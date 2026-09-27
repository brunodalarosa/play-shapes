class_name LobbyPlaygroundWorld
extends Node2D
## Reconciles host registry records into one character per player identity.

const CHARACTER: PackedScene = preload("res://characters/lobby_squircle.tscn")
const MAX_SEQUENCE := 9007199254740991.0

var _characters: Dictionary = {}
var _last_sequence: Dictionary = {}

@onready var _anchors: Node2D = $FutureCharacterAnchors
@onready var _character_layer: Node2D = $CharactersFrontOfPanels


func reconcile(players: Array[Dictionary]) -> void:
	var present: Dictionary = {}
	for player: Dictionary in players:
		var player_id := String(player.player_id)
		var seat := int(player.seat)
		if seat < 1 or seat > _anchors.get_child_count():
			continue
		present[player_id] = true
		var character := _characters.get(player_id) as LobbySquircle
		if character == null:
			character = CHARACTER.instantiate() as LobbySquircle
			character.configure(player, (_anchors.get_child(seat - 1) as Marker2D).position)
			_characters[player_id] = character
			_character_layer.add_child(character)
		else:
			character.refresh_player(player)
		if String(player.state) != "connected":
			_last_sequence.erase(player_id)
	for player_id: String in _characters.keys():
		if present.has(player_id):
			continue
		var character := _characters[player_id] as LobbySquircle
		character.queue_free()
		_characters.erase(player_id)
		_last_sequence.erase(player_id)


func clear_all_input() -> void:
	for character: LobbySquircle in _characters.values():
		character.clear_input()


func reset_sequence(player_id: String) -> void:
	_last_sequence.erase(player_id)
	var character := character_for(player_id)
	if character != null:
		character.clear_input()


func character_for(player_id: String) -> LobbySquircle:
	return _characters.get(player_id) as LobbySquircle


func handle_input(player: Dictionary, message: Dictionary, now_msec: int) -> Dictionary:
	if player.is_empty() or String(player.get("state", "")) != "connected":
		return _rejected("not_joined")
	var player_id := String(player.player_id)
	var character := character_for(player_id)
	if character == null or not character.connected:
		return _rejected("not_in_lobby")
	var raw_sequence: Variant = message.get("input_seq")
	if typeof(raw_sequence) not in [TYPE_INT, TYPE_FLOAT]:
		return _rejected("invalid_sequence")
	var sequence := float(raw_sequence)
	if is_nan(sequence) or is_inf(sequence) or sequence < 1.0 or sequence > MAX_SEQUENCE \
			or floor(sequence) != sequence or sequence <= float(_last_sequence.get(player_id, 0)):
		return _rejected("stale_sequence")
	var kind := String(message.get("type", ""))
	if kind == "lobby_move":
		var raw_horizontal: Variant = message.get("horizontal")
		if typeof(raw_horizontal) not in [TYPE_INT, TYPE_FLOAT]:
			return _rejected("invalid_movement")
		var horizontal := float(raw_horizontal)
		if is_nan(horizontal) or is_inf(horizontal) or horizontal < -1.0 or horizontal > 1.0:
			return _rejected("invalid_movement")
		_last_sequence[player_id] = int(sequence)
		character.set_horizontal(horizontal, now_msec)
		return {"accepted": true}
	if kind == "lobby_jump_release":
		_last_sequence[player_id] = int(sequence)
		return {"accepted": true, "jumped": character.request_jump()}
	return _rejected("unsupported_message")


func _rejected(code: String) -> Dictionary:
	return {"accepted": false, "code": code, "message": "Lobby input was not accepted"}
