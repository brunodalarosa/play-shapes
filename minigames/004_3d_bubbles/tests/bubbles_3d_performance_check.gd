extends TestScript
## Measures the shared screen of Bubbles and jellyfishes 3D at its heaviest: ten players with the
## most caught jellyfishes drawn, the free-jellyfish cap reached and pufferfishes crossing. Run
## without --headless on the target machine; vsync is turned off so the frame time is the work.

const SCENE: PackedScene = preload("res://minigames/004_3d_bubbles/3d_bubbles.tscn")
const SAMPLE_SECONDS := 6.0


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene := SCENE.instantiate() as Bubbles3DPresentation
	root.add_child(scene)
	await process_frame
	var tuning := scene.controller.tuning.duplicate() as Bubbles3DTuning
	tuning.instructions_seconds = 0.0
	tuning.countdown_seconds = 0.0
	tuning.starting_jellyfish = tuning.max_free_jellyfish
	tuning.jellyfish_low_spawn_rate = 10.0
	tuning.jellyfish_high_spawn_rate = 15.0
	tuning.pufferfish_start_spawn_rate = 0.6
	tuning.pufferfish_max_spawn_rate = 0.6
	scene.controller.tuning = tuning
	var players: Array = []
	for index: int in 10:
		var name := "Player %d" % (index + 1)
		players.append({ "player_id": "p%d" % index, "name": name, "seat": index + 1 })
	scene.start_round(players, Time.get_ticks_msec())
	while scene.controller.phase_name() != &"active":
		await process_frame
	for index: int in 10:
		for _catch: int in tuning.captured_visual_cap + index:
			scene.controller.record_jellyfish_capture("p%d" % index, Time.get_ticks_msec())
	await create_timer(1.0).timeout

	var frames: Array[float] = []
	var draw_calls := 0
	var last := Time.get_ticks_usec()
	var end := last + roundi(SAMPLE_SECONDS * 1_000_000.0)
	while Time.get_ticks_usec() < end:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_calls = maxi(draw_calls, int(calls))
	frames.sort()
	var total := 0.0
	for frame: float in frames:
		total += frame
	var average := total / frames.size()
	var slow := frames[floori(frames.size() * 0.95)]
	var free := scene.creature_arena.jellyfish_count()
	print(
		"[GODOT-RUNTIME] Bubbles 3D, 10 players, %d free and %d caught jellyfishes drawn: "
		% [free, 10 * tuning.captured_visual_cap]
		+ "average frame %.2f ms (%.0f fps), 95th percentile %.2f ms, up to %d draw calls, %s"
		% [average, 1000.0 / average, slow, draw_calls, RenderingServer.get_video_adapter_name()]
	)
	check(free >= tuning.max_free_jellyfish - 5, "The free-jellyfish cap is nearly reached")
	check(average < 1000.0 / 60.0, "The heaviest state stays above 60 frames per second here")
