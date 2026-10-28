extends TestScript
## A phone that resumes into a Flappy Race receives its welcome with the race snapshot, which
## carries the whole course and is far larger than a lobby message.

const HTTP_PORT := 18140
const WEBSOCKET_PORT := 18141


func _run() -> void:
	var host := root.get_node("SessionHost")
	host.settings = NetworkingTuning.new()
	host.settings.http_port = HTTP_PORT
	host.settings.websocket_port = WEBSOCKET_PORT
	if not check(host.boot(BootRequest.new([&"servers_this_pc"])), "This-PC servers start"):
		return

	var registry: PlayerRegistry = host.player_registry
	var joined := registry.join_player(-1, "Racer", true)
	registry.disconnect_connection(-1)
	var race := FlappyRaceController.new()
	root.add_child(race)
	race.tuning = load("res://minigames/006_flappy_race/tuning/Default.tres")
	race.start_race([joined.player], 3, Time.get_ticks_msec())
	var protocol := FlappyRaceProtocol.new(race)
	host.register_minigame_protocol(protocol)
	var size := JSON.stringify(protocol.snapshot_for(joined.player.player_id)).length()
	check(size > 8192, "The race snapshot is large (%d bytes)" % size)

	var client := WebSocketPeer.new()
	client.connect_to_url("ws://127.0.0.1:%d" % WEBSOCKET_PORT)
	var hello := {
		"type": "hello",
		"protocol": 1,
		"reconnect_token": joined.reconnect_token,
		"session_id": registry.session_id,
	}
	var welcome := { }
	var give_up := Time.get_ticks_msec() + 5000
	var sent := false
	while welcome.is_empty() and Time.get_ticks_msec() < give_up:
		await process_frame
		client.poll()
		if client.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		if not sent:
			client.send_text(JSON.stringify(hello))
			sent = true
		while client.get_available_packet_count() > 0:
			var message: Variant = JSON.parse_string(client.get_packet().get_string_from_utf8())
			if message is Dictionary and message.get("type") == "welcome":
				welcome = message
	check(welcome.get("resume_status") == "resumed", "The phone resumes its racer")
	var gameplay: Dictionary = welcome.get("gameplay", { })
	check(gameplay.get("type") == FlappyRaceProtocol.SNAPSHOT_TYPE, "With the race snapshot")
	check(gameplay.get("course", { }).has("flight"), "Which carries the course")

	client.close()
	host.unregister_minigame_protocol(protocol)
	host.stop()
