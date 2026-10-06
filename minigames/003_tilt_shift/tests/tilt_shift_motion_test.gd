extends TestScript


func _run() -> void:
	_turns_and_gaps()
	_capture_and_tuning()
	await _arena_lifecycle()


func _turns_and_gaps() -> void:
	var channel := MotionInputChannel.new()
	channel.begin("one")
	var selected := TiltShiftMotionTuning.new()
	var input := TiltShiftTiltInput.new(selected)
	check(TiltShiftMotionFixtures.live(channel, 0, 1, 1000), "Neutral sample is accepted")
	check(input.calibrate(channel, 1000), "Unknown permission with usable data can calibrate")
	for step: int in range(1, 145):
		var turn := step * 10.0
		var now := 1000 + step * 34
		TiltShiftMotionFixtures.live(channel, turn, step + 1, now)
		check(input.update(channel, now), "A new full-turn sample updates control")
		check(
			absf(input.angle_radians - deg_to_rad(turn)) < 0.00001,
			"Clockwise beam turns remain unwrapped and 1:1 through Euler branches",
		)
	for step: int in range(1, 289):
		var turn := 1440.0 - step * 10.0
		var now := 6000 + step * 34
		TiltShiftMotionFixtures.live(channel, turn, step + 145, now)
		input.update(channel, now)
		check(
			absf(input.angle_radians - deg_to_rad(turn)) < 0.00001,
			"Reversal and counterclockwise complete turns remain continuous",
		)
	var neutral := input.neutral_phase
	var held := input.angle_radians
	check(not input.update(channel, 20000), "Stale input does not update the angle")
	channel.reconnect()
	check(input.calibrated, "Reconnect does not discard the old neutral")
	TiltShiftMotionFixtures.live(channel, -1440 + 720 + 20, 1, 21000)
	input.update(channel, 21000)
	check(
		absf(input.angle_radians - held - deg_to_rad(20)) < 0.00001,
		"A reconnect takes the nearest branch and does not invent unseen complete turns",
	)
	check(input.neutral_phase == neutral, "The original neutral survives reconnect")
	check(input.continuity == &"resumed", "The first post-gap sample is marked resumed")
	var current := input.angle_radians
	channel.latest.screen_angle = -90
	channel.received_at += 34
	input.update(channel, 21034)
	check(is_equal_approx(current, input.angle_radians), "Autorotation alone cannot tilt a paddle")
	channel.latest.orientation = TiltShiftMotionFixtures.angles(-700, 237)
	channel.received_at += 34
	input.update(channel, 21068)
	check(is_equal_approx(current, input.angle_radians), "Yaw alone cannot tilt a paddle")
	TiltShiftMotionFixtures.live(channel, -520, 2, 21102)
	check(not input.update(channel, 21102), "An exactly ambiguous half turn is held")
	check(input.state(channel, 21102).capture_state == "ambiguous_turn", "Ambiguity is observable")
	check(is_equal_approx(current, input.angle_radians), "Ambiguity preserves the accepted angle")
	channel.end()


func _capture_and_tuning() -> void:
	var channel := MotionInputChannel.new()
	channel.begin("one")
	var profile := TiltShiftMotionTuning.new()
	profile.gain = 2.0
	var input := TiltShiftTiltInput.new(profile)
	profile.gain = 8.0
	TiltShiftMotionFixtures.live(channel, 0, 1, 1000)
	input.calibrate(channel, 1000)
	TiltShiftMotionFixtures.live(channel, -30, 2, 1034)
	input.update(channel, 1034)
	check(
		absf(input.angle_radians - deg_to_rad(-60)) < 0.00001,
		"Host gain is frozen independently of later Inspector edits",
	)
	channel.latest.orientation[0] = null
	check(input.capture_state(channel, 1034) == &"partial_orientation", "Partial data is distinct")
	channel.latest.orientation_age_msec = null
	check(input.capture_state(channel, 1034) == &"absent_orientation", "Absent events are distinct")
	channel.latest.orientation_age_msec = 1001
	check(
		input.capture_state(channel, 1034) == &"stale_orientation",
		"Live acceleration cannot make an old orientation usable",
	)
	channel.latest.orientation = [0, 0, 0]
	channel.latest.orientation_age_msec = 0
	check(
		input.capture_state(channel, 1034) == &"degenerate_orientation",
		"Face-horizontal projection is explicitly unusable",
	)
	channel.diagnostics.orientation_permission = "denied"
	check(input.capture_state(channel, 1034) == &"denied", "Denied orientation is distinct")
	channel.diagnostics.orientation_permission = "unknown"
	channel.diagnostics.orientation_support = false
	check(
		input.capture_state(channel, 1034) == &"unsupported",
		"Unsupported orientation is distinct",
	)
	channel.diagnostics.secure_context = false
	check(input.capture_state(channel, 1034) == &"insecure", "Insecure capture is distinct")
	check(not input.calibrate(channel, 1034), "Unusable data cannot establish neutral")
	var bounded_profile := TiltShiftMotionTuning.new()
	bounded_profile.continuous = false
	bounded_profile.maximum_degrees = 60
	var bounded := TiltShiftTiltInput.new(bounded_profile)
	channel.reconnect()
	TiltShiftMotionFixtures.live(channel, 180, 1, 2000)
	bounded.calibrate(channel, 2000)
	TiltShiftMotionFixtures.live(channel, 210, 2, 2034)
	bounded.update(channel, 2034)
	check(absf(bounded.angle_radians - deg_to_rad(30)) < 0.00001, "Opposite hold retains tilt sign")
	TiltShiftMotionFixtures.live(channel, 280, 3, 2068)
	bounded.update(channel, 2068)
	check(absf(bounded.angle_radians - deg_to_rad(60)) < 0.00001, "Comparison clamps at its limit")
	TiltShiftMotionFixtures.live(channel, 200, 4, 2102)
	bounded.update(channel, 2102)
	check(
		absf(bounded.angle_radians - deg_to_rad(20)) < 0.00001,
		"Bounded reversal retains neutral",
	)
	bounded_profile.gain = INF
	check(not bounded_profile.validation_errors().is_empty(), "Non-finite control gain is rejected")
	channel.end()


