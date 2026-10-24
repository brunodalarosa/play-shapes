extends TestScript
## The shared-screen scene of Bubbles and jellyfishes 3D: it frames the plane edge to edge, lets
## the bubbles enter, beats the countdown, shows GO and the timer, keeps a nameplate on every
## bubble, shows ranked results with every player, and asks to return to the lobby.

const SCENE: PackedScene = preload("res://minigames/004_3d_bubbles/3d_bubbles.tscn")


func _run() -> void:
	var scene := SCENE.instantiate() as Bubbles3DPresentation
	root.add_child(scene)
	await process_frame

	_check_framing(scene)
	check(scene.get_node("World/Scenery").get_child_count() >= 20, "The seabed is dressed")
	check(
		scene.water.top_colour == scene.controller.tuning.water_top_colour,
		"The water look comes from the tuning",
	)

	var tuning := Bubbles3DTuning.new()
	tuning.instructions_seconds = 0.5
	tuning.countdown_seconds = 1.0
	tuning.round_duration_seconds = 10.0
	tuning.final_timer_emphasis_seconds = 10
	# No creatures, so only the catch below scores.
	tuning.starting_jellyfish = 0
	tuning.jellyfish_low_spawn_rate = 0.0
	tuning.jellyfish_high_spawn_rate = 0.0
	tuning.pufferfish_start_spawn_rate = 0.0
	tuning.pufferfish_max_spawn_rate = 0.0
	scene.controller.tuning = tuning
	var players := [
		{ "player_id": "a", "name": "Ada", "seat": 1, "state": "connected" },
		{ "player_id": "b", "name": "Bo", "seat": 2, "state": "connected" },
		{ "player_id": "c", "name": "Cy", "seat": 3, "state": "connected" },
	]
	check(scene.start_round(players, Time.get_ticks_msec()).accepted, "A round starts")
	check(not scene.start_round(players, Time.get_ticks_msec()).accepted, "Only once")
	var bubble := scene.player_arena.get_bubble("a")
	check(absf(bubble.position.x) > 9.6, "Bubbles enter from beyond the side walls")
	check(bubble.freeze, "Entering bubbles do not collide")
	var nameplates := scene.get_node("Hud/Nameplates")
	check(nameplates.get_child_count() == 3, "Every bubble has a nameplate")
	check((nameplates.get_child(0) as Label).text == "Ada", "A nameplate shows the player name")

	await _wait_for(scene, &"countdown", 3000)
	check(absf(bubble.position.x) <= 9.6, "The entrance ends inside the plane")
	await _wait_for(scene, &"active", 3000)
	check(scene.audio_event_count(&"beat") >= 1, "The countdown beats")
	check((scene.get_node("Hud/CenterCue") as Label).text == "GO", "GO shows when play starts")
	var timer := scene.get_node("Hud/Timer") as Label
	check(timer.visible and int(timer.text) in [9, 10], "The timer shows whole seconds left")
	check(not bubble.freeze, "Bubbles move once play starts")
	await process_frame
	var plate := nameplates.get_child(0) as ScreenFollowLabel
	var anchor := scene.camera.unproject_position(bubble.global_position)
	var plate_bottom := plate.global_position.y + plate.size.y
	check(plate.visible and plate_bottom < anchor.y, "A nameplate sits above its bubble")

	var beats := scene.audio_event_count(&"beat")
	scene.controller.record_jellyfish_capture("b", Time.get_ticks_msec())
	await create_timer(1.2).timeout
	check(scene.audio_event_count(&"beat") > beats, "The final seconds beat")
	check(scene.audio_event_count(&"collect") == 1, "A catch plays its sound")

	await _wait_for(scene, &"results", 12000)
	var rows := scene.get_node("Hud/Results/Margin/Column/ResultsList")
	await process_frame
	check(scene.get_node("Hud/Results").visible, "Results show at zero")
	check(rows.get_child_count() == 3, "Results list every player")
	var first_name := (rows.get_child(0) as HBoxContainer).get_child(2) as Label
	check(first_name.text == "Bo", "The best catch ranks first")
	check(not nameplates.visible, "Nameplates hide behind the results")
	var returned := [false]
	scene.controller.return_to_lobby_requested.connect(
		func() -> void:
			returned[0] = true,
	)
	(scene.get_node("Hud/Results/Margin/Column/ReturnToLobby") as Button).pressed.emit()
	check(returned[0], "Return to lobby asks the host to go back")


func _check_framing(scene: Bubbles3DPresentation) -> void:
	var view := scene.get_viewport_rect().size
	var corner := scene.camera.unproject_position(Vector3(9.6, 5.4, 0.0))
	if view.x / view.y >= 16.0 / 9.0:
		check(absf(corner.y) < 2.0, "A wide screen shows the plane's full height")
	else:
		check(absf(corner.x - view.x) < 2.0, "A narrow screen shows the plane's full width")


func _wait_for(scene: Bubbles3DPresentation, phase: StringName, limit_msec: int) -> void:
	var give_up := Time.get_ticks_msec() + limit_msec
	while scene.controller.phase_name() != phase and Time.get_ticks_msec() < give_up:
		await process_frame
	check(scene.controller.phase_name() == phase, "The round reaches %s" % phase)
