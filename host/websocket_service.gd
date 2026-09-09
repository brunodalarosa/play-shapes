class_name WebsocketService
extends Node
## Phase 1 accepts only a versioned hello. No client can submit game state.

signal connection_count_changed(count: int)

var _server: TCPServer = TCPServer.new()
var _clients: Array[Dictionary] = []
var _settings: HostSettings
var _next_id: int = 1

func start(settings: HostSettings) -> Error:
	_settings = settings
	return _server.listen(settings.websocket_port, "*")

func stop() -> void:
	_server.stop()
	for client: Dictionary in _clients:
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
		_clients.append({"peer": peer, "tcp": tcp, "welcomed": false, "created": Time.get_ticks_msec()})
	for index: int in range(_clients.size() - 1, -1, -1):
		var client: Dictionary = _clients[index]
		var peer: WebSocketPeer = client.peer
		peer.poll()
		if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED or (not client.welcomed and Time.get_ticks_msec() - client.created > _settings.request_timeout_seconds * 1000):
			client.tcp.disconnect_from_host()
			_clients.remove_at(index)
			_emit_count()
			continue
		if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		for unused: int in range(8):
			if peer.get_available_packet_count() == 0:
				break
			var packet := peer.get_packet()
			var parser := JSON.new()
			if not peer.was_string_packet() or packet.size() > 1024 or parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary:
				peer.close(1008, "Expected hello JSON")
				break
			var message: Dictionary = parser.data
			if client.welcomed or message.get("type") != "hello" or message.get("protocol") != 1:
				peer.close(1008, "Unsupported message")
				break
			peer.send_text(JSON.stringify({"type": "welcome", "protocol": 1, "connection_id": _next_id, "message": "Hello world"}))
			_next_id += 1
			client.welcomed = true
			_emit_count()

func _emit_count() -> void:
	var count: int = 0
	for client: Dictionary in _clients:
		if client.welcomed:
			count += 1
	connection_count_changed.emit(count)

func _exit_tree() -> void:
	stop()
