class_name WebsocketService
extends Node
## Versioned browser transport. Identity mutations are delegated to PlayerRegistry.

signal connection_count_changed(count: int)
signal motion_session_ended

const MAX_PACKET_BYTES := 8192 # Bounds every client WebSocket packet.

var _server: TCPServer = TCPServer.new()
var _clients: Array[Dictionary] = []
var _settings: NetworkingTuning
var _tls_options: TLSOptions
var _network: ControllerNetworkConfig
var _registry: PlayerRegistry
var _accepting_new_players: Callable
var _next_id: int = 1
var _minigame_protocol: MinigameProtocol
var _active_protocol: RefCounted
var _lobby_controller: LobbyPlaygroundWorld
var _readiness: PreMinigameReadiness
var motion_channel := MotionInputChannel.new()
var motion_channels: Dictionary[String, MotionInputChannel] = { }


func begin_motion(player_id: String) -> void:
	end_motion()
	motion_channel.begin(player_id)
	motion_channels[player_id] = motion_channel
	_send_motion_subscription.call_deferred(player_id, motion_channel.subscription_id)


func begin_multiplayer_motion(player_ids: PackedStringArray) -> bool:
	if player_ids.is_empty() or player_ids.size() > 10:
		return false
	var unique: Dictionary[String, bool] = { }
	for player_id: String in player_ids:
		if player_id.is_empty() or unique.has(player_id):
			return false
		unique[player_id] = true
	end_motion()
	for player_id: String in player_ids:
		var channel := MotionInputChannel.new()
		channel.begin(player_id)
		motion_channels[player_id] = channel
		_send_motion_subscription.call_deferred(player_id, channel.subscription_id)
	return true


func _send_motion_subscription(player_id: String, generation: String) -> void:
	var channel := motion_channels.get(player_id) as MotionInputChannel
	if channel == null or channel.subscription_id != generation:
		return
	var message := channel.subscription()
	if channel != motion_channel:
		message.type = "motion_subscribe"
	_send_to_player(player_id, message)


func add_multiplayer_motion(player_id: String) -> MotionInputChannel:
	if player_id.is_empty() or motion_channels.size() >= 10 or motion_channels.has(player_id):
		return null
	var channel := MotionInputChannel.new()
	channel.begin(player_id)
	motion_channels[player_id] = channel
	_send_motion_subscription.call_deferred(player_id, channel.subscription_id)
	return channel


func remove_multiplayer_motion(player_id: String) -> void:
	var channel := motion_channels.get(player_id) as MotionInputChannel
	if channel == null:
		return
	motion_channels.erase(player_id)
	_send_to_player(
		player_id,
		{ "type": "motion_stop", "subscription_id": channel.subscription_id },
	)
	channel.end()


## Routes the message types [param protocol] handles to it until it is cleared.
func set_minigame_protocol(protocol: MinigameProtocol) -> void:
	clear_minigame_protocol()
	_minigame_protocol = protocol
	_active_protocol = protocol
	protocol.send_requested.connect(_send_to_player)
	protocol.broadcast_requested.connect(_broadcast_gameplay_snapshots)
	_broadcast_gameplay_snapshots()


## Clears [param protocol], or whichever minigame protocol is set when it is null.
func clear_minigame_protocol(protocol: MinigameProtocol = null) -> void:
	if _minigame_protocol == null or (protocol != null and protocol != _minigame_protocol):
		return
	_minigame_protocol.send_requested.disconnect(_send_to_player)
	_minigame_protocol.broadcast_requested.disconnect(_broadcast_gameplay_snapshots)
	_minigame_protocol.detach()
	if _active_protocol == _minigame_protocol:
		_active_protocol = null
	_minigame_protocol = null


func send_current_snapshot(player_id: String, coalesce := true) -> void:
	if _active_protocol != null:
		_send_to_player(player_id, _active_protocol.snapshot_for(player_id), coalesce)


