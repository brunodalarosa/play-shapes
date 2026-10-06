class_name TiltShiftMotionFixtures
extends RefCounted


static func angles(
	turn_degrees: float,
	yaw_degrees: float = 0.0,
	lean_degrees: float = 80.0,
) -> Array:
	var raw := Basis(Vector3.BACK, deg_to_rad(yaw_degrees)) \
			* Basis(Vector3.UP, deg_to_rad(lean_degrees)) \
			* Basis(Vector3.BACK, -deg_to_rad(turn_degrees))
	var beta := asin(clampf(raw.y.z, -1.0, 1.0))
	var gamma := atan2(-raw.x.z, raw.z.z)
	var alpha := atan2(-raw.y.x, raw.y.y)
	if absf(gamma) > PI / 2.0:
		beta = wrapf(PI - beta, -PI, PI)
		gamma = wrapf(gamma + PI, -PI, PI)
		alpha += PI
	return [fposmod(rad_to_deg(alpha), 360.0), rad_to_deg(beta), rad_to_deg(gamma)]


static func sample(turn: float, screen_angle: float = 90.0, yaw: float = 0.0) -> Dictionary:
	return {
		"orientation": angles(turn, yaw),
		"absolute": false,
		"rotation_rate": [0, 0, 0],
		"acceleration": [0, 0, 0],
		"acceleration_gravity": [0, 0, 9.8],
		"interval_msec": 16.667,
		"screen_angle": screen_angle,
		"orientation_age_msec": 0,
		"motion_age_msec": 0,
		"orientation_hz": 60,
		"motion_hz": 60,
	}


static func diagnostics(state: String = "live") -> Dictionary:
	return {
		"secure_context": true,
		"motion_support": true,
		"orientation_support": true,
		"motion_permission": "unknown",
		"orientation_permission": "unknown",
		"state": state,
		"page_protocol": "https:",
		"hostname": "127.0.0.1",
		"websocket_protocol": "wss:",
		"websocket_status": "open",
	}


static func live(channel: MotionInputChannel, turn: float, sequence: int, now: int) -> bool:
	if channel.diagnostics.is_empty():
		channel.handle(
			{ "player_id": channel.target_player_id },
			{
				"type": "motion_status",
				"subscription_id": channel.subscription_id,
				"diagnostics": diagnostics(),
			},
			now,
		)
	return channel.handle(
		{ "player_id": channel.target_player_id },
		{
			"type": "motion_sample",
			"subscription_id": channel.subscription_id,
			"sequence": sequence,
			"sample": sample(turn),
		},
		now,
	)
