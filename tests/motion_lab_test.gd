extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18088
	host.settings.websocket_port = 18089
	assert(host.start(false))
	var scenario: DebugScenario = root.get_node("DebugLauncher").scenario_for_id(&"motion_lab")
	assert(scenario != null and scenario.availability({}).available)
	var lab: Control = load(scenario.scene_path).instantiate()
	root.add_child(lab)
	await process_frame
	assert(lab.target_player_id.is_empty())
	assert(lab.get("_viewport").own_world_3d)
	var one: Dictionary = host.player_registry.join_player(1, "Player One", true)
	var two: Dictionary = host.player_registry.join_player(2, "Player Two", true)
	assert(lab.target_player_id == one.player.player_id)
	assert(host.websocket.motion_channel.target_player_id != two.player.player_id)
	var channel: MotionInputChannel = host.websocket.motion_channel
	var diagnostics := {"secure_context": true, "motion_support": true, "orientation_support": true, "motion_permission": "granted", "orientation_permission": "granted", "state": "live", "page_protocol": "https:", "hostname": "192.168.2.79", "websocket_protocol": "wss:", "websocket_status": "open"}
	assert(channel.handle(one.player, {"type": "motion_status", "subscription_id": channel.subscription_id, "diagnostics": diagnostics}, Time.get_ticks_msec()))
	var sample := {"orientation": [35, 70, -15], "absolute": false, "rotation_rate": [24, -18, 4], "acceleration": [2, -1, 0], "acceleration_gravity": [2, 8.8, 1], "interval_msec": 16, "screen_angle": 90, "orientation_age_msec": 0, "motion_age_msec": 0, "orientation_hz": 60, "motion_hz": 60}
	assert(channel.handle(one.player, {"type": "motion_sample", "subscription_id": channel.subscription_id, "sequence": 1, "sample": sample}, Time.get_ticks_msec()))
	await process_frame
	assert(lab.call("_has_orientation"))
	lab.recenter()
	assert(lab.get("_pose").is_equal_approx(Quaternion.IDENTITY))
	lab.reset_calibration()
	assert(lab.get("_neutral").is_equal_approx(Quaternion.IDENTITY))
	var plots: Array = lab.get("_plots")
	for index: int in range(150):
		plots[0].append_sample([index, null, 0])
	assert(plots[0].history.size() == 120)
	host.player_registry.leave_connection(1)
	var replacement: Dictionary = host.player_registry.join_player(3, "Replacement", true)
	assert(replacement.player.seat == 1 and lab.target_player_id == one.player.player_id)
	lab.bind_player_one()
	assert(lab.target_player_id == replacement.player.player_id)
	lab.queue_free()
	await process_frame
	assert(channel.target_player_id.is_empty() and channel.latest.is_empty())
	host.stop()
	print("Motion lab identity, scene, calibration and cleanup checks passed")
	quit(0)
