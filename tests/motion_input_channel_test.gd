extends SceneTree

func _initialize() -> void:
	var channel := MotionInputChannel.new()
	channel.begin("one")
	var sample := {"orientation": [0, 90, null], "absolute": false, "rotation_rate": [null, null, null], "acceleration": [0, null, 1], "acceleration_gravity": [0, 9.8, 0], "interval_msec": 16, "screen_angle": 0, "orientation_age_msec": 0, "motion_age_msec": 0, "orientation_hz": 60, "motion_hz": 60}
	var message := {"type": "motion_sample", "subscription_id": channel.subscription_id, "sequence": 1, "sample": sample}
	assert(not channel.handle({}, message, 1000))
	assert(not channel.handle({"player_id": "two"}, message, 1000))
	assert(channel.handle({"player_id": "one"}, message, 1000))
	assert(channel.latest.acceleration[0] == 0 and channel.latest.acceleration[1] == null)
	assert(not channel.handle({"player_id": "one"}, message, 1100))
	message.sequence = 2
	assert(not channel.handle({"player_id": "one"}, message, 1001))
	message.sample.orientation[0] = INF
	assert(not channel.handle({"player_id": "one"}, message, 1100))
	message.sample.orientation[0] = 0
	channel.reconnect()
	assert(not channel.handle({"player_id": "one"}, message, 1200))
	assert(channel.latest.is_empty())
	channel.end()
	assert(channel.target_player_id.is_empty())
	assert(MotionOrientation.device_basis([0, 90, 0]).is_equal_approx(Basis.IDENTITY))
	assert(MotionOrientation.physical_basis([40, 70, -15], 90).is_equal_approx(MotionOrientation.device_basis([40, 70, -15])))
	assert(MotionOrientation.device_basis([359.9, 90, 0]).get_rotation_quaternion().angle_to(MotionOrientation.device_basis([0.1, 90, 0]).get_rotation_quaternion()) < 0.01)
	print("Motion channel and orientation checks passed")
	quit(0)
