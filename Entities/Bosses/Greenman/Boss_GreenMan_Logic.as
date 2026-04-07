#include "Boss_GreenMan_Common.as";
#include "FireCommon.as"
#include "Hitters.as";

//attacks limited to the one time per-actor before reset.

void greenman_actorlimit_setup(CBlob@ this)
{
	u16[] networkIDs;
	this.set("LimitedActors", networkIDs);
}

bool greenman_has_hit_actor(CBlob@ this, CBlob@ actor)
{
	u16[]@ networkIDs;
	this.get("LimitedActors", @networkIDs);
	return networkIDs.find(actor.getNetworkID()) >= 0;
}

void greenman_add_actor_limit(CBlob@ this, CBlob@ actor)
{
	this.push("LimitedActors", actor.getNetworkID());
}

void greenman_clear_actor_limits(CBlob@ this)
{
	this.clear("LimitedActors");
}

void onInit(CBlob@ this)
{
	this.Tag("boss");
	this.Tag("medium weight");
	//this.Tag("player");//added for knight hittable
	this.set_s16(burn_duration , 130);
	greenman_actorlimit_setup(this);

	this.addCommandID("action sync");

	GreenManInfo greenman;

	greenman.state = GreenManStates::normal;
	greenman.actionTimer = 0;

	this.set("greenManInfo", @greenman);
}


void onTick(CBlob@ this)
{
	GreenManInfo@ greenman;
	if (!this.get("greenManInfo", @greenman))
	{
		return;
	}

	u8 state = greenman.state;
	u16 actionTimer = greenman.actionTimer;
	actionTimer++;

	switch (state)
	{
		case GreenManStates::normal:
		{
			if (isServer() && actionTimer >= 30)
			{
				actionTimer = 0;

				u8 random = XORRandom(3);
				Vec2f direction = Vec2f_zero;
				switch (random)
				{
					case 0:
					{
						state = GreenManStates::chasing;

						//find target
						CBlob@ targetBlob = findTarget(this);
						if (targetBlob is null)
						{
							state = GreenManStates::normal;
						}
						else
						{
							greenman.targetID = targetBlob.getNetworkID();
						}
					}
					break;

					case 1:
					{
						state = GreenManStates::throwing;
					}
					break;

					case 2:
					{
						state = GreenManStates::jumping;
						greenman.falling = false;

						//find target
						CBlob@ targetBlob = findTarget(this);

						//jump
						Vec2f jumpForce = Vec2f(0.0f, -GreenManVars::jumping_force);
						//rotate direction to target(todo)
						//Gingerbread please

						this.setVelocity(jumpForce);

						direction = jumpForce;
					}
					break;
				}

				if (!isClient() && state != GreenManStates::normal)//not localhost
				{
					CBitStream params;
					params.write_u8(state);
					params.write_Vec2f(direction);
					params.write_netid(greenman.targetID);
					this.SendCommand(this.getCommandID("action sync"), params);
				}
			}
		}
		break;

		case GreenManStates::chasing:
		{
			CBlob@ targetBlob = getBlobByNetworkID(greenman.targetID);
			if (targetBlob is null)
			{
				state = GreenManStates::normal;
				break;
			}
			Vec2f dif = this.getPosition() - targetBlob.getPosition();
			bool targetIsLeft = dif.x < 0;
			this.SetFacingLeft(targetIsLeft);
			this.setVelocity(Vec2f(targetIsLeft ? GreenManVars::chasing_force : -GreenManVars::chasing_force, 0.0f));

			if (dif.x <= GreenManVars::punch_length && dif.x >= -GreenManVars::punch_length)
			{
				actionTimer = 0;
				state = GreenManStates::punching;

				if (!isClient())//not localhost
				{
					CBitStream params;
					params.write_u8(state);
					params.write_Vec2f(Vec2f_zero);
					params.write_netid(-1);
					this.SendCommand(this.getCommandID("action sync"), params);
				}
			}
		}
		break;

		case GreenManStates::punching:
		{
			CBlob@ targetBlob = getBlobByNetworkID(greenman.targetID);
			if (targetBlob !is null)
			{
				Vec2f dif = this.getPosition() - targetBlob.getPosition();
				this.SetFacingLeft(dif.x < 0);
			}

			if (actionTimer >= 30)
			{
				greenman_clear_actor_limits(this);
				//sound
				Sound::Play("CatapultFire", this.getPosition());
				//punch
				Punch(this);
				//set state
				actionTimer = 0;
				state = GreenManStates::punched;
			}
		}
		break;

		case GreenManStates::punched:
		{
			if (actionTimer < 10)
			{
				Punch(this);
			}
			else if (actionTimer >= 30)
			{
				actionTimer = 0;
				state = GreenManStates::normal;
			}
		}
		break;

		case GreenManStates::throwing:
		{
			//find target
			CBlob@ targetBlob = findTarget(this);

			if (targetBlob !is null)
			{
				Vec2f dif = this.getPosition() - targetBlob.getPosition();
				this.SetFacingLeft(dif.x < 0);
			}
			if (actionTimer >= 60)
			{
				//set state
				actionTimer = 0;
				state = GreenManStates::throwed;
				//sound
				Sound::Play("CatapultFire", this.getPosition());

				//throw
				if (isServer())
				{
					//calculate direction(Gingerbread please)

					//shoot
					int r = 0;
					for (int i = 0; i < GreenManVars::throw_amount; i++)
					{
						CBlob@ ball = server_CreateBlob("arrow");
						ball.IgnoreCollisionWhileOverlapped(this);
						ball.server_setTeamNum(this.getTeamNum());
						ball.setPosition(this.getPosition());

						r = r > 0 ? -(r + 1) : (-r) + 1;

						Vec2f ballVel = Vec2f(GreenManVars::throw_velocity, 0.0f);
						if (!this.isFacingLeft()) ballVel.RotateBy(180.0f, Vec2f());//change here when calculate direction
						ballVel = ballVel.RotateBy(GreenManVars::throw_deviation * r, Vec2f());
						ball.setVelocity(ballVel);
					}
				}
			}
		}
		break;

		case GreenManStates::throwed:
		{
			if (actionTimer >= 30)
			{
				actionTimer = 0;
				state = GreenManStates::normal;
			}
		}
		break;

		case GreenManStates::jumping:
		{
			bool falling = greenman.falling;
			Vec2f velocity = this.getVelocity();

			if (falling)
			{
				if (actionTimer >= 30)
				{
					state = GreenManStates::normal;
				}
				else if (actionTimer <= 1 && velocity.y <= 0)
				{
					actionTimer = 0;
				}
			}
			else if (actionTimer >= 10 && velocity.y > 0)
			{
				falling = true;
				actionTimer = 0;
			}

			greenman.falling = falling;
		}
		break;
	}

	greenman.state = state;
	greenman.actionTimer = actionTimer;
}

