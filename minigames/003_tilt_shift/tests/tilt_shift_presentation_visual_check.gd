extends TestScript
## Mapped factory composition and scoped synthetic host costs; no physical sensor evidence.

const SCENE := preload("res://minigames/003_tilt_shift/tilt_shift_presentation.tscn")
const Driver := preload("res://minigames/003_tilt_shift/tests/tilt_shift_physics_cost_check.gd")
const OUTPUT := "res://test-results/tilt-shift/presentation/"
var _presentation: TiltShiftPresentation


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var report := "Godot %s; CPU %s; %d Hz; GL Compatibility.\n" % [
		Engine.get_version_info().string,
		OS.get_processor_name(),
		Engine.physics_ticks_per_second,
	]
	report += await _measure(0, 60)
	report += await _measure(1, 300)
	report += "Script timings exclude native physics/rendering and transport.\n"
	report += "Engine physics samples are one-second maxima, not per-frame percentiles.\n"
	var file := FileAccess.open(OUTPUT.path_join("cost.txt"), FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)


func _measure(layout_index: int, balls: int) -> String:
	var presentation := SCENE.instantiate() as TiltShiftPresentation
	_presentation = presentation
	root.add_child(presentation)
	var source: TiltShiftTuning = load("res://minigames/003_tilt_shift/tuning/Default.tres")
	var profile: TiltShiftTuning = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	profile.layouts_by_round = [profile.layouts_by_round[layout_index]]
	profile.baskets_by_round.resize(1)
	profile.round_count = 1
	profile.physics.ball_count = balls
	profile.physics.use_position_seed = true
	profile.physics.position_seed = 749
	var players := TiltShiftFixtures.players(10)
	for index: int in players.size():
		players[index].character_color = String(CharacterSelection.COLORS[index].hex)
		players[index].player_name = "Operator %d" % (index + 1)
	check(presentation.start_shift(profile, players).accepted, "Mapped factory launches")
	var suffix := "layout-a" if layout_index == 0 else "layout-b"
	await _capture(suffix + "-preparation.png")
	var controller := presentation.arena.controller
	controller.force_start(controller.snapshot().round_token, Time.get_ticks_msec())
	await create_timer(1).timeout
	await _capture(suffix + "-countdown.png")
	while controller.snapshot().phase != &"active":
		await process_frame
	var state := controller.snapshot()
	var driver := Driver.Controls.new()
	driver.arena = presentation.arena
	for player: TiltShiftState.Player in state.players:
		if player.selected:
			driver.players.append(player)
	driver.token = state.round_token
	driver.started = state.started_at_msec
	root.add_child(driver)
	var arena_times := PackedInt64Array()
	var input_times := PackedInt64Array()
	var clock_times := PackedInt64Array()
	var physics_peaks := PackedFloat64Array()
	var next_monitor := state.started_at_msec + 1200
	var stage := 0
	while presentation.arena._active:
		await physics_frame
		await process_frame
		arena_times.append(presentation.arena.last_step_usec)
		input_times.append(driver.control_usec)
		clock_times.append(presentation.last_process_usec)
		var now := Time.get_ticks_msec()
		if now >= next_monitor:
			physics_peaks.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
			next_monitor += 1000
		var elapsed := now - state.started_at_msec
		if stage == 0 and elapsed > 6000:
			await _capture(suffix + "-fhd.png")
			root.size = Vector2i(1280, 720)
			root.content_scale_size = root.size
			stage = 1
		elif stage == 1 and elapsed > 8000:
			await _capture(suffix + "-hd.png")
			root.size = Vector2i(1024, 768)
			root.content_scale_size = root.size
			stage = 2
		elif stage == 2 and elapsed > 10000:
			await _capture(suffix + "-four-three.png")
			root.size = Vector2i(1920, 1080)
			root.content_scale_size = root.size
			stage = 3
		elif stage == 3 and elapsed > 30000:
			await _capture(suffix + "-mixed-balls.png")
			stage = 4
	await _capture(suffix + "-result.png")
	var total := balls + profile.physics.negative_ball_count
	check(presentation.arena.spawned_count == total, "Mapped factory delivers the complete budget")
	check(presentation.arena.live_balls().is_empty(), "Deadline clears visual ball bodies")
	physics_peaks.sort()
	var report := "%s; ten-player roster; %d selected; %d balls; 45 seconds.\n" % [
		suffix,
		driver.players.size(),
		total,
	]
	report += "Arena script p95: %d us; input p95: %d us; presentation p95: %d us.\n" % [
		_p95(arena_times),
		_p95(input_times),
		_p95(clock_times),
	]
	report += "Peak live balls: %d; native physics interval-peak p95: %.3f ms.\n" % [
		presentation.arena.peak_live_balls,
		physics_peaks[ceili(physics_peaks.size() * 0.95) - 1],
	]
	presentation.stop()
	driver.queue_free()
	presentation.queue_free()
	await process_frame
	return report


func _p95(samples: PackedInt64Array) -> int:
	samples.sort()
	return samples[mini(samples.size() - 1, ceili(samples.size() * 0.95) - 1)]


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var visible := Rect2(Vector2.ZERO, Vector2(_presentation.viewport.size)).grow(2)
	var bounds := _presentation.world_bounds()
	var transform := _presentation.viewport.get_canvas_transform()
	for corner: Vector2 in [bounds.position, bounds.end]:
		check(visible.has_point(transform * corner), "Camera retains complete factory: " + filename)
	check(
		root.get_texture().get_image().save_png(OUTPUT.path_join(filename)) == OK,
		"Factory capture saves: " + filename,
	)
