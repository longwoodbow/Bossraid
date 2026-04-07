#define CLIENT_ONLY
#include "Boss_GreenMan_Common.as";

void onInit(CSprite@ this)
{

}

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

	GreenManInfo@ greenman;
	if (!blob.get("greenManInfo", @greenman))
	{
		return;
	}

	u8 state = greenman.state;
	u16 actionTimer = greenman.actionTimer;

	switch (state)
	{
		case GreenManStates::normal:
		{
			this.SetAnimation("default");
		}
		break;

		case GreenManStates::chasing:
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

		case GreenManStates::punching:
		{
			this.SetAnimation("punch");
			this.animation.SetFrameIndex(0);
		}
		break;

		case GreenManStates::punched:
		{
			this.SetAnimation("punch");

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

		case GreenManStates::throwing:
		{
			this.SetAnimation("throw");
			this.animation.SetFrameIndex(0);
		}
		break;

		case GreenManStates::throwed:
		{
			this.SetAnimation("throw");

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

		case GreenManStates::jumping:
		{
			this.SetAnimation("jump");

			if (greenman.falling)
			{
				this.animation.SetFrameIndex(1);
			}
			else
			{
				this.animation.SetFrameIndex(0);
			}
		}
		break;
	}
}