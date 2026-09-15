class_name WebsocketService
extends Node
## Versioned browser transport. Identity mutations are delegated to PlayerRegistry.

signal connection_count_changed(count: int)

const MAX_PACKET_BYTES := 1024

var _server: TCPServer = TCPServer.new()
var _clients: Array[Dictionary] = []
var _settings: NetworkingTuning
var _registry: PlayerRegistry
var _accepting_new_players: Callable
var _next_id: int = 1

func start(settings: NetworkingTuning, registry: PlayerRegistry,
		accepting_new_players: Callable) -> Error:
	_settings = settings
	_registry = registry
	_accepting_new_players = accepting_new_players
	return _server.listen(settings.websocket_port, "*")

func stop() -> void:
	_server.stop()
	for client: Dictionary in _clients:
		_disconnect_player(client)
		client.tcp.disconnect_from_host()
	_clients.clear()
	connection_count_changed.emit(0)

func _process(_delta: float) -> void:
	if not _server.is_listening():
		return
	for unused: int in range(8):
		if not _server.is_connection_available():
			break
		var tcp := _server.take_connection()
		if _clients.size() >= _settings.max_connections:
			tcp.disconnect_from_host()
			continue
		var peer := WebSocketPeer.new()
		peer.inbound_buffer_size = 4096
		peer.outbound_buffer_size = 4096
		peer.max_queued_packets = 8
		peer.heartbeat_interval = 5.0
		if peer.accept_stream(tcp) != OK:
			tcp.disconnect_from_host()
			continue
		_clients.append({
			"peer": peer,
			"tcp": tcp,
			"welcomed": false,
			"connection_id": 0,
			"created": Time.get_ticks_msec(),
		})
	for index: int in range(_clients.size() - 1, -1, -1):
		var client: Dictionary = _clients[index]
		var peer: WebSocketPeer = client.peer
		peer.poll()
		if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED or (
				not client.welcomed and Time.get_ticks_msec() - client.created > _settings.request_timeout_seconds * 1000):
			_drop(index)
			continue
		if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		for unused: int in range(8):
			if peer.get_available_packet_count() == 0:
				break
			var packet := peer.get_packet()
			var parser := JSON.new()
			if not peer.was_string_packet() or packet.size() > MAX_PACKET_BYTES or parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary:
				peer.close(1008, "Expected protocol JSON")
				break
			_handle_message(client, parser.data)

func _handle_message(client: Dictionary, message: Dictionary) -> void:
	var peer: WebSocketPeer = client.peer
	if not client.welcomed:
		if message.get("type") != "hello" or message.get("protocol") != 1:
			peer.close(1008, "Unsupported handshake")
			return
		var connection_id := _next_id
		_next_id += 1
		client.connection_id = connection_id
		client.welcomed = true
		var resume := {"accepted": false, "code": &"join_required", "message": "Enter a name to join"}
		if message.has("reconnect_token") or message.has("session_id"):
			resume = _registry.resume_player(
				connection_id,
				message.get("session_id"),
				message.get("reconnect_token")
			)
		if resume.accepted:
			_close_replaced_connection(resume.replaced_connection_id, connection_id)
		peer.send_text(JSON.stringify({
			"type": "welcome",
			"protocol": 1,
			"connection_id": connection_id,
			"session_id": _registry.session_id,
			"resume_status": str(resume.status if resume.accepted else resume.code),
			"message": "Connected to Play Shapes" if resume.accepted else resume.message,
			"player": resume.get("player"),
			"reconnect_token": resume.get("reconnect_token"),
		}))
		_emit_count()
		return

	match message.get("type"):
		"join":
			var result := _registry.join_player(
				client.connection_id,
				message.get("name"),
				_accepting_new_players.call()
			)
			if result.accepted:
				peer.send_text(JSON.stringify({
					"type": "join_accepted",
					"session_id": _registry.session_id,
					"player": result.player,
					"reconnect_token": result.reconnect_token,
				}))
			else:
				_send_rejection(peer, "join_rejected", result)
		"leave":
			var result := _registry.leave_connection(client.connection_id)
			if result.accepted:
				peer.send_text(JSON.stringify({"type": "left", "message": "You left the lobby"}))
			else:
				_send_rejection(peer, "error", result)
		_:
			_send_rejection(peer, "error", {
				"code": &"unsupported_message",
				"message": "That action is not supported",
			})

func _send_rejection(peer: WebSocketPeer, response_type: String, result: Dictionary) -> void:
	peer.send_text(JSON.stringify({
		"type": response_type,
		"code": str(result.code),
		"message": result.message,
	}))

func _close_replaced_connection(old_connection_id: int, new_connection_id: int) -> void:
	if old_connection_id == PlayerRegistry.DISCONNECTED or old_connection_id == new_connection_id:
		return
	for client: Dictionary in _clients:
		if client.connection_id == old_connection_id:
			client.peer.close(4000, "Player resumed in another tab")
			return

func _drop(index: int) -> void:
	var client: Dictionary = _clients[index]
	_disconnect_player(client)
	client.tcp.disconnect_from_host()
	_clients.remove_at(index)
	_emit_count()

func _disconnect_player(client: Dictionary) -> void:
	if client.welcomed:
		_registry.disconnect_connection(client.connection_id)

func _emit_count() -> void:
	var count: int = 0
	for client: Dictionary in _clients:
		if client.welcomed:
			count += 1
	connection_count_changed.emit(count)

func _exit_tree() -> void:
	stop()