func send_motion_feedback(player_id: String, generation: String, state: Dictionary) -> void:
	var channel := motion_channels.get(player_id) as MotionInputChannel
	if channel == null or channel.subscription_id != generation:
		return
	_send_to_player(
		player_id,
		{ "type": "motion_control_state", "subscription_id": generation, "control_state": state },
	)


func end_motion() -> void:
	var retiring := motion_channels.values()
	motion_channels.clear()
	for channel: MotionInputChannel in retiring:
		_send_to_player(
			channel.target_player_id,
			{ "type": "motion_stop", "subscription_id": channel.subscription_id },
		)
		channel.end()
	if not retiring.is_empty():
		motion_session_ended.emit()


func start(
	settings: NetworkingTuning,
	registry: PlayerRegistry,
	accepting_new_players: Callable,
	network: ControllerNetworkConfig = null,
	tls_options: TLSOptions = null,
) -> Error:
	_tls_options = tls_options
	_settings = settings
	_network = network if network != null else ControllerNetworkConfig.new(settings)
	_registry = registry
	_accepting_new_players = accepting_new_players
	return _server.listen(_network.websocket_port, _network.bind_address)


func stop() -> void:
	end_motion()
	_server.stop()
	for client: Dictionary in _clients:
		_disconnect_player(client)
		client.connection.close()
	_clients.clear()
	connection_count_changed.emit(0)


func set_lobby_controller(controller: LobbyPlaygroundWorld) -> void:
	_lobby_controller = controller


func clear_lobby_controller(controller: LobbyPlaygroundWorld) -> void:
	if _lobby_controller == controller:
		_lobby_controller.clear_all_input()
		_lobby_controller = null


func begin_pre_minigame(phase: PreMinigameReadiness) -> void:
	_readiness = phase
	_active_protocol = phase
	for client: Dictionary in _clients:
		var joined := _registry.player_for_connection(int(client.connection_id))
		client.preexisting_onboarding = joined.is_empty()
	phase.changed.connect(_on_readiness_changed)
	_broadcast_gameplay_snapshots()


func end_pre_minigame() -> void:
	if _readiness != null and _readiness.changed.is_connected(_on_readiness_changed):
		_readiness.changed.disconnect(_on_readiness_changed)
	if _active_protocol == _readiness:
		_active_protocol = null
	_readiness = null
	for client: Dictionary in _clients:
		client.preexisting_onboarding = false


func _on_readiness_changed(_snapshot: Dictionary) -> void:
	_broadcast_gameplay_snapshots()


