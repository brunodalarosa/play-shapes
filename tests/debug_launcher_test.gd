extends TestScript
## Focused checks for registration and state transitions without starting LAN services.


func _run() -> void:
	var launcher := root.get_node("DebugLauncher")
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18080
	host.settings.websocket_port = 18081
	if not check(host.start(false), "Test LAN services start"):
		return
	var original_host_id := host.get_instance_id()
	var animation_lab: DebugScenario = launcher.scenario_for_id(&"squircle_animation_lab")
	var bubbles: DebugScenario = launcher.scenario_for_id(&"one_player_bubbles")
	if not check(animation_lab != null, "Animation lab is registered"):
		return
	if not check(
		animation_lab.availability({ }).available,
		"Implemented animation lab is available",
	):
		return
	if not check(
		launcher.scenario_for_id(&"squircle_render_preview") == null,
		"Retired comparison is not registered",
	):
		return
	if not check(
		launcher.scenario_for_id(&"one_player_simon") == null,
		"Retired game has no debug scenario",
	):
		return
	if not check(
		bubbles != null and bubbles.minigame_id == &"bubbles",
		"One-player Bubbles is registered as a separate minigame debug scenario",
	):
		return
	if not check(
		not bubbles.availability({ "one_registered_player": false }).available \
				and bubbles.availability({ "one_registered_player": true }).available,
		"Bubbles debug requires exactly one registered player",
	):
		return
	if not check(not launcher.restart_scenario(), "Restart is disabled outside a debug scenario"):
		return
	if not check(launcher.active_scenario == null, "Normal startup has no debug scenario"):
		return
	if not check(launcher.get_tree().paused == false, "Launcher does not pause the scene tree"):
		return
	var f12 := InputEventKey.new()
	f12.keycode = KEY_F12
	f12.pressed = true
	launcher._input(f12)
	if not check(launcher.is_open(), "F12 opens the overlay"):
		return
	if not check(
		launcher.get_tree().paused == false,
		"Opening the overlay does not pause the scene tree",
	):
		return
	launcher._input(f12)
	if not check(not launcher.is_open(), "F12 closes the overlay"):
		return

	var fixture := DebugScenario.new(
		&"test_fixture",
		"Clean-state fixture",
		"res://tests/fixtures/debug_scenario.tscn",
	)
	launcher.register_scenario(fixture)
	if not check(launcher.launch(&"test_fixture"), "Available scenario launches immediately"):
		return
	await scene_changed
	var first_scene_id := current_scene.get_instance_id()
	if not check(
		launcher.marker_text() == "DEBUG — Clean-state fixture",
		"Debug scenario marker persists",
	):
		return
	if not check(
		host.running and host.get_instance_id() == original_host_id,
		"LAN service owner survives launch",
	):
		return
	if not check(launcher.restart_scenario(), "Current scenario restarts"):
		return
	await scene_changed
	if not check(
		current_scene.get_instance_id() != first_scene_id,
		"Restart reconstructs the scenario scene",
	):
		return
	if not check(
		host.running and host.get_instance_id() == original_host_id,
		"LAN service owner survives restart",
	):
		return
	launcher.return_to_lobby()
	await scene_changed
	if not check(current_scene.scene_file_path == launcher.LOBBY_PATH, "Return loads the lobby"):
		return
	if not check(launcher.marker_text().is_empty(), "Lobby return removes the debug marker"):
		return
	if not check(
		host.running and host.get_instance_id() == original_host_id,
		"LAN service owner survives lobby return",
	):
		return
	var tilt_review: DebugScenario = launcher.scenario_for_id(&"tilt_shift_review")
	if not check(
		tilt_review != null and tilt_review.minigame_id.is_empty(),
		"Tilt Shift review is separate from real minigame launch",
	):
		return
	var original_profile: TiltShiftTuning = host.active_presets.tilt_shift
	var review_profile: TiltShiftTuning = original_profile.duplicate_deep(
		Resource.DEEP_DUPLICATE_ALL
	)
	review_profile.round_duration_seconds = 1.0
	review_profile.physics.ball_count = 2
	review_profile.physics.delivery_cutoff_seconds = 0.0
	review_profile.flow.countdown_seconds = 0.1
	review_profile.flow.start_seconds = 0.1
	host.active_presets.tilt_shift = review_profile
	var review_launched: bool = launcher.launch(&"tilt_shift_review")
	if not check(review_launched, "Simulated factory launches without phones"):
		return
	await scene_changed
	var review_id := current_scene.get_instance_id()
	var factory: TiltShiftPresentation = current_scene._factory
	if not check(
		factory.arena.controller.snapshot().players.size() == 10,
		"Factory review contains ten synthetic operators",
	):
		return
	if not check(
		host.players().is_empty() and host.websocket.motion_channels.is_empty(),
		"Factory review creates no registered phones or motion subscriptions",
	):
		return
	if not check(
		launcher.marker_text().contains("simulated controls")
		and not host.minigame_availability(&"tilt_shift").available,
		"Simulated marker persists without granting normal launch eligibility",
	):
		return
	if not await _review_progresses(factory):
		return
	check(
		host.players().is_empty() and host.websocket.motion_channels.is_empty(),
		"Simulated rounds never create registered phones or motion subscriptions",
	)
	if not check(launcher.restart_scenario(), "Simulated factory restarts"):
		return
	await scene_changed
	if not check(current_scene.get_instance_id() != review_id, "Restart creates a fresh factory"):
		return
	if not await _review_countdown(current_scene._factory):
		return
	host.active_presets.tilt_shift = original_profile
	launcher.return_to_lobby()
	await scene_changed
	check(current_scene.scene_file_path == launcher.LOBBY_PATH, "Factory return loads the lobby")
	check(launcher.marker_text().is_empty(), "Factory return removes the simulated marker")
	check(host.accepting_new_players, "Factory return restores onboarding")
	host.stop()


func _review_countdown(factory: TiltShiftPresentation) -> bool:
	var deadline := Time.get_ticks_msec() + 1000
	while factory.arena.controller.snapshot().phase == &"preparing":
		if Time.get_ticks_msec() >= deadline:
			break
		await process_frame
	return check(
		factory.arena.controller.snapshot().phase == &"countdown"
		and not factory.participant_panel.visible,
		"Simulated readiness leaves the participant panel without a force start or timeout",
	)


func _review_progresses(factory: TiltShiftPresentation) -> bool:
	if not await _review_countdown(factory):
		return false
	var active_rounds: Dictionary[int, bool] = { }
	var moving_rounds: Dictionary[int, bool] = { }
	var delivering_rounds: Dictionary[int, bool] = { }
	var deadline := Time.get_ticks_msec() + 10000
	var state := factory.arena.controller.snapshot()
	while state.phase != &"finished" and Time.get_ticks_msec() < deadline:
		if state.phase == &"active":
			active_rounds[state.round_number] = true
			for body: TiltShiftPaddleBody in factory.arena.paddle_bodies():
				if body.auto_rate == 0.0 and absf(body.applied_angle) > 0.01:
					moving_rounds[state.round_number] = true
			if factory.arena.spawned_count > 0:
				delivering_rounds[state.round_number] = true
		await process_frame
		state = factory.arena.controller.snapshot()
	check(active_rounds.size() == state.round_count, "Every simulated round reaches active play")
	check(
		moving_rounds.size() == state.round_count,
		"Simulated controls move paddles in every round",
	)
	check(delivering_rounds.size() == state.round_count, "Every simulated round delivers balls")
	return check(state.phase == &"finished", "Simulated rounds advance through shift results")
