class_name PlayerRegistry
extends RefCounted
## Session-scoped authoritative player identity. Transport peers only refer to records
## through host-assigned connection IDs and opaque reconnect tokens.

signal players_changed

const DISCONNECTED := -1

var session_id: String
var max_players: int
var reconnect_grace_msec: int

var _players_by_id: Dictionary = {}
var _player_id_by_token: Dictionary = {}
var _player_id_by_connection: Dictionary = {}
var _next_seat: int = 1

func _init(player_capacity: int = 20, reconnect_grace_seconds: float = 60.0) -> void:
	max_players = player_capacity
	reconnect_grace_msec = roundi(reconnect_grace_seconds * 1000.0)
	session_id = _opaque_id()

func join_player(connection_id: int, raw_name: Variant, accepting_new_players: bool,
		now_msec: int = Time.get_ticks_msec(), raw_character_shape: Variant = null,
		raw_character_color: Variant = null) -> Dictionary:
	expire_players(now_msec)
	if _player_id_by_connection.has(connection_id):
		return _rejected(&"already_joined", "This connection already has a player")
	if not accepting_new_players:
		return _rejected(&"game_in_progress", "A game is in progress. Return to the lobby to join")
	var name_result := validate_name(raw_name)
	if not name_result.accepted:
		return name_result
	var name: String = name_result.name
	var has_shape := raw_character_shape != null
	var has_color := raw_character_color != null
	var selection := CharacterSelection.default_selection() if not has_shape and not has_color \
		else CharacterSelection.validate_selection(raw_character_shape, raw_character_color)
	if not selection.accepted:
		return selection
	var name_key := name.to_lower()
	for player: Dictionary in _players_by_id.values():
		if player.name_key == name_key:
			return _rejected(&"duplicate_name", "Name already in use")
	if _players_by_id.size() >= max_players:
		return _rejected(&"full", "The lobby is full")

	var player_id := _opaque_id()
	var reconnect_token := _opaque_id(24)
	var player := {
		"player_id": player_id,
		"name": name,
		"name_key": name_key,
		"character_shape": selection.character_shape,
		"character_color": selection.character_color,
		"seat": _next_seat,
		"connection_id": connection_id,
		"reconnect_token": reconnect_token,
		"disconnected_at_msec": DISCONNECTED,
	}
	_next_seat += 1
	_players_by_id[player_id] = player
	_player_id_by_token[reconnect_token] = player_id
	_player_id_by_connection[connection_id] = player_id
	players_changed.emit()
	return {
		"accepted": true,
		"status": &"joined",
		"player": _public_player(player),
		"reconnect_token": reconnect_token,
		"replaced_connection_id": DISCONNECTED,
	}

func resume_player(connection_id: int, requested_session_id: Variant,
		reconnect_token: Variant, now_msec: int = Time.get_ticks_msec()) -> Dictionary:
	expire_players(now_msec)
	if not requested_session_id is String or requested_session_id != session_id:
		return _rejected(&"session_restarted", "The host started a new session. Join again")
	if not reconnect_token is String or reconnect_token.length() > 128 or not _player_id_by_token.has(reconnect_token):
		return _rejected(&"expired", "Your previous player expired. Join again")
	var player_id: String = _player_id_by_token[reconnect_token]
	var player: Dictionary = _players_by_id[player_id]
	var replaced_connection_id: int = player.connection_id
	if replaced_connection_id != DISCONNECTED:
		_player_id_by_connection.erase(replaced_connection_id)
	player.connection_id = connection_id
	player.disconnected_at_msec = DISCONNECTED
	_player_id_by_connection[connection_id] = player_id
	players_changed.emit()
	return {
		"accepted": true,
		"status": &"resumed",
		"player": _public_player(player),
		"reconnect_token": reconnect_token,
		"replaced_connection_id": replaced_connection_id,
	}

func disconnect_connection(connection_id: int, now_msec: int = Time.get_ticks_msec()) -> void:
	if not _player_id_by_connection.has(connection_id):
		return
	var player_id: String = _player_id_by_connection[connection_id]
	_player_id_by_connection.erase(connection_id)
	var player: Dictionary = _players_by_id.get(player_id, {})
	if player.is_empty() or player.connection_id != connection_id:
		return
	player.connection_id = DISCONNECTED
	player.disconnected_at_msec = now_msec
	players_changed.emit()

func leave_connection(connection_id: int) -> Dictionary:
	if not _player_id_by_connection.has(connection_id):
		return _rejected(&"not_joined", "Join before leaving")
	var player_id: String = _player_id_by_connection[connection_id]
	var player: Dictionary = _players_by_id[player_id]
	_remove_player(player)
	players_changed.emit()
	return {"accepted": true, "status": &"left"}

func expire_players(now_msec: int = Time.get_ticks_msec()) -> void:
	var expired: Array[Dictionary] = []
	for player: Dictionary in _players_by_id.values():
		if player.connection_id == DISCONNECTED and now_msec - player.disconnected_at_msec >= reconnect_grace_msec:
			expired.append(player)
	for player: Dictionary in expired:
		_remove_player(player)
	if not expired.is_empty():
		players_changed.emit()

func public_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player: Dictionary in _players_by_id.values():
		result.append(_public_player(player))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.seat < b.seat)
	return result

func player_count() -> int:
	return _players_by_id.size()

func player_for_connection(connection_id: int) -> Dictionary:
	if not _player_id_by_connection.has(connection_id):
		return {}
	var player_id: String = _player_id_by_connection[connection_id]
	var player: Dictionary = _players_by_id.get(player_id, {})
	return _public_player(player) if not player.is_empty() else {}

func validate_name(raw_name: Variant) -> Dictionary:
	if not raw_name is String:
		return _rejected(&"invalid_name", "Enter a name")
	var name: String = raw_name.strip_edges()
	if name.length() < 1 or name.length() > 16:
		return _rejected(&"invalid_name", "Name must be 1–16 characters")
	for index: int in name.length():
		var codepoint := name.unicode_at(index)
		# C0/C1 controls and Unicode line separators are not printable name text.
		if codepoint < 32 or (codepoint >= 127 and codepoint <= 159) or codepoint == 0x2028 or codepoint == 0x2029:
			return _rejected(&"invalid_name", "Name cannot contain control characters")
	return {"accepted": true, "name": name}

func _remove_player(player: Dictionary) -> void:
	_players_by_id.erase(player.player_id)
	_player_id_by_token.erase(player.reconnect_token)
	if player.connection_id != DISCONNECTED:
		_player_id_by_connection.erase(player.connection_id)

func _public_player(player: Dictionary) -> Dictionary:
	var selection := CharacterSelection.for_player(player)
	return {
		"player_id": player.player_id,
		"name": player.name,
		"seat": player.seat,
		"state": "connected" if player.connection_id != DISCONNECTED else "reconnecting",
		"character_shape": selection.character_shape,
		"character_color": selection.character_color,
	}

func _rejected(code: StringName, message: String) -> Dictionary:
	return {"accepted": false, "code": code, "message": message}

func _opaque_id(byte_count: int = 16) -> String:
	return Crypto.new().generate_random_bytes(byte_count).hex_encode()