func send_lobby_state() -> void:
	for client: Dictionary in _clients:
		if client.welcomed and not _registry.player_for_connection(client.connection_id).is_empty():
			client.peer.send_text(
				JSON.stringify(
					{ "type": "lobby", "state": "waiting", "message": "Waiting for the next game" }
				)
			)


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
		_clients.append(
			{
				"peer": peer,
				"connection": ControllerStream.new(tcp, _tls_options),
				"stream_accepted": false,
				"welcomed": false,
				"connection_id": 0,
				"created": Time.get_ticks_msec(),
				"preexisting_onboarding": false,
			}
		)
	for index: int in range(_clients.size() - 1, -1, -1):
		var client: Dictionary = _clients[index]
		var peer: WebSocketPeer = client.peer
		if not client.stream_accepted:
			var connection: ControllerStream = client.connection
			var ready := connection.poll_ready()
			if (
				connection.failed
				or Time.get_ticks_msec() - client.created > _settings.request_timeout_seconds * 1000
			):
				_drop(index)
				continue
			if not ready:
				continue
			if peer.accept_stream(connection.stream) != OK:
				_drop(index)
				continue
			client.stream_accepted = true
		peer.poll()
		if (
			peer.get_ready_state() == WebSocketPeer.STATE_CLOSED
			or (
				not client.welcomed
				and Time.get_ticks_msec() - client.created
				> _settings.request_timeout_seconds * 1000
			)
		):
			_drop(index)
			continue
		if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		var pending_motion: Dictionary = { }
		for unused: int in range(8):
			if peer.get_available_packet_count() == 0:
				break
			var packet := peer.get_packet()
			var parser := JSON.new()
			if (
				not peer.was_string_packet() or packet.size() > MAX_PACKET_BYTES
				or parser.parse(packet.get_string_from_utf8()) != OK
				or not parser.data is Dictionary
			):
				peer.close(1008, "Expected protocol JSON")
				break
			if parser.data.get("type") == "motion_sample":
				pending_motion = parser.data
			else:
				if not pending_motion.is_empty():
					_handle_message(client, pending_motion)
					pending_motion = { }
				_handle_message(client, parser.data)
		if not pending_motion.is_empty() and peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_handle_message(client, pending_motion)


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
		var resume := {
			"accepted": false,
			"code": &"join_required",
			"message": "Enter a name to join",
		}
		if message.has("reconnect_token") or message.has("session_id"):
			resume = _registry.resume_player(
				connection_id,
				message.get("session_id"),
				message.get("reconnect_token"),
			)
		if resume.accepted:
			_close_replaced_connection(resume.replaced_connection_id, connection_id)
			if _readiness != null:
				_readiness.set_ready(resume.player, false)
			if _lobby_controller != null:
				_lobby_controller.reset_sequence(String(resume.player.player_id))
		if not resume.accepted and _readiness != null and not bool(client.preexisting_onboarding):
			peer.close(1008, "Ready-up is closed to new phones")
			return
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
			var resumed_id := String(resume.player.player_id)
			var channel := motion_channels.get(resumed_id) as MotionInputChannel
			if channel != null:
				channel.reconnect()
			welcome.gameplay = _active_protocol.snapshot_for(String(resume.player.player_id)) \
					if _active_protocol != null else {
				"type": "lobby",
				"state": "waiting",
				"message": "Waiting for the next game",
			}
		peer.send_text(JSON.stringify(welcome))
		if resume.accepted:
			var resumed_id := String(resume.player.player_id)
			var channel := motion_channels.get(resumed_id) as MotionInputChannel
			if channel != null:
				_send_motion_subscription(resumed_id, channel.subscription_id)
		_emit_count()
		return

	match message.get("type"):
		"motion_status", "motion_sample", "motion_calibrate":
			# Identity is resolved from the current socket, never a phone-authored ID.
			var player := _registry.player_for_connection(client.connection_id)
			var channel := motion_channels.get(String(player.get("player_id", ""))) \
					as MotionInputChannel
			if channel != null:
				var calibration: bool = message.get("type") == "motion_calibrate"
				if (
					calibration and _active_protocol != null
					and _active_protocol.has_method("valid_calibration")
				):
					if not _active_protocol.valid_calibration(message):
						return
					message = {
						"type": "motion_calibrate",
						"subscription_id": message.get("subscription_id"),
					}
				channel.handle(player, message, Time.get_ticks_msec())
		"join":
			var may_join: bool = (
				_accepting_new_players.call()
				or (
					_readiness != null and _readiness.active and bool(client.preexisting_onboarding)
				)
			)
			var result := _registry.join_player(
				client.connection_id,
				message.get("name"),
				may_join,
				Time.get_ticks_msec(),
				message.get("character_shape"),
				message.get("character_color"),
			)
			if result.accepted:
				peer.send_text(
					JSON.stringify(
						{
							"type": "join_accepted",
							"session_id": _registry.session_id,
							"player": result.player,
							"reconnect_token": result.reconnect_token,
						}
					)
				)
				if _readiness != null:
					client.preexisting_onboarding = false
					_readiness.add_joined(result.player)
					_send_gameplay_snapshot(peer, String(result.player.player_id))
			else:
				_send_rejection(peer, "join_rejected", result)
		"leave":
			if _readiness != null:
				_send_rejection(
					peer,
					"error",
					{
						"code": &"ready_unavailable",
						"message": "Leave is unavailable during ready-up",
					},
				)
				return
			var result := _registry.leave_connection(client.connection_id)
			if result.accepted:
				peer.send_text(JSON.stringify({ "type": "left", "message": "You left the lobby" }))
			else:
				_send_rejection(peer, "error", result)
		"lobby_move", "lobby_jump_release", "lobby_fall_release":
			var player := _registry.player_for_connection(client.connection_id)
			var result: Dictionary = _lobby_controller.handle_input(
				player,
				message,
				Time.get_ticks_msec(),
			) \
					if (
				_lobby_controller != null and _active_protocol == null
				and _accepting_new_players.call()
			) \
					else {
				"accepted": false,
				"code": &"lobby_unavailable",
				"message": "Lobby controls are not active",
			}
			if not result.accepted:
				_send_rejection(peer, "error", result)
		"pre_minigame_ready":
			var player := _registry.player_for_connection(client.connection_id)
			var ready_value: Variant = message.get("ready")
			var result: Dictionary = _readiness.set_ready(player, ready_value) \
					if _readiness != null and ready_value is bool else {
				"accepted": false,
				"code": &"invalid_ready",
				"message": "Invalid ready action",
			}
			if not result.accepted:
				_send_rejection(peer, "error", result)
			elif _readiness != null:
				_send_gameplay_snapshot(peer, String(player.player_id))
		_:
			var type := String(message.get("type", ""))
			if (
				_minigame_protocol != null and _active_protocol == _minigame_protocol
				and _minigame_protocol.handles(type)
			):
				var player := _registry.player_for_connection(client.connection_id)
				var result := _minigame_protocol.handle_message(
					player,
					message,
					Time.get_ticks_msec(),
				)
				if not result.accepted:
					_send_rejection(peer, "error", result)
					return
				if result.has("reply"):
					peer.send_text(JSON.stringify(result.reply))
				if result.get("snapshot", false):
					_send_gameplay_snapshot(peer, String(player.player_id))
				return
			_send_rejection(
				peer,
				"error",
				{ "code": &"unsupported_message", "message": "That action is not supported" },
			)