void onCommand(CBlob@ this, u8 cmd, CBitStream @params)
{
	GreenManInfo@ greenman;
	if (!this.get("greenManInfo", @greenman))
	{
		return;
	}

	if (cmd == this.getCommandID("action sync") && isClient())
	{
		u8 state;
		if (!params.saferead_u8(state)) return;

		Vec2f direction;
		if (!params.saferead_Vec2f(direction)) return;

		u16 target;
		if (!params.saferead_netid(target)) return;

		greenman.state = state;
		greenman.actionTimer = 0;

		switch (state)
		{
			case GreenManStates::chasing:
			{
				greenman.targetID = target;
			}
			break;

			case GreenManStates::throwing:
			{
				//nothing
			}
			break;

			case GreenManStates::jumping:
			{
				this.setVelocity(direction);
				greenman.falling = false;
			}
			break;

			case GreenManStates::punching:
			{
				//nothing
			}
			break;
		}
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid)// from Stomp.as
{
	if (blob is null)   // map collision?
	{
		return;
	}

	if (!solid)
	{
		return;
	}

	//dead bodies dont stomp
	if (this.hasTag("dead"))
	{
		return;
	}

	// server only
	if (!getNet().isServer() || !blob.hasTag("player")) { return; }

	if (this.getPosition().y < blob.getPosition().y - 2)
	{
		float enemydam = 0.0f;
		f32 vely = this.getOldVelocity().y;

		if (vely > 10.0f)
		{
			enemydam = 2.0f;
		}
		else if (vely > 5.5f)
		{
			enemydam = 1.0f;
		}

		if (enemydam > 0)
		{
			this.server_Hit(blob, this.getPosition(), Vec2f(0, 1) , GreenManVars::jumping_damage, Hitters::stomp);
		}
	}
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

void Punch(CBlob@ this)
{
	if (!isServer()) return;

	f32 radius = this.getRadius();
	CMap@ map = this.getMap();
	Vec2f pos = this.getPosition();
	HitInfo@[] hitInfos;
	if (map.getHitInfosFromArc(pos, (this.isFacingLeft() ? 0.0f : 180.0f), GreenManVars::punch_arc, radius + GreenManVars::punch_length, this, @hitInfos))
	{
		for (int i = 0; i < hitInfos.size(); i++)
		{
			HitInfo@ hi = hitInfos[i];
			CBlob@ b = hi.blob;

			if (b is null) continue;
					
			Vec2f velocity = b.getPosition() - pos;
			velocity.Normalize();
			velocity *= 12; // knockback force is same regardless of distance

			if (canHit(this, b) && !greenman_has_hit_actor(this, b))
			{
				this.server_Hit(b, hi.hitpos, velocity, GreenManVars::punch_damage, Hitters::sword, true);
				greenman_add_actor_limit(this, b);
			}
		}
	}
}

// Blame Fuzzle.
// as same as knight
bool canHit(CBlob@ this, CBlob@ b)
{
	if (b.hasTag("invincible") || b.hasTag("temp blob"))
		return false;
	
	// don't hit picked up items (except players and specially tagged items)
	return b.hasTag("player") || b.hasTag("slash_while_in_hand") || !isBlobBeingCarried(b);
}

bool isBlobBeingCarried(CBlob@ b)
{	
	CAttachment@ att = b.getAttachments();
	if (att is null)
	{
		return false;
	}

	// Look for a "PICKUP" attachment point where socket=false and occupied=true
	return att.getAttachmentPoint("PICKUP", false, true) !is null;
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}