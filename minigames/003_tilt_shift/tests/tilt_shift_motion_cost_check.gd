extends TestScript
## Virtual 17 ms frames with distinct 34 ms player samples. Native physics/sockets excluded.


func _run() -> void:
	var service := WebsocketService.new()
	root.add_child(service)
	var motion := TiltShiftMotionController.new()
	root.add_child(motion)
	motion.set_process(false)
	var time := [1000]
	motion.clock = func() -> int:
		return time[0]
	var players := TiltShiftFixtures.players(10)
	var ids := PackedStringArray()
	for player: TiltShiftState.Player in players:
		ids.append(player.player_id)
	var motion_profile := TiltShiftMotionTuning.new()
	check(motion.prepare(service, ids, motion_profile), "Ten-player cost session prepares")
	for player_id: String in ids:
		var channel := service.motion_channels[player_id]
		TiltShiftMotionFixtures.live(channel, 0, 1, time[0])
		motion._calibrate(time[0], player_id)
	var arena := TiltShiftArena.new()
	root.add_child(arena)
	arena.clock = motion.clock
	var content := TiltShiftFixtures.tuning(1)
	content.round_duration_seconds = 45
	check(arena.start_shift(content, players).accepted, "The benchmark uses actual arena targets")
	check(motion.activate(arena), "Ten-player cost session activates")
	var all_frames := PackedFloat64Array()
	var sample_frames := PackedFloat64Array()
	var accept_frames := PackedFloat64Array()
	for frame: int in range(1, 1321):
		time[0] += 17
		if frame % 2 == 0:
			var start := Time.get_ticks_usec()
			for index: int in ids.size():
				TiltShiftMotionFixtures.live(
					service.motion_channels[ids[index]],
					frame * 0.5 + index,
					frame / 2 + 1,
					time[0],
				)
			if frame > 120:
				accept_frames.append((Time.get_ticks_usec() - start) / 1000.0)
		var start := Time.get_ticks_usec()
		motion.poll()
		var elapsed := (Time.get_ticks_usec() - start) / 1000.0
		if frame > 120:
			all_frames.append(elapsed)
			if frame % 2 == 0:
				sample_frames.append(elapsed)
	var report := {
		"cpu": OS.get_processor_name(),
		"players": 10,
		"warmup_frames": 120,
		"measured_frames": 1200,
		"virtual_frame_msec": 17,
		"virtual_duration_seconds": 20.4,
		"sample_hz_per_phone": 1000.0 / 34,
		"poll_all_frames_ms": _summary(all_frames),
		"poll_sample_frames_ms": _summary(sample_frames),
		"fixture_and_channel_accept_ms": _summary(accept_frames),
		"excluded": "sockets, JSON parsing, native physics, rendering, physical sensors",
	}
	DirAccess.make_dir_recursive_absolute("res://test-results/tilt-shift/motion")
	var file := FileAccess.open("res://test-results/tilt-shift/motion/cost.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(JSON.stringify(report))
	arena.stop()
	arena.queue_free()
	motion.queue_free()
	service.queue_free()
	await process_frame


static func _summary(values: PackedFloat64Array) -> Dictionary:
	values.sort()
	return {
		"median": values[values.size() / 2],
		"p95": values[ceili(values.size() * 0.95) - 1],
		"max": values[-1],
	}
