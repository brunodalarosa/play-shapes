extends SceneTree
## Fixture-only observer messages test real socket authorization without production APIs.


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = 18090
	host.settings.websocket_port = 18091
	assert(host.start(false))
	var lab: Control = load("res://debug/motion_lab/motion_lab.tscn").instantiate()
	root.add_child(lab)
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(
		func() -> void:
			var channel: MotionInputChannel = host.websocket.motion_channel
			for player: Dictionary in host.players():
				host.websocket._send_to_player(
					player.player_id,
					{
						"type": "motion_observed",
						"target": channel.target_player_id,
						"samples": channel.sample_count,
						"latest": channel.latest,
						"diagnostics": channel.diagnostics,
						"subscription_id": channel.subscription_id,
					},
				),
	)
	root.add_child(timer)
	timer.start()
	print("Motion lab fixture ready")
