extends TestScript
## The F12 launcher's simulated Tilt Shift 3D review: it plays a whole shift with ten synthetic
## players and moving paddles, creates no registered phones or motion subscriptions, never makes
## the real minigame launchable, restarts fresh and returns to the lobby.


func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18080
	host.settings.websocket_port = 18081
	if not check(host.start(false), "Test LAN services start"):
		return
	var review: DebugScenario = launcher.scenario_for_id(&"tilt_shift_3d_review")
	if not check(
		review != null and review.minigame_id.is_empty(),
		"Tilt Shift 3D review is separate from real minigame launch",
	):
		return
	var original: TiltShift3DTuning = host.active_presets.tilt_shift_3d
	var quick: TiltShift3DTuning = original.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	quick.round_duration_seconds = 1.0
	quick.physics.ball_count = 2
	quick.physics.delivery_cutoff_seconds = 0.0
	quick.flow.countdown_seconds = 0.1
	quick.flow.start_seconds = 0.1
	host.active_presets.tilt_shift_3d = quick
	if not check(launcher.launch(&"tilt_shift_3d_review"), "Simulated factory launches"):
		return
	await scene_changed
	var review_id := current_scene.get_instance_id()
	var factory: TiltShift3DPresentation = current_scene._factory
	check(
		factory.arena.controller.snapshot().players.size() == 10,
		"The review contains ten synthetic players",
	)
	check(
		launcher.marker_text().contains("simulated controls")
		and not host.minigame_availability(&"tilt_shift_3d").available,
		"Simulated marker persists without granting normal launch eligibility",
	)
	await _progresses(factory)
	check(
		host.players().is_empty() and host.websocket.motion_channels.is_empty(),
		"Simulated rounds never create registered phones or motion subscriptions",
	)
	if not check(launcher.restart_scenario(), "Simulated factory restarts"):
		return
	await scene_changed
	check(current_scene.get_instance_id() != review_id, "Restart creates a fresh factory")
	host.active_presets.tilt_shift_3d = original
	launcher.return_to_lobby()
	await scene_changed
	check(current_scene.scene_file_path == launcher.LOBBY_PATH, "Review return loads the lobby")
	check(host.accepting_new_players, "Review return restores onboarding")
	host.stop()


func _progresses(factory: TiltShift3DPresentation) -> void:
	var active: Dictionary[int, bool] = { }
	var moving: Dictionary[int, bool] = { }
	var deadline := Time.get_ticks_msec() + 15000
	var state := factory.arena.controller.snapshot()
	while state.phase != &"finished" and Time.get_ticks_msec() < deadline:
		if state.phase == &"active":
			active[state.round_number] = true
			for body: TiltShift3DPaddleBody in factory.arena.paddle_bodies():
				if body.auto_rate == 0.0 and absf(body.applied_angle) > 0.01:
					moving[state.round_number] = true
		await process_frame
		state = factory.arena.controller.snapshot()
	check(active.size() == state.round_count, "Every simulated round reaches active play")
	check(moving.size() == state.round_count, "Simulated controls move paddles in every round")
	check(state.phase == &"finished", "Simulated rounds advance through shift results")
