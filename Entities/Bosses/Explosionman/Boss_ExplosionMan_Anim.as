#define CLIENT_ONLY
#include "Boss_ExplosionMan_Common.as";

void onTick(CSprite@ this)
{
	CBlob@ blob = this.getBlob();

	if (blob.hasTag("dead"))
	{
		if (this.animation.name != "dead")
		{
			this.SetAnimation("dead");
		}
		return;
	}

	ExplosionManInfo@ explosionman;
	if (!blob.get("explosionManInfo", @explosionman))
	{
		return;
	}

	u8 state = explosionman.state;
	u16 actionTimer = explosionman.actionTimer;

	switch (state)
	{
		case ExplosionManStates::normal:
		{
			this.SetAnimation("default");
		}
		break;

		case ExplosionManStates::chasing:
		{
			this.SetAnimation("run");
			if (blob.isOnGround() && (blob.getNetworkID() + getGameTime()) % 8 == 0)
			{
				f32 volume = Maths::Min(0.1f + blob.getShape().vellen * 0.1f, 1.0f);
				TileType tile = blob.getMap().getTile(blob.getPosition() + Vec2f(0.0f, blob.getRadius() + 4.0f)).type;

				if (blob.getMap().isTileGroundStuff(tile))
				{
					this.PlayRandomSound("/EarthStep", volume);
				}
				/*
				else if (blob.isOnLadder())
				{
					f32 pitch = 0.75f + XORRandom(10) / 20.0f; //0.75f - 1.25f
					this.PlaySound("/WoodHeavyBump1", volume, pitch);
				}
				*/
				else
				{
					this.PlayRandomSound("/StoneStep", volume);
				}
			}
		}		
		break;

		case ExplosionManStates::clustercharging:
		{
			this.SetAnimation("cluster");
			this.animation.SetFrameIndex(0);
		}
		break;

		case ExplosionManStates::cluster:
		{
			this.SetAnimation("cluster");
			this.animation.SetFrameIndex(1);
		}
		break;

		case ExplosionManStates::suiciding:
		{
			this.SetAnimation("suicide");
			this.animation.SetFrameIndex(0);
		}
		break;

		case ExplosionManStates::suicide:
		{
			this.SetAnimation("suicide");
			this.animation.SetFrameIndex(1);
		}
		break;

		case ExplosionManStates::bombrain:
		{
			this.SetAnimation("bombrain");
		}
		break;

		case ExplosionManStates::throwingkeg:
		{
			this.SetAnimation("throwkeg");
			this.animation.SetFrameIndex(0);
		}
		break;

		case ExplosionManStates::throwedkeg:
		{
			this.SetAnimation("throwkeg");

			if (actionTimer < 10)
			{
				this.animation.SetFrameIndex(1);
			}
			else
			{
				this.animation.SetFrameIndex(2);
			}
		}
		break;

		case ExplosionManStates::minerain:
		{
			this.SetAnimation("minerain");
		}
		break;
	}
}