#include "Boss_ExploSionMan_Common.as";
#include "FireCommon.as";
#include "Hitters.as";
#include "ActivationThrowCommon.as";
#include "Explosion.as";

void onInit(CBlob@ this)
{
	this.Tag("boss");
	this.Tag("medium weight");
	//this.Tag("player");//added for knight hittable
	this.set_s16(burn_duration , 130);

	this.Tag("bomberman_style");
	this.set_f32("map_bomberman_width", 24.0f);
	this.set_f32("explosive_radius", 64.0f);
	this.set_f32("explosive_damage", 10.0f);
	this.set_u8("custom_hitter", Hitters::keg);
	this.set_string("custom_explosion_sound", "Entities/Items/Explosives/KegExplosion.ogg");
	this.set_f32("map_damage_radius", 72.0f);
	this.set_f32("map_damage_ratio", 0.8f);
	this.set_bool("map_damage_raycast", true);

	this.addCommandID("action sync");

	ExplosionManInfo explosionman;

	explosionman.state = ExplosionManStates::normal;
	explosionman.actionTimer = 0;

	this.set("explosionManInfo", @explosionman);
}

void onTick(CBlob@ this)
{
	if (this.hasTag("dead")) return;

	ExplosionManInfo@ explosionman;
	if (!this.get("explosionManInfo", @explosionman))
	{
		return;
	}

	u8 state = explosionman.state;
	u16 actionTimer = explosionman.actionTimer;
	actionTimer++;

	switch (state)
	{
		case ExplosionManStates::normal:
		{
			if (isServer() && actionTimer >= 30)
			{
				actionTimer = 0;

				u8 random = XORRandom(5);
				switch (random)
				{
					case 0:
					{
						state = ExplosionManStates::chasing;

						//find target
						CBlob@ targetBlob = findTarget(this);
						if (targetBlob is null)
						{
							state = ExplosionManStates::normal;
						}
						else
						{
							explosionman.targetID = targetBlob.getNetworkID();
						}
					}
					break;

					case 1:
					{
						state = ExplosionManStates::suiciding;
					}
					break;

					case 2:
					{
						state = ExplosionManStates::bombrain;

						//find target
						CBlob@ targetBlob = findTarget(this);
						if (targetBlob !is null)
						{
							CBlob@ bomb = server_CreateBlob("bomb");
							if (bomb !is null)
							{
								bomb.server_setTeamNum(this.getTeamNum());
								bomb.setPosition(Vec2f(targetBlob.getPosition().x, 0.0f));
							}
						}
					}
					break;

					case 3:
					{
						state = ExplosionManStates::throwingkeg;
					}
					break;

					case 4:
					{
						state = ExplosionManStates::minerain;

						for (int i = 0; i < ExplosionManVars::mine_amount; i++)
						{
							CBlob@ mine = server_CreateBlob("mine");
							if (mine !is null)
							{
								mine.server_setTeamNum(this.getTeamNum());
								CMap@ map = getMap();
								mine.setPosition(Vec2f(map.tilemapwidth * map.tilesize / 255 * XORRandom(256),  0.0f));
							}
						}
					}
					break;
				}

				if (!isClient() && state != ExplosionManStates::normal)//not localhost
				{
					CBitStream params;
					params.write_u8(state);
					params.write_netid(explosionman.targetID);
					this.SendCommand(this.getCommandID("action sync"), params);
				}
			}
		}
		break;

		case ExplosionManStates::chasing:
		{
			CBlob@ targetBlob = getBlobByNetworkID(explosionman.targetID);
			if (targetBlob is null || actionTimer >= ExplosionManVars::chasing_time)
			{
				state = ExplosionManStates::normal;
				break;
			}
			Vec2f dif = this.getPosition() - targetBlob.getPosition();
			bool targetIsLeft = dif.x > 0;
			this.SetFacingLeft(targetIsLeft);
			this.setVelocity(Vec2f(targetIsLeft ? -ExplosionManVars::chasing_force : ExplosionManVars::chasing_force, 0.0f));

			if (dif.x <= ExplosionManVars::chasing_length && dif.x >= -ExplosionManVars::chasing_length)
			{
				actionTimer = 0;
				state = ExplosionManStates::clustercharging;

				if (isServer())
				{
					for (int i = 0; i < ExplosionManVars::cluster_amount; i++)
					{
						CBlob@ cluster = server_CreateBlob("boss_explosionman_cluster");
						if (cluster !is null)
						{
							cluster.server_setTeamNum(this.getTeamNum());
							cluster.set_s16("cluster_timer", -1);
							cluster.set_s16("cluster_time", ExplosionManVars::cluster_delay * i);
							explosionman.clusterHolder.push_back(@cluster);
						}
					}
				}

				if (!isClient())//not localhost
				{
					CBitStream params;
					params.write_u8(state);
					params.write_netid(-1);
					this.SendCommand(this.getCommandID("action sync"), params);
				}
			}
		}
		break;

		case ExplosionManStates::clustercharging:
		{
			f32 angle = this.isFacingLeft() ? 180.0f : 0.0f;

			CBlob@ targetBlob = getBlobByNetworkID(explosionman.targetID);
			if (targetBlob !is null)
			{
				Vec2f dif = this.getPosition() - targetBlob.getPosition();
				this.SetFacingLeft(dif.x > 0);
				angle = (targetBlob.getPosition() - this.getPosition()).Angle();
			}

			bool clusterTime = actionTimer >= ExplosionManVars::cluster_charge_time;

			for (int i = 0; i < ExplosionManVars::cluster_amount; i++)
			{
				CBlob@ cluster = @explosionman.clusterHolder[i];
				if (cluster !is null)
				{
					cluster.setPosition(this.getPosition() + Vec2f(ExplosionManVars::cluster_length * (i + 1), 0.0f).RotateBy(-angle));
					if (clusterTime) cluster.set_s16("cluster_timer", 0);
				}
			}

			if (clusterTime)
			{
				//set state
				actionTimer = 0;
				state = ExplosionManStates::cluster;
				explosionman.clusterHolder.clear();

				if (!isClient())//not localhost
				{
					CBitStream params;
					params.write_u8(state);
					params.write_netid(-1);
					this.SendCommand(this.getCommandID("action sync"), params);
				}
			}
		}
		break;

		case ExplosionManStates::cluster:
		{
			if (actionTimer >= ExplosionManVars::cluster_time)
			{
				actionTimer = 0;
				state = ExplosionManStates::normal;
			}
		}
		break;

		case ExplosionManStates::suiciding:
		{
			if (actionTimer >= ExplosionManVars::suicide_charge_time)
			{
				//explode
				Explode(this, 64.0f, 10.0f);
				//set state
				actionTimer = 0;
				state = ExplosionManStates::suicide;
			}
		}
		break;

		case ExplosionManStates::suicide:
		{
			if (actionTimer >= ExplosionManVars::suicide_time)
			{
				actionTimer = 0;
				state = ExplosionManStates::normal;
			}
		}
		break;

		case ExplosionManStates::bombrain:
		{
			if (actionTimer >= ExplosionManVars::bomb_time)
			{
				actionTimer = 0;
				state = ExplosionManStates::normal;
			}
		}
		break;

		case ExplosionManStates::throwingkeg:
		{
			//find target
			CBlob@ targetBlob = findTarget(this);

			if (targetBlob !is null)
			{
				Vec2f dif = this.getPosition() - targetBlob.getPosition();
				this.SetFacingLeft(dif.x > 0);
			}
			if (actionTimer >= ExplosionManVars::throw_keg_charge_time)
			{
				//set state
				actionTimer = 0;
				state = ExplosionManStates::throwedkeg;
				//sound
				Sound::Play("CatapultFire", this.getPosition());

				//throw
				if (isServer())
				{
					//calculate direction(Gingerbeard please)

					//shoot
					CBlob@ keg = server_CreateBlob("keg");
					if (keg !is null)
					{
						keg.IgnoreCollisionWhileOverlapped(this);
						keg.server_setTeamNum(this.getTeamNum());
						keg.setPosition(this.getPosition());
						server_Activate(keg);
					
						Vec2f kegVel = Vec2f(ExplosionManVars::throw_keg_velocity, 0.0f);
						kegVel.RotateBy(this.isFacingLeft() ? -100.0f : -80.0f, Vec2f());//change here when calculate direction
						keg.setVelocity(kegVel);
					}
				}
			}
		}
		break;

		case ExplosionManStates::throwedkeg:
		{
			if (actionTimer >= ExplosionManVars::throw_keg_time)
			{
				actionTimer = 0;
				state = ExplosionManStates::normal;
			}
		}
		break;

		case ExplosionManStates::minerain:
		{
			if (actionTimer >= ExplosionManVars::mine_time)
			{
				actionTimer = 0;
				state = ExplosionManStates::normal;
			}
		}
		break;
	}

	explosionman.state = state;
	explosionman.actionTimer = actionTimer;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	ExplosionManInfo@ explosionman;
	if (!this.get("explosionManInfo", @explosionman))
	{
		return;
	}

	if (cmd == this.getCommandID("action sync") && isClient())
	{
		u8 state;
		if (!params.saferead_u8(state)) return;

		u16 target;
		if (!params.saferead_netid(target)) return;

		explosionman.state = state;
		explosionman.actionTimer = 0;

		switch (state)
		{
			case ExplosionManStates::chasing:
			{
				explosionman.targetID = target;
			}
			break;

			case ExplosionManStates::suiciding:
			{
				//nothing
			}
			break;

			case ExplosionManStates::bombrain:
			{
				//nothing
			}
			break;

			case ExplosionManStates::throwingkeg:
			{
				//nothing
			}
			break;

			case ExplosionManStates::minerain:
			{
				//nothing
			}
			break;
			
			case ExplosionManStates::clustercharging:
			{
				//nothing
			}
			break;
			
			case ExplosionManStates::cluster:
			{
				//nothing
			}
			break;
		}
	}
}

