class_name TiltShiftProtocol
extends RefCounted
## Copy-only wire view. Sensor input uses the authenticated motion channel, not this adapter.

var generation := ""
var sequence := 0
var phase := ""
var round_number := 0
var _players: Dictionary[String, TiltShiftState.Player] = { }
var _size := Vector2.ONE


func _init(token: String = "") -> void:
	generation = token


func apply_snapshot(state: TiltShiftState.Snapshot) -> void:
	phase = String(state.phase)
	round_number = state.round_number
	_size = Vector2(state.physics.paddle_length, state.physics.paddle_thickness)
	_players.clear()
	for player: TiltShiftState.Player in state.players:
		_players[player.player_id] = TiltShiftState.copy_player(player)
	sequence += 1


func apply_player(player: TiltShiftState.Player) -> void:
	_players[player.player_id] = TiltShiftState.copy_player(player)
	sequence += 1


func snapshot_for(player_id: String) -> Dictionary:
	var player := _players.get(player_id) as TiltShiftState.Player
	if player == null:
		return { }
	return {
		"type": "tilt_shift_snapshot",
		"generation": generation,
		"sequence": sequence,
		"phase": phase,
		"round": round_number,
		"team": player.team,
		"angle_radians": player.angle_radians,
		"paddle_ids": Array(player.paddle_ids),
		"paddle_size": [_size.x, _size.y],
	}


func player_ids() -> PackedStringArray:
	return PackedStringArray(_players.keys())
