namespace ExplosionManStates
{
	enum States
	{
		normal = 0,
		chasing,
		clustercharging,
		cluster,
		suiciding,
		suicide,
		bombrain,
		throwingkeg,
		throwedkeg,
		minerain
	}
}

namespace ExplosionManVars
{
	const ::f32 chasing_force = 3.0f;
	const ::f32 chasing_length = 256.0f;
	const ::s32 chasing_time = 255;

	const ::s32 cluster_charge_time = 60;
	const ::s32 cluster_time = 30;
	const ::s32 cluster_amount = 8;
	const ::s32 cluster_delay = 7;
	const ::f32 cluster_damage = 3.0f;
	const ::f32 cluster_length = 32.0f;
	const ::f32 cluster_radius = 16.0f;

	const ::s32 suicide_charge_time = 60;
	const ::s32 suicide_time = 60;

	const ::s32 bomb_time = 30;

	const ::s32 throw_keg_charge_time = 30;
	const ::s32 throw_keg_time = 30;
	const ::f32 throw_keg_velocity = 15.0f;

	const ::s32 mine_time = 30;
	const ::s32 mine_amount = 3;
}

shared class ExplosionManInfo
{
	u8 state;
	u16 actionTimer;
	u16 targetID = -1;
	CBlob@[] clusterHolder;
};