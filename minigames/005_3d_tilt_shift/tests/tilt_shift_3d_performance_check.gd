extends TestScript
## Measures the shared screen of Tilt Shift 3D at its heaviest: ten players in layout B with
## every paddle tilting, names and faces showing, and the round's whole budget of sixty white and
## twenty dark blue balls delivered within twenty seconds, so far more are live at once than in
## a normal 45-second round. Run without --headless on the target machine; vsync is turned off
## so the frame time is the work.

const SCENE := preload("res://minigames/005_3d_tilt_shift/tilt_shift_3d_presentation.tscn")
const Driver := preload(
	"res://minigames/005_3d_tilt_shift/tests/tilt_shift_3d_physics_cost_check.gd"
)
const OUTPUT := "res://test-results/tilt-shift-3d/"
const SAMPLE_SECONDS := 21.0


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	var presentation := SCENE.instantiate() as TiltShift3DPresentation
	root.add_child(presentation)
	var source: TiltShift3DTuning = load("res://minigames/005_3d_tilt_shift/tuning/Default.tres")
	var profile: TiltShift3DTuning = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	profile.layouts_by_round = [profile.layouts_by_round[1]]
	profile.baskets_by_round.resize(1)
	profile.round_count = 1
	profile.round_duration_seconds = 20.0
	profile.physics.delivery_cutoff_seconds = 2.0
	profile.physics.negative_delivery_curve = PackedVector2Array([Vector2(0, 1), Vector2(1, 1)])
	var players := TiltShift3DFixtures.players(10)
	for index: int in players.size():
		players[index].character_color = String(CharacterSelection.COLORS[index].hex)
	check(presentation.start_shift(profile, players).accepted, "The heaviest shift launches")
	var controller := presentation.arena.controller
	controller.force_start(controller.snapshot().round_token, Time.get_ticks_msec())
	while controller.snapshot().phase != &"active":
		await process_frame
	var state := controller.snapshot()
	var controls := Driver.Controls.new()
	controls.arena = presentation.arena
	for player: TiltShift3DState.Player in state.players:
		if player.selected:
			controls.players.append(player)
	controls.token = state.round_token
	controls.started = state.started_at_msec
	root.add_child(controls)

	var frames: Array[float] = []
	var physics: Array[float] = []
	var draw_calls := 0
	var last := Time.get_ticks_usec()
	var end := last + roundi(SAMPLE_SECONDS * 1_000_000.0)
	while Time.get_ticks_usec() < end and presentation.arena.is_active():
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_calls = maxi(draw_calls, int(calls))
	frames.sort()
	physics.sort()
	var total := 0.0
	for frame: float in frames:
		total += frame
	var average := total / frames.size()
	var slow := frames[floori(frames.size() * 0.95)]
	var worst := frames[-1]
	var physics_slow := physics[floori(physics.size() * 0.95)]
	var report := (
		"[GODOT-RUNTIME] Tilt Shift 3D, 10 players, %d paddles, %d balls delivered, up to %d live: "
		% [
			presentation.arena.paddle_bodies().size(),
			presentation.arena.spawned_count,
			presentation.arena.peak_live_balls,
		]
		+ "average frame %.2f ms (%.0f fps), 95th percentile %.2f ms, worst %.2f ms; "
		% [average, 1000.0 / average, slow, worst]
		+ "physics step 95th percentile %.2f ms; up to %d draw calls; %s; %s"
		% [
			physics_slow,
			draw_calls,
			RenderingServer.get_video_adapter_name(),
			OS.get_processor_name(),
		]
	)
	print(report)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("performance.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string(report + "\n")
		file.close()
	check(presentation.arena.spawned_count >= 70, "Most of the round's ball budget is delivered")
	check(average < 1000.0 / 60.0, "The heaviest state stays above 60 frames per second here")
	controls.queue_free()
	presentation.stop()
