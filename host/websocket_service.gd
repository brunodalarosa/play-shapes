class_name WebsocketService
extends Node
## Versioned browser transport. Identity mutations are delegated to PlayerRegistry.

signal connection_count_changed(count: int)

const MAX_PACKET_BYTES := 8192 # One bounded 128-point Bubbles trace plus protocol envelope.
const FlashPoseProtocolScript = preload("res://host/flash_pose_protocol.gd")
const BubblesProtocolScript = preload("res://host/bubbles_protocol.gd")

var _server: TCPServer = TCPServer.new()
var _clients: Array[Dictionary] = []
var _settings: NetworkingTuning
var _registry: PlayerRegistry
var _accepting_new_players: Callable
var _next_id: int = 1
var _flash_pose_protocol: RefCounted
var _bubbles_protocol: RefCounted
var _active_protocol: RefCounted

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

func set_flash_pose_controller(controller: FlashPoseRoundController) -> void:
	_clear_bubbles_controller()
	_clear_flash_pose_controller()
	_flash_pose_protocol = FlashPoseProtocolScript.new(controller)
	_active_protocol = _flash_pose_protocol
	controller.phase_changed.connect(_on_flash_pose_phase_changed)
	controller.genuine_stop_started.connect(_on_flash_pose_challenge)
	controller.semantic_animation_updated.connect(_on_semantic_state_changed)
	controller.pose_evaluation_resolved.connect(_on_flash_pose_results)
	controller.round_results_ready.connect(_on_flash_pose_round_results)
	controller.return_to_lobby_requested.connect(_on_flash_pose_return_to_lobby)

func clear_flash_pose_controller(controller: FlashPoseRoundController) -> void:
	if _flash_pose_protocol != null and _flash_pose_protocol.controller == controller:
		_clear_flash_pose_controller()

func set_bubbles_controller(controller: BubblesRoundController) -> void:
	_clear_flash_pose_controller()
	_clear_bubbles_controller()
	_bubbles_protocol = BubblesProtocolScript.new(controller)
	_active_protocol = _bubbles_protocol
	controller.phase_changed.connect(_on_bubbles_phase_changed)
	controller.personal_state_changed.connect(_on_bubbles_personal_state_changed)
	controller.personal_visual_changed.connect(_on_bubbles_personal_visual_changed)
	controller.feedback_requested.connect(_on_bubbles_feedback)
	controller.return_to_lobby_requested.connect(_on_bubbles_return_to_lobby)
	_broadcast_gameplay_snapshots()

func clear_bubbles_controller(controller: BubblesRoundController) -> void:
	if _bubbles_protocol != null and _bubbles_protocol.controller == controller:
		_clear_bubbles_controller()

