extends TestScript
## The generic minigame protocol seam of the WebSocket service: setting a protocol makes it the
## active one and wires its send and broadcast requests; clearing it detaches it, and clearing a
## different protocol changes nothing.


class FakeProtocol:
	extends MinigameProtocol

	var detached := false


	func handles(message_type: String) -> bool:
		return message_type == "fake_move"


	func detach() -> void:
		detached = true


func _run() -> void:
	var service := WebsocketService.new()
	root.add_child(service)
	var protocol := FakeProtocol.new()
	service.set_minigame_protocol(protocol)
	check(service._active_protocol == protocol, "A set minigame protocol is the active one")
	check(
		protocol.send_requested.is_connected(service._send_to_player)
		and protocol.broadcast_requested.is_connected(service._broadcast_gameplay_snapshots),
		"The service answers the protocol's send and broadcast requests",
	)
	check(
		protocol.snapshot_for("anyone").type == "lobby",
		"The base snapshot waits for the next game",
	)

	service.clear_minigame_protocol(FakeProtocol.new())
	check(service._active_protocol == protocol, "Clearing another protocol changes nothing")

	var replacement := FakeProtocol.new()
	service.set_minigame_protocol(replacement)
	check(protocol.detached, "Setting a new protocol detaches the old one")
	check(
		not protocol.send_requested.is_connected(service._send_to_player),
		"A replaced protocol can no longer send",
	)
	service.clear_minigame_protocol(replacement)
	check(
		service._active_protocol == null and replacement.detached,
		"Clearing the protocol detaches it and leaves no active protocol",
	)
