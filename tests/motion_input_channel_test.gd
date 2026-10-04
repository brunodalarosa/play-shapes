extends TestScript


func _run() -> void:
	var channel := MotionInputChannel.new()
	channel.begin("one")
	var sample := {
		"orientation": [0, 90, null],
		"absolute": false,
		"rotation_rate": [null, null, null],
		"acceleration": [0, null, 1],
		"acceleration_gravity": [0, 9.8, 0],
		"interval_msec": 16,
		"screen_angle": 0,
		"orientation_age_msec": 0,
		"motion_age_msec": 0,
		"orientation_hz": 60,
		"motion_hz": 60,
	}
	var message := {
		"type": "motion_sample",
		"subscription_id": channel.subscription_id,
		"sequence": 1,
		"sample": sample,
	}
	check(
		not channel.handle({ }, message, 1000),
		"A sample from a connection without a player is refused",
	)
	check(
		not channel.handle({ "player_id": "two" }, message, 1000),
		"A sample from a player the channel does not target is refused",
	)
	check(
		channel.handle({ "player_id": "one" }, message, 1000),
		"A sample from the target player is accepted",
	)
	check(
		channel.latest.acceleration[0] == 0 and channel.latest.acceleration[1] == null,
		"Missing sensor axes stay null beside the measured ones",
	)
	check(
		not channel.handle({ "player_id": "one" }, message, 1100),
		"A repeated sequence number is refused",
	)
	message.sequence = 2
	check(
		not channel.handle({ "player_id": "one" }, message, 1001),
		"A sample that arrives too soon after the last is refused",
	)
	message.sample.orientation[0] = INF
	check(
		not channel.handle({ "player_id": "one" }, message, 1100),
		"A sample with a non-finite value is refused",
	)
	message.sample.orientation[0] = 0
	message.sample.erase("motion_age_msec")
	message.sample.extra = null
	check(
		not channel.handle({ "player_id": "one" }, message, 1100),
		"A sample with a missing or unknown field is refused",
	)
	channel.reconnect()
	check(
		not channel.handle({ "player_id": "one" }, message, 1200),
		"A sample for the subscription before a reconnect is refused",
	)
	check(channel.latest.is_empty(), "A reconnect clears the latest sample")
	channel.end()
	check(channel.target_player_id.is_empty(), "Ending the channel clears its target")
	check(
		MotionOrientation.device_basis([0, 90, 0]).is_equal_approx(Basis.IDENTITY),
		"A phone held upright in portrait maps to the identity basis",
	)
	check(
		MotionOrientation
		.physical_basis([40, 70, -15], 90)
		.is_equal_approx(MotionOrientation.device_basis([40, 70, -15])),
		"The screen angle does not change the physical basis",
	)
	check(
		MotionOrientation
		.device_basis([359.9, 90, 0])
		.get_rotation_quaternion()
		.angle_to(MotionOrientation.device_basis([0.1, 90, 0]).get_rotation_quaternion())
		< 0.01,
		"Orientations on both sides of the 360 degree wrap are close",
	)