f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (damage > 0.05f) //sound for all damage
	{
		if (hitterBlob !is this)
		{
			this.getSprite().PlaySound("dig_stone", Maths::Min(1.25f, Maths::Max(0.5f, damage)));
		}

		makeGibParticle("GenericGibs", worldPoint, getRandomVelocity((this.getPosition() - worldPoint).getAngle(), 1.0f + damage, 90.0f) + Vec2f(0.0f, -2.0f),
		                2, 4 + XORRandom(4), Vec2f(8, 8), 2.0f, 0, "", 0);
	}

	this.Damage(damage, hitterBlob);
	// Gib if health below gibHealth
	f32 gibHealth = -3.0f;

	//printf("ON HIT " + damage + " he " + this.getHealth() + " g " + gibHealth );
	// blob server_Die()() and then gib


	//printf("gibHealth " + gibHealth + " health " + this.getHealth() );
	if (this.getHealth() <= gibHealth)
	{
		this.getSprite().Gib();
		this.server_Die();
	}
	if (this.getHealth() <= 0.0f && !this.hasTag("dead"))
	{
		this.Tag("dead");

		this.UnsetMinimapVars(); //remove minimap icon

		// we want the corpse to stay but player to respawn so we force a die event in rules

		if (getNet().isServer())
		{
			getRules().server_BlobDie(this);
		}

		// sound

		if (this.getSprite() !is null) //moved here to prevent other logic potentially not getting run
		{
			if (this !is hitterBlob)
			{
				if (this.getHealth() > gibHealth / 2.0f)
				{
					this.getSprite().PlaySound("WilhelmShort.ogg", this.getSexNum() == 0 ? 1.0f : 1.5f);
				}
				else if (this.getHealth() > gibHealth)
				{
					this.getSprite().PlaySound("Wilhelm.ogg", 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
				}
			}
		}

		this.getCurrentScript().tickFrequency = 30;

		// new physics vars so bodies don't slide
		this.getShape().setFriction(0.75f);
		this.getShape().setElasticity(0.2f);

		// disable tags
		this.Untag("boss");
		this.getShape().getVars().isladder = false;
		this.getShape().getVars().onladder = false;
		this.getShape().checkCollisionsAgain = true;
		this.getShape().SetGravityScale(1.0f);
        // fall out of attachments/seats // drop all held things
		this.server_DetachAll();
	}

	return 0.0f; //done, we've used all the damage
}

CBlob@ findTarget(CBlob@ this)
{
	CBlob@[] players;
	getBlobsByTag("player", @players);
	Vec2f pos = this.getPosition();
	CBlob@ finalPotential = null;
	f32 minLength = -1.0f;
	for (uint i = 0; i < players.length; i++)
	{
		CBlob@ potential = players[i];
		Vec2f pos2 = potential.getPosition();
		f32 length = (pos2 - pos).getLength();
		if (potential !is this && this.getTeamNum() != potential.getTeamNum()
				&& (minLength == -1.0f || length < minLength)
		        && !potential.hasTag("dead") && !potential.hasTag("migrant")
		   )
		{
			minLength = length;
			@finalPotential = @potential;
		}
	}
	return finalPotential;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}