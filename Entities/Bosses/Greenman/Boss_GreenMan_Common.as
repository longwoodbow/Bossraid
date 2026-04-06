namespace GreenManStates
{
	enum States
	{
		normal = 0,
		chasing,
		punching,
		punched,
		throwing,
		throwed,
		jumping
	}
}

namespace GreenManVars
{
	const ::f32 chasing_force = 3.0f;
	const ::f32 punch_damage = 3.0f;
	const ::f32 punch_arc = 90.0f;
	const ::f32 punch_length = 32.0f;
	const ::s32 throw_amount = 5;
	const ::f32 throw_deviation = 2.5f;
	const ::f32 throw_velocity = 17.59f;
	const ::f32 jumping_damage = 3.0f;
	const ::f32 jumping_force = 10.0f;
}

shared class GreenManInfo
{
	u8 state;
	u16 actionTimer;
	u16 targetID = -1;
	bool falling = false;
};