
#include "Hitters.as";
#include "ShieldCommon.as";
#include "KnockedCommon.as";
#include "DoorCommon.as";

const f32 arrowMediumSpeed = 8.0f;
const f32 arrowFastSpeed = 13.0f;

const f32 ARROW_PUSH_FORCE = 6.0f;
const f32 SPECIAL_HIT_SCALE = 1.0f; //special hit on food items to shoot to team-mates

//Arrow logic

//blob functions
void onInit(CBlob@ this)
{
	CShape@ shape = this.getShape();
	ShapeConsts@ consts = shape.getConsts();
	consts.mapCollisions = false;	 // we have our own map collision
	consts.bullet = false;
	consts.net_threshold_multiplier = 4.0f;
	this.Tag("projectile");

	//dont collide with top of the map
	this.SetMapEdgeFlags(CBlob::map_collide_left | CBlob::map_collide_right);

	// 20 seconds of floating around - gets cut down for fire arrow
	// in ArrowHitMap
	this.server_SetTimeToDie(20);
}

void onTick(CBlob@ this)
{
	CShape@ shape = this.getShape();

	f32 angle;
	bool processSticking = true;
	if (!this.hasTag("collided")) //we haven't hit anything yet!
	{
		//prevent leaving the map
		{
			Vec2f pos = this.getPosition();
			if (
				pos.x < 0.1f ||
				pos.x > (getMap().tilemapwidth * getMap().tilesize) - 0.1f
			) {
				this.server_Die();
				return;
			}
		}

		angle = (this.getVelocity()).Angle();
		Pierce(this);   //map
		this.setAngleDegrees(-angle);

		if (shape.vellen > 0.0001f)
		{
			if (shape.vellen > 13.5f)
			{
				shape.SetGravityScale(0.1f);
			}
			else
			{
				shape.SetGravityScale(Maths::Min(1.0f, 1.0f / (shape.vellen * 0.1f)));
			}

			processSticking = false;
		}
	}
}

void onCollision(CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1)
{
	if (blob !is null && doesCollideWithBlob(this, blob) && !this.hasTag("collided"))
	{
		if (
			!solid && !blob.hasTag("flesh") &&
			!specialArrowHit(blob) &&
			(blob.getName() != "mounted_bow" || this.getTeamNum() != blob.getTeamNum())
		) {
			return;
		}

		Vec2f initVelocity = this.getOldVelocity();
		f32 vellen = initVelocity.Length();
		if (vellen < 0.1f)
		{
			return;
		}

		f32 dmg = 0.0f;
		if (blob.getTeamNum() != this.getTeamNum() || blob.getName() == "bridge")
		{
			dmg = getArrowDamage(this, vellen);
		}


		// this isnt synced cause we want instant collision for arrow even if it was wrong
		dmg = ArrowHitBlob(this, point1, initVelocity, dmg, blob, Hitters::arrow);

		if (dmg > 0.0f)
		{
			// determine the hit type
			// fire arrows still act as normal arrows
			const u8 hit_type =Hitters::arrow;

			//perform the hit and tag so that another doesn't happen
			this.server_Hit(blob, point1, initVelocity, dmg, hit_type);

			this.Tag("collided");
		}

		//die _now_ for bomb arrow
		if (!this.hasTag("dead"))
		{
			this.doTickScripts = false;
			this.server_Die(); //explode
		}
		this.Tag("dead");
	}
}

bool doesCollideWithBlob(CBlob@ this, CBlob@ blob)
{
	//don't collide with other projectiles
	if (blob.hasTag("projectile"))
	{
		return false;
	}

	//collide so normal arrows can be ignited
	if (blob.getName() == "fireplace")
	{
		return true;
	}

	//anything to always hit
	if (specialArrowHit(blob))
	{
		return true;
	}

	bool check =	this.getTeamNum() != blob.getTeamNum() || // collide with enemy blobs
					blob.getName() == "bridge";

	//maybe collide with team structures
	if (!check)
	{
		CShape@ shape = blob.getShape();
		check = (shape.isStatic() && !shape.getConsts().platform);
	}

	if (check)
	{
		if (
			//we've collided
			this.getShape().isStatic() ||
			this.hasTag("collided") ||
			//or they're dead
			blob.hasTag("dead") ||
			//or they ignore us
			blob.hasTag("ignore_arrow")
		) {
			return false;
		}
		else
		{
			return true;
		}
	}

	return false;
}

bool specialArrowHit(CBlob@ blob)
{
	string bname = blob.getName();
	return (bname == "fishy" && blob.hasTag("dead") || bname == "food"
		|| bname == "steak" || bname == "grain"/* || bname == "heart"*/); //no egg because logic
}

void Pierce(CBlob @this, CBlob@ blob = null)
{
	Vec2f end;
	CMap@ map = getMap();
	Vec2f position = blob is null ? this.getPosition() : blob.getPosition();

	if (map.rayCastSolidNoBlobs(this.getShape().getVars().oldpos, position, end))
	{
		ArrowHitMap(this, end, this.getOldVelocity(), 0.5f, Hitters::arrow, blob);
	}
}

