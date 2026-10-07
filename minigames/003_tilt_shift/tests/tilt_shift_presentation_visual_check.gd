extends TestScript
## Real rendered factory layouts and scoped synthetic host costs.

const SCENE := preload("res://minigames/003_tilt_shift/tilt_shift_presentation.tscn")
const Driver := preload("res://minigames/003_tilt_shift/tests/tilt_shift_physics_cost_check.gd")
const OUTPUT := "res://test-results/tilt-shift/presentation/"
var _presentation: TiltShiftPresentation


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _capture_pair()
	await _measure_ten()


func _players(count: int) -> Array[TiltShiftState.Player]:
	var players := TiltShiftFixtures.players(count)
	for index: int in count:
		players[index].character_color = String(CharacterSelection.COLORS[index].hex)
		players[index].player_name = "Operator %d" % (index + 1)
	return players


func _capture_pair() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var presentation := SCENE.instantiate() as TiltShiftPresentation
	_presentation = presentation
	root.add_child(presentation)
	var profile := TiltShiftFixtures.tuning(1)
	profile.round_duration_seconds = 10
	profile.physics.ball_count = 40
	presentation.start_shift(profile, _players(2))
	await create_timer(2).timeout
	await _capture("two-players-fhd.png")
	presentation.stop()
	presentation.queue_free()
	await process_frame


func _measure_ten() -> void:
	var presentation := SCENE.instantiate() as TiltShiftPresentation
	_presentation = presentation
	root.add_child(presentation)
	var profile := TiltShiftFixtures.tuning(1)
	profile.round_duration_seconds = 45
	profile.physics.ball_count = 300
	profile.physics.use_position_seed = true
	profile.physics.position_seed = 749
	check(presentation.start_shift(profile, _players(10)).accepted, "Measured factory launches")
	var driver := Driver.Controls.new()
	driver.arena = presentation.arena
	var state := presentation.arena.controller.snapshot()
	driver.players = state.players
	driver.token = state.round_token
	driver.started = state.started_at_msec
	root.add_child(driver)
	var arena_times := PackedInt64Array()
	var input_times := PackedInt64Array()
	var clock_times := PackedInt64Array()
	var capture_stage := 0
	while presentation.arena._active:
		await physics_frame
		await process_frame
		arena_times.append(presentation.arena.last_step_usec)
		input_times.append(driver.control_usec)
		clock_times.append(presentation.last_process_usec)
		var elapsed := Time.get_ticks_msec() - state.started_at_msec
		if capture_stage == 0 and elapsed > 6000:
			await _capture("ten-players-fhd.png")
			root.size = Vector2i(1280, 720)
			root.content_scale_size = root.size
			capture_stage = 1
		elif capture_stage == 1 and elapsed > 8000:
			await _capture("ten-players-hd.png")
			root.size = Vector2i(1024, 768)
			root.content_scale_size = root.size
			capture_stage = 2
		elif capture_stage == 2 and elapsed > 10000:
			await _capture("ten-players-four-three.png")
			root.size = Vector2i(1920, 1080)
			root.content_scale_size = root.size
			capture_stage = 3
	await _capture("shift-result.png")
	check(presentation.arena.spawned_count == 300, "Measured factory delivers all 300 balls")
	check(presentation.arena.live_balls().is_empty(), "Cutoff clears all visual ball bodies")
	var report := "Ten synthetic players; 300 balls; 45 s; GL Compatibility.\n"
	report += "Arena script p95: %d us\n" % _p95(arena_times)
	report += "Ten accepted-control callbacks p95: %d us\n" % _p95(input_times)
	report += "Presentation clock callback p95: %d us\n" % _p95(clock_times)
	report += "Peak live balls: %d\n" % presentation.arena.peak_live_balls
	report += "Control timing includes cosmetic pose updates from accepted input.\n"
	report += "Native physics, rendering, blink and badge callbacks excluded.\n"
	report += "Added phone messages and bytes: zero; presentation is local to the host.\n"
	var file := FileAccess.open(OUTPUT.path_join("cost.txt"), FileAccess.WRITE)
	file.store_string(report)
	file.close()
	print(report)
	presentation.stop()
	driver.queue_free()
	presentation.queue_free()
	await process_frame


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
		check(
			visible.has_point(transform * corner),
			"Camera retains complete factory after resize: " + filename,
		)
	check(
		root.get_texture().get_image().save_png(OUTPUT.path_join(filename)) == OK,
		"Factory capture saves: " + filename,
	)
