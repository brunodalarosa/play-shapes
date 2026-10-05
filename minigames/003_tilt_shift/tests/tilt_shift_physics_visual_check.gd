extends TestScript
## Captures the actual arena with synthetic controls; production presentation is separate.

const CostCheck := preload("res://minigames/003_tilt_shift/tests/tilt_shift_physics_cost_check.gd")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var selected := TiltShiftFixtures.tuning(1)
	selected.round_duration_seconds = 8.0
	selected.physics.ball_count = 180
	selected.physics.use_position_seed = true
	selected.physics.position_seed = 749
	var driver := CostCheck.Controls.new()
	root.add_child(driver)
	var arena := load("res://minigames/003_tilt_shift/tilt_shift_arena.tscn").instantiate() \
			as TiltShiftArena
	driver.add_child(arena)
	check(
		arena.start_shift(selected, TiltShiftFixtures.players(10)).accepted,
		"Visual helper launches the gameplay arena",
	)
	var state := arena.controller.snapshot()
	driver.arena = arena
	driver.players = state.players
	driver.token = state.round_token
	driver.started = state.started_at_msec
	var camera := Camera2D.new()
	camera.position = state.paddle_layout.arena_size * TiltShiftArena.WORLD_UNITS * 0.5
	var size := state.paddle_layout.arena_size * TiltShiftArena.WORLD_UNITS
	var zoom := minf(root.size.x / size.x, root.size.y / (size.y + 80)) * 0.9
	camera.zoom = Vector2.ONE * zoom
	driver.add_child(camera)
	var directory := "res://test-results/tilt-shift/physics"
	DirAccess.make_dir_recursive_absolute(directory)
	for index: int in 3:
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var file := directory.path_join("arena-%d.png" % (index + 1))
		check(root.get_texture().get_image().save_png(file) == OK, "Runtime capture saves")
		print(
			"Runtime capture: ",
			file,
			" live=",
			arena.live_balls().size(),
			" scores=",
			arena.controller.snapshot().scores,
		)
	arena.stop()