func send_lobby_state() -> void:
	for client: Dictionary in _clients:
		if client.welcomed and not _registry.player_for_connection(client.connection_id).is_empty():
			client.peer.send_text(JSON.stringify({"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}))

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
		peer.inbound_buffer_size = 16384
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
		var welcome := {
			"type": "welcome",
			"protocol": 1,
			"connection_id": connection_id,
			"session_id": _registry.session_id,
			"resume_status": str(resume.status if resume.accepted else resume.code),
			"message": "Connected to Play Shapes" if resume.accepted else resume.message,
			"player": resume.get("player"),
			"reconnect_token": resume.get("reconnect_token"),
		}
		if resume.accepted:
			welcome.gameplay = _active_protocol.snapshot_for(String(resume.player.player_id)) \
				if _active_protocol != null else {"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}
		peer.send_text(JSON.stringify(welcome))
		_emit_count()
		return

	match message.get("type"):
		"join":
			var result := _registry.join_player(
				client.connection_id,
				message.get("name"),
				_accepting_new_players.call(),
				Time.get_ticks_msec(),
				message.get("character_shape"),
				message.get("character_color")
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
		"pose_down", "pose_up":
			var player := _registry.player_for_connection(client.connection_id)
			var result: Dictionary = _active_protocol.handle_action(player, message, Time.get_ticks_msec()) \
				if _active_protocol == _flash_pose_protocol and _flash_pose_protocol != null else {"accepted": false, "code": &"game_unavailable", "message": "Flash? Pose! is not active"}
			if not result.accepted:
				_send_rejection(peer, "error", result)
		"bubbles_trace", "bubbles_charge":
			var player := _registry.player_for_connection(client.connection_id)
			var result: Dictionary = _active_protocol.handle_action(player, message, Time.get_ticks_msec()) \
				if _active_protocol == _bubbles_protocol and _bubbles_protocol != null else {"accepted": false, "code": &"game_unavailable", "message": "Bubbles is not active"}
			if not result.accepted:
				_send_rejection(peer, "error", result)
			elif message.get("type") == "bubbles_trace":
				peer.send_text(JSON.stringify({"type": "bubbles_trace_result", "action": result.action,
					"reason": result.reason, "charge": 0.0}))
				_send_gameplay_snapshot(peer, String(player.player_id))
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

func _send_gameplay_snapshot(peer: WebSocketPeer, player_id: String) -> void:
	var message: Dictionary = _active_protocol.snapshot_for(player_id) if _active_protocol != null \
		else {"type": "lobby", "state": "waiting", "message": "Waiting for the next game"}
	peer.send_text(JSON.stringify(message))

func _send_to_player(player_id: String, message: Dictionary) -> void:
	for client: Dictionary in _clients:
		if client.welcomed and _registry.player_for_connection(client.connection_id).get("player_id") == player_id:
			client.peer.send_text(JSON.stringify(message))
			return

func _broadcast_gameplay_snapshots() -> void:
	for client: Dictionary in _clients:
		if not client.welcomed:
			continue
		var player := _registry.player_for_connection(client.connection_id)
		if not player.is_empty():
			_send_gameplay_snapshot(client.peer, String(player.player_id))

func _on_flash_pose_phase_changed(phase: StringName, _snapshot: Dictionary) -> void:
	# Resolve and flash are covered by the personalized result message. Sending a
	# generic snapshot immediately afterward would erase that feedback on phones.
	if phase not in [&"resolve", &"flash_wait"]:
		_broadcast_gameplay_snapshots()

func _on_flash_pose_challenge(_stop_id: int, _direction: StringName, _available: Array[StringName]) -> void:
	var message: Dictionary = _flash_pose_protocol.challenge_message()
	for player: Dictionary in _flash_pose_protocol.controller.player_snapshot():
		_send_to_player(String(player.player_id), message)

func _on_semantic_state_changed(player_id: String, state: Dictionary) -> void:
	if _flash_pose_protocol == null:
		return
	var message: Dictionary = _flash_pose_protocol.charge_update_for(player_id, state)
	if not message.is_empty():
		_send_to_player(player_id, message)

func _on_flash_pose_results(stop_id: int, results: Array[Dictionary]) -> void:
	for result: Dictionary in results:
		var player_id := String(result.player_id)
		_send_to_player(player_id, _flash_pose_protocol.result_for(player_id, stop_id, results))

func _on_flash_pose_round_results(results: Dictionary) -> void:
	for player: Dictionary in _flash_pose_protocol.controller.player_snapshot():
		var player_id := String(player.player_id)
		_send_to_player(player_id, _flash_pose_protocol.results_message(player_id, results))

func _on_flash_pose_return_to_lobby() -> void:
	send_lobby_state()

func _on_bubbles_phase_changed(_phase: StringName, _snapshot: Dictionary) -> void:
	_broadcast_gameplay_snapshots()

func _on_bubbles_personal_state_changed(player_id: String, _snapshot: Dictionary) -> void:
	if _bubbles_protocol != null:
		_send_to_player(player_id, _bubbles_protocol.snapshot_for(player_id))

func _on_bubbles_personal_visual_changed(player_id: String, visual_state: Dictionary) -> void:
	if _bubbles_protocol != null:
		_send_to_player(player_id, {"type": "bubbles_visual", "visual": visual_state})

func _on_bubbles_feedback(player_id: String, kind: StringName, data: Dictionary) -> void:
	if _bubbles_protocol == null or kind not in [&"captured", &"spin", &"pop"]:
		return
	var message: Dictionary = _bubbles_protocol.feedback_for(player_id, kind, data)
	if not message.is_empty():
		_send_to_player(player_id, message)


func _on_bubbles_return_to_lobby() -> void:
	send_lobby_state()

func _clear_flash_pose_controller() -> void:
	if _flash_pose_protocol == null:
		return
	var controller: FlashPoseRoundController = _flash_pose_protocol.controller
	if is_instance_valid(controller):
		if controller.phase_changed.is_connected(_on_flash_pose_phase_changed): controller.phase_changed.disconnect(_on_flash_pose_phase_changed)
		if controller.genuine_stop_started.is_connected(_on_flash_pose_challenge): controller.genuine_stop_started.disconnect(_on_flash_pose_challenge)
		if controller.semantic_animation_updated.is_connected(_on_semantic_state_changed): controller.semantic_animation_updated.disconnect(_on_semantic_state_changed)
		if controller.pose_evaluation_resolved.is_connected(_on_flash_pose_results): controller.pose_evaluation_resolved.disconnect(_on_flash_pose_results)
		if controller.round_results_ready.is_connected(_on_flash_pose_round_results): controller.round_results_ready.disconnect(_on_flash_pose_round_results)
		if controller.return_to_lobby_requested.is_connected(_on_flash_pose_return_to_lobby): controller.return_to_lobby_requested.disconnect(_on_flash_pose_return_to_lobby)
	if _active_protocol == _flash_pose_protocol:
		_active_protocol = null
	_flash_pose_protocol = null

func _clear_bubbles_controller() -> void:
	if _bubbles_protocol == null:
		return
	var controller: BubblesRoundController = _bubbles_protocol.controller
	if is_instance_valid(controller):
		if controller.phase_changed.is_connected(_on_bubbles_phase_changed): controller.phase_changed.disconnect(_on_bubbles_phase_changed)
		if controller.personal_state_changed.is_connected(_on_bubbles_personal_state_changed): controller.personal_state_changed.disconnect(_on_bubbles_personal_state_changed)
		if controller.personal_visual_changed.is_connected(_on_bubbles_personal_visual_changed): controller.personal_visual_changed.disconnect(_on_bubbles_personal_visual_changed)
		if controller.feedback_requested.is_connected(_on_bubbles_feedback): controller.feedback_requested.disconnect(_on_bubbles_feedback)
		if controller.return_to_lobby_requested.is_connected(_on_bubbles_return_to_lobby): controller.return_to_lobby_requested.disconnect(_on_bubbles_return_to_lobby)
	if _active_protocol == _bubbles_protocol:
		_active_protocol = null
	_bubbles_protocol = null

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
