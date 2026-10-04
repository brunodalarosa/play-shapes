extends TestScript


func _run() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18088
	host.settings.websocket_port = 18089
	if not check(host.start(false), "The host starts on the test ports"):
		return
	var scenario: DebugScenario = root.get_node("DebugLauncher").scenario_for_id(&"motion_lab")
	if not check(
		scenario != null and scenario.availability({ }).available,
		"The motion lab scenario exists and is available",
	):
		return
	var lab: Control = load(scenario.scene_path).instantiate()
	root.add_child(lab)
	await process_frame
	check(lab.target_player_id.is_empty(), "The lab targets nobody before a player joins")
	check(lab.get("_viewport").own_world_3d, "The lab renders its model in a world of its own")
	var one: Dictionary = host.player_registry.join_player(1, "Player One", true)
	var two: Dictionary = host.player_registry.join_player(2, "Player Two", true)
	check(lab.target_player_id == one.player.player_id, "The lab targets the first player to join")
	check(
		host.websocket.motion_channel.target_player_id != two.player.player_id,
		"The motion channel does not target the second player",
	)
	var channel: MotionInputChannel = host.websocket.motion_channel
	var diagnostics := {
		"secure_context": true,
		"motion_support": true,
		"orientation_support": true,
		"motion_permission": "granted",
		"orientation_permission": "granted",
		"state": "live",
		"page_protocol": "https:",
		"hostname": "192.168.2.79",
		"websocket_protocol": "wss:",
		"websocket_status": "open",
	}
	check(
		channel.handle(
			one.player,
			{
				"type": "motion_status",
				"subscription_id": channel.subscription_id,
				"diagnostics": diagnostics,
			},
			Time.get_ticks_msec(),
		),
		"The channel accepts a status message from the target player",
	)
	var sample := {
		"orientation": [35, 70, -15],
		"absolute": false,
		"rotation_rate": [24, -18, 4],
		"acceleration": [2, -1, 0],
		"acceleration_gravity": [2, 8.8, 1],
		"interval_msec": 16,
		"screen_angle": 90,
		"orientation_age_msec": 0,
		"motion_age_msec": 0,
		"orientation_hz": 60,
		"motion_hz": 60,
	}
	check(
		channel.handle(
			one.player,
			{
				"type": "motion_sample",
				"subscription_id": channel.subscription_id,
				"sequence": 1,
				"sample": sample,
			},
			Time.get_ticks_msec(),
		),
		"The channel accepts a motion sample from the target player",
	)
	await process_frame
	check(lab.call("_has_orientation"), "The lab has an orientation after a sample")
	lab.recenter()
	check(
		lab.get("_pose").is_equal_approx(Quaternion.IDENTITY),
		"Recentering makes the current pose the identity",
	)
	lab.reset_calibration()
	check(
		lab.get("_neutral").is_equal_approx(Quaternion.IDENTITY),
		"Resetting the calibration clears the neutral pose",
	)
	var plots: Array = lab.get("_plots")
	for index: int in range(150):
		plots[0].append_sample([index, null, 0])
	check(plots[0].history.size() == 120, "A plot keeps only its last 120 samples")
	host.player_registry.leave_connection(1)
	var replacement: Dictionary = host.player_registry.join_player(3, "Replacement", true)
	check(
		replacement.player.seat == 1 and lab.target_player_id == one.player.player_id,
		"A replacement takes seat one while the lab keeps its target",
	)
	lab.bind_player_one()
	check(
		lab.target_player_id == replacement.player.player_id,
		"Binding to player one targets the replacement",
	)
	lab.queue_free()
	await process_frame
	check(
		channel.target_player_id.is_empty() and channel.latest.is_empty(),
		"Freeing the lab clears the channel's target and its latest sample",
	)
	host.stop()
