extends TestScript
## Native engine physics-frame time includes the driver and arena at their actual tick order.


class Controls:
	extends Node
	var arena: TiltShiftArena
	var players: Array[TiltShiftState.Player] = []
	var token: String
	var started: int
	var control_usec: int = 0


	func _physics_process(_delta: float) -> void:
		if arena == null or arena.controller == null or not arena._active:
			return
		var began := Time.get_ticks_usec()
		var now := Time.get_ticks_msec()
		var seconds := float(now - started) / 1000.0
		var progress := fmod(seconds, 8.0)
		var angle := PI * (progress if progress < 4.0 else 8.0 - progress)
		for index: int in players.size():
			arena.controller.accept_angle(
				players[index].player_id,
				angle if index % 2 == 0 else -angle,
				token,
				now,
			)
		control_usec = Time.get_ticks_usec() - began


func _run() -> void:
	var report := "Godot %s; %s; CPU %s; physics %d Hz\n" % [
		Engine.get_version_info().string,
		OS.get_name(),
		OS.get_processor_name(),
		Engine.physics_ticks_per_second,
	]
	report += "Ten synthetic players; ten rotating paddles; no phone/network/render workload.\n"
	report += "Engine monitor reports one-second maxima, not per-frame percentiles.\n"
	report += "Script timing measures each physics callback; both include synthetic controls.\n"
	report += await _measure(0, 3.0)
	report += await _measure(300, 45.0)
	var directory := "res://test-results/tilt-shift"
	DirAccess.make_dir_recursive_absolute(directory)
	var output := FileAccess.open(directory.path_join("physics-cost.txt"), FileAccess.WRITE)
	if check(output != null, "Physics cost report opens"):
		output.store_string(report)
		output.close()
	print(report)


func _measure(count: int, duration: float) -> String:
	var selected := TiltShiftFixtures.tuning(1)
	selected.round_duration_seconds = duration
	selected.physics.ball_count = count
	selected.physics.use_position_seed = true
	selected.physics.position_seed = 827
	selected.physics.delivery_curve = PackedVector2Array(
		[
			Vector2(0, 0),
			Vector2(0.4, 0),
			Vector2(0.42, 1),
			Vector2(0.58, 1),
			Vector2(0.6, 0),
			Vector2(1, 0),
		]
	)
	var driver := Controls.new()
	root.add_child(driver)
	var arena := TiltShiftArena.new()
	driver.add_child(arena)
	check(
		arena.start_shift(selected, TiltShiftFixtures.players(10)).accepted,
		"Measured arena launches with valid content",
	)
	driver.arena = arena
	var state := arena.controller.snapshot()
	driver.players = state.players
	driver.token = state.round_token
	driver.started = state.started_at_msec
	var physics := PackedFloat64Array()
	var script := PackedFloat64Array()
	var warmups := 0
	var next_monitor_sample := state.started_at_msec + 1200
	var invalid_body := false
	while arena._active:
		await physics_frame
		await process_frame
		warmups += 1
		if warmups > 20 and arena._active:
			var now := Time.get_ticks_msec()
			if now >= next_monitor_sample:
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
				next_monitor_sample += 1000
			script.append(float(arena.last_step_usec + driver.control_usec) / 1000.0)
		for ball: TiltShiftBall in arena.live_balls():
			invalid_body = invalid_body or not ball.position.is_finite()
			invalid_body = invalid_body or not ball.linear_velocity.is_finite()
	check(not invalid_body, "High-density physics stays finite")
	check(arena.spawned_count == count, "Measured profile emits every ball before cutoff")
	check(arena.live_balls().is_empty(), "Measured round clears every live ball at its deadline")
	var result := "Balls %d / %.1f seconds; peak live %d; script samples %d\n" % [
		count,
		duration,
		arena.peak_live_balls,
		script.size(),
	]
	result += "  Engine one-second maxima ms median/p95/max (%d samples): %s\n" % [
		physics.size(),
		_stats(physics),
	]
	result += "  Arena + synthetic controls ms median/p95/max: %s\n" % _stats(script)
	arena.stop()
	await process_frame
	check(arena.get_child_count() == 0, "Measured stop leaves no orphan colliders")
	driver.queue_free()
	await process_frame
	return result


func _stats(samples: PackedFloat64Array) -> String:
	if samples.is_empty():
		return "no samples"
	samples.sort()
	return "%.4f / %.4f / %.4f" % [
		_percentile(samples, 0.5),
		_percentile(samples, 0.95),
		samples[-1],
	]


func _percentile(samples: PackedFloat64Array, fraction: float) -> float:
	var index := float(samples.size() - 1) * fraction
	return lerpf(samples[floori(index)], samples[ceili(index)], index - floorf(index))
