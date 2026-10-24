extends TestScript

const Service = preload("res://host/websocket_service.gd")


func _run() -> void:
	var service := Service.new()
	root.add_child(service)
	var bubbles := Bubbles3DRoundController.new()
	root.add_child(bubbles)
	bubbles.tuning = Bubbles3DTuning.new()
	bubbles.tuning.instructions_seconds = 0.0
	bubbles.tuning.countdown_seconds = 0.0
	bubbles.start_round(
		[
			{ "player_id": "p0", "name": "First", "seat": 1 },
			{ "player_id": "p1", "name": "Second", "seat": 2 },
		],
		0,
	)
	bubbles.complete_entrance(0)
	bubbles.advance(0)
	var protocol := Bubbles3DProtocol.new(bubbles)
	service.set_minigame_protocol(protocol)
	check(
		service._active_protocol == service._minigame_protocol
		and service._active_protocol.snapshot_for("p0").type == "bubbles_3d_snapshot",
		"Bubbles 3D is the only active gameplay protocol",
	)
	check(
		protocol.send_requested.is_connected(service._send_to_player)
		and protocol.broadcast_requested.is_connected(service._broadcast_gameplay_snapshots),
		"Active minigame protocol connects its send and broadcast signals",
	)
	service.clear_minigame_protocol(protocol)
	check(
		service._active_protocol == null and service._minigame_protocol == null,
		"Leaving Bubbles 3D clears active routing",
	)
