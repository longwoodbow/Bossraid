#include "Hitters.as";
#include "Boss_Explosionman_Common.as";
#include "Explosion.as";  // <---- onHit()

void onInit(CBlob@ this)
{
	this.Tag("exploding");
	this.set_f32("explosive_radius", ExplosionManVars::cluster_radius);
	this.set_f32("explosive_damage", ExplosionManVars::cluster_damage);
	this.set_u8("custom_hitter", Hitters::bomb);
	this.set_f32("map_damage_radius", ExplosionManVars::cluster_radius);
	this.set_f32("map_damage_ratio", 0.4f);
	this.set_bool("map_damage_raycast", true);

	this.getShape().SetStatic(true);
}

void onTick(CBlob@ this)
{
	if (!isServer()) return;

	if(this.get_s16("cluster_timer") >= this.get_s16("cluster_time"))
	{
		this.server_Die();
	}
	else if(this.get_s16("cluster_timer") >= 0) this.add_s16("cluster_timer", 1);
}

bool canBePickedUp(CBlob@ this, CBlob@ byBlob)
{
	return false;
}