func _arena_lifecycle() -> void:
	var service := WebsocketService.new()
	root.add_child(service)
	var motion := TiltShiftMotionController.new()
	root.add_child(motion)
	motion.set_process(false)
	var time := [1000]
	motion.clock = func() -> int:
		return time[0]
	var players := TiltShiftFixtures.players(2)
	var ids := PackedStringArray([players[0].player_id, players[1].player_id])
	check(
		motion.prepare(service, ids, TiltShiftMotionTuning.new()),
		"Preparation subscribes both players",
	)
	for player_id: String in ids:
		var channel := service.motion_channels[player_id]
		TiltShiftMotionFixtures.live(channel, 0, 1, time[0])
		channel.handle(
			{ "player_id": player_id },
			{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
			time[0],
		)
		check(
			motion.ready_for(player_id),
			"Each player independently becomes calibrated and usable",
		)
	var arena := TiltShiftArena.new()
	root.add_child(arena)
	arena.clock = motion.clock
	var started := arena.start_shift(TiltShiftFixtures.tuning(2), players)
	check(started.accepted, "The actual arena starts")
	check(motion.activate(arena), "Calibrated roster activates authoritative control")
	time[0] += 34
	for player_id: String in ids:
		TiltShiftMotionFixtures.live(service.motion_channels[player_id], 30, 2, time[0])
	motion.poll()
	for paddle: TiltShiftPaddleBody in arena.paddle_bodies():
		check(
			absf(paddle.target_angle - deg_to_rad(30)) < 0.00001,
			"All assigned paddles share accepted tilt",
		)
	for unused: int in 24:
		await physics_frame
	for paddle: TiltShiftPaddleBody in arena.paddle_bodies():
		check(
			absf(paddle.applied_angle - deg_to_rad(30)) < 0.00001,
			"Confirmed collider poses converge together within the physical rate limit",
		)
	var channel := service.motion_channels[ids[0]]
	var neutral := motion.inputs[ids[0]].neutral_phase
	time[0] += 200
	channel.handle(
		{ "player_id": ids[0] },
		{ "type": "motion_calibrate", "subscription_id": channel.subscription_id },
		time[0],
	)
	check(motion.inputs[ids[0]].neutral_phase == neutral, "Active recalibration is rejected")
	channel.reconnect()
	time[0] += 34
	TiltShiftMotionFixtures.live(channel, 360 + 40, 1, time[0])
	motion.poll()
	check(
		absf(motion.inputs[ids[0]].angle_radians - deg_to_rad(40)) < 0.00001,
		"Active resume keeps neutral",
	)
	time[0] = 2000
	arena.controller.advance(time[0])
	check(arena.controller.snapshot().phase == &"between_rounds", "Round closes at its deadline")
	check(arena.start_next_round().accepted, "The next round starts with retained control")
	motion.poll()
	check(motion.inputs[ids[0]].calibrated, "Round changes retain each neutral")
	arena.stop()
	check(
		motion.inputs.is_empty() and service.motion_channels.is_empty(),
		"Arena stop releases channels and neutral",
	)
	check(
		motion.prepare(service, ids, TiltShiftMotionTuning.new()),
		"A later preparation starts fresh",
	)
	check(not motion.ready_for(ids[0]), "A later game cannot inherit calibration")
	service.begin_motion(ids[0])
	check(motion.inputs.is_empty(), "Switching to the lab retires gameplay control")
	check(
		service.motion_channel.target_player_id == ids[0],
		"The stable lab channel remains usable",
	)
	service.end_motion()
	arena.queue_free()
	motion.queue_free()
	service.queue_free()
	await process_frame