func _send_rejection(peer: WebSocketPeer, response_type: String, result: Dictionary) -> void:
	peer.send_text(
		JSON.stringify(
			{ "type": response_type, "code": str(result.code), "message": result.message }
		)
	)


func _send_gameplay_snapshot(peer: WebSocketPeer, player_id: String) -> void:
	var message: Dictionary = _active_protocol.snapshot_for(player_id) if _active_protocol != null \
			else { "type": "lobby", "state": "waiting", "message": "Waiting for the next game" }
	peer.send_text(JSON.stringify(message))


func _send_to_player(player_id: String, message: Dictionary, coalesce := false) -> void:
	for client: Dictionary in _clients:
		if (
			client.welcomed
			and _registry.player_for_connection(client.connection_id).get("player_id") == player_id
		):
			if coalesce and client.peer.get_current_outbound_buffered_amount() > 0:
				return
			client.peer.send_text(JSON.stringify(message))
			return


func _broadcast_gameplay_snapshots() -> void:
	for client: Dictionary in _clients:
		if not client.welcomed:
			continue
		var player := _registry.player_for_connection(client.connection_id)
		if not player.is_empty():
			_send_gameplay_snapshot(client.peer, String(player.player_id))


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
	client.connection.close()
	_clients.remove_at(index)
	_emit_count()


func _disconnect_player(client: Dictionary) -> void:
	if client.welcomed:
		var leaving := _registry.player_for_connection(client.connection_id)
		var player_id := String(leaving.get("player_id", ""))
		var channel := motion_channels.get(player_id) as MotionInputChannel
		if channel != null:
			channel.reconnect()
		_registry.disconnect_connection(client.connection_id)


func _emit_count() -> void:
	var count: int = 0
	for client: Dictionary in _clients:
		if client.welcomed:
			count += 1
	connection_count_changed.emit(count)


func _exit_tree() -> void:
	stop()
