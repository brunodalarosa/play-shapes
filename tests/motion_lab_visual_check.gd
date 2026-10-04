extends TestScript
## Rendered desktop evidence using explicitly synthetic sensor input.


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18580
	host.settings.websocket_port = 18581
	if not check(host.start(false), "The host starts on the capture ports"):
		return
	var player: Dictionary = host.player_registry.join_player(900, "Preview phone", true)
	check(player.accepted, "The registry accepts the preview phone")
	var lab: Control = load("res://debug/motion_lab/motion_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	check(lab.target_player_id == player.player.player_id, "The lab targets the preview phone")
	var channel: MotionInputChannel = host.websocket.motion_channel
	channel.diagnostics = {
		"secure_context": true,
		"page_protocol": "https:",
		"hostname": "192.168.2.79",
		"websocket_protocol": "wss:",
		"websocket_status": "open",
		"motion_support": true,
		"orientation_support": true,
		"motion_permission": "granted",
		"orientation_permission": "granted",
		"state": "live",
	}
	channel.latest = {
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
	for index: int in range(80):
		channel.received_at = Time.get_ticks_msec()
		channel.first_received_at = channel.received_at - 3000
		channel.sample_count = index + 1
		channel.latest.acceleration = [sin(index * 0.1) * 5, cos(index * 0.1) * 3, 1]
		channel.changed.emit()
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results/motion-lab")
	check(
		root
		.get_texture()
		.get_image()
		.save_png("res://test-results/motion-lab/desktop-synthetic.png")
		== OK,
		"The capture is saved",
	)
	print("Synthetic motion lab desktop capture saved")
	lab.queue_free()
	await process_frame
	host.stop()