f32 ArrowHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	if (hitBlob !is null)
	{
		Pierce(this, hitBlob);
		if (this.hasTag("collided")) return 0.0f;

		// check if invincible + special -> add force here
		if (specialArrowHit(hitBlob))
		{
			const f32 scale = SPECIAL_HIT_SCALE;
			f32 force = (ARROW_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;
			force *= 1.3f;

			hitBlob.AddForce(velocity * force);

			//die
			this.server_Hit(this, this.getPosition(), Vec2f(), 1.0f, Hitters::crush);
		}

		// check if shielded
		const bool hitShield = (hitBlob.hasTag("shielded") && blockAttack(hitBlob, velocity, 0.0f));

		// play sound
		if (!hitShield)
		{
			if (hitBlob.hasTag("flesh"))
			{
				if (velocity.Length() > arrowFastSpeed)
				{
					this.getSprite().PlaySound("ArrowHitFleshFast.ogg");
				}
				else
				{
					this.getSprite().PlaySound("ArrowHitFlesh.ogg");
				}
			}
			else
			{
				if (velocity.Length() > arrowFastSpeed)
				{
					this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
				}
				else
				{
					this.getSprite().PlaySound("ArrowHitGround.ogg");
				}
			}
		}
		
		//stick into "map" blobs
		if (hitBlob.getShape().isStatic())
		{
			ArrowHitMap(this, worldPoint, velocity, damage, Hitters::arrow, hitBlob);
		}
		//die otherwise
		else
		{
			this.server_Die();
		}
	}

	return damage;
}

void ArrowHitMap(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, u8 customData, CBlob@ hitBlob = null)
{
	if (velocity.Length() > arrowFastSpeed)
	{
		this.getSprite().PlaySound("ArrowHitGroundFast.ogg");
	}
	else
	{
		this.getSprite().PlaySound("ArrowHitGround.ogg");
	}

	f32 radius = this.getRadius();

	f32 angle = velocity.Angle();

	this.set_u8("angle", Maths::get256DegreesFrom360(angle));

	Vec2f norm = velocity;
	norm.Normalize();
	norm *= (1.5f * radius);
	Vec2f lock = worldPoint - norm;
	this.set_Vec2f("lock", lock);

	// saving information on what was hit to determine when the arrow should collapse
	if (isServer())
	{
		if (hitBlob is null) // map (stone, wood, dirt)
		{
			this.set_Vec2f("hitWorldPoint", worldPoint);
		}
		else // hitBlob (door, platform, etc.)
		{
			this.set_u32("hitBlob", hitBlob.getNetworkID());
		}
	}

	this.Sync("lock", true);
	this.Sync("angle", true);

	this.setVelocity(Vec2f(0, 0));
	this.setPosition(lock);
	//this.getShape().server_SetActive( false );

	this.Tag("collided");

	if (!this.hasTag("dead"))
	{
		this.Tag("dead");
		this.doTickScripts = false;
		this.server_Die(); //explode
	}

	//kill any grain plants we shot the base of
	//ignite fireplace when fire arrow hits the base
	CBlob@[] blobsInRadius;
	if (getMap().getBlobsInRadius(worldPoint, this.getRadius() * 1.3f, @blobsInRadius))
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
			if (b.getName() == "grain_plant")
			{
				this.server_Hit(b, worldPoint, Vec2f(0, 0), velocity.Length() / 7.0f, Hitters::arrow);
				break;
			}
		}
	}
}


f32 onHit(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData)
{
	if (customData == Hitters::sword)
	{
		return 0.0f; //no cut arrows
	}

	return damage;
}

void onHitBlob(CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData)
{
	// unbomb, stick to blob
	if (this !is hitBlob && customData == Hitters::arrow)
	{
		// affect players velocity

		const f32 scale = specialArrowHit(hitBlob) ? SPECIAL_HIT_SCALE : 1.0f;

		Vec2f vel = velocity;
		const f32 speed = vel.Normalize();
		if (speed > 17.59f * 0.5f)
		{
			f32 force = (ARROW_PUSH_FORCE * 0.125f) * Maths::Sqrt(hitBlob.getMass() + 1) * scale;

			force *= 1.3f;

			hitBlob.AddForce(velocity * force);

			// stun if shot real close
			if (
				this.getTickSinceCreated() <= 4 &&
				speed > 17.59f * 0.845f &&
				hitBlob.hasTag("player")
			) {
				setKnocked(hitBlob, 20, true);
				Sound::Play("/Stun", hitBlob.getPosition(), 1.0f, this.getSexNum() == 0 ? 1.0f : 1.5f);
			}
		}
	}
}

f32 getArrowDamage(CBlob@ this, f32 vellen = -1.0f)
{
	if (vellen < 0) //grab it - otherwise use cached
	{
		CShape@ shape = this.getShape();
		if (shape is null)
			vellen = this.getOldVelocity().Length();
		else
			vellen = this.getShape().getVars().oldvel.Length();
	}

	if (vellen >= arrowFastSpeed)
	{
		return 1.0f;
	}
	else if (vellen >= arrowMediumSpeed)
	{
		return 1.0f;
	}

	return 0.5f;
}