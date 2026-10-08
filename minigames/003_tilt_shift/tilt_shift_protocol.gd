class_name TiltShiftProtocol
extends RefCounted
## Copy-only wire view. Sensor input uses the authenticated motion channel, not this adapter.

var generation := ""
var sequence := 0
var phase := ""
var round_number := 0
var _players: Dictionary[String, TiltShiftState.Player] = { }
var _size := Vector2.ONE
var round_token := ""
var panel_visible := false
var reworked := false
var ready_action: Callable
var calibration_context: Callable
var _motion: Dictionary[String, Dictionary] = { }


func _init(token: String = "") -> void:
	generation = token


func apply_snapshot(state: TiltShiftState.Snapshot) -> void:
	phase = String(state.phase)
	round_token = state.round_token
	panel_visible = state.panel_visible
	reworked = state.reworked
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
		"round_token": round_token,
		"selected": player.selected,
		"ready": player.ready,
		"ready_available": panel_visible and player.selected and phase == "preparing",
		"calibration_available": phase in ["preparing", "countdown", "start", "between_rounds"],
		"calibrated": _motion.get(player_id, { }).get("calibrated", false),
		"usable": _motion.get(player_id, { }).get("usable", false),
		"team": player.team,
		"angle_radians": player.angle_radians,
		"paddle_ids": Array(player.paddle_ids),
		"paddle_size": [_size.x, _size.y],
	}


func player_ids() -> PackedStringArray:
	return PackedStringArray(_players.keys())


func apply_motion(player_id: String, state: Dictionary) -> void:
	_motion[player_id] = state.duplicate(true)
	sequence += 1


func handle_ready(player_id: String, message: Dictionary, now: int) -> bool:
	if (
		(
			not ready_action.is_valid() or message.size() != 4
			or message.get("generation") != generation
		) \
				or message.get("round_token") != round_token
		or not message.get("ready") is bool
	):
		return false
	return ready_action.call(player_id, message.ready, round_token, now)


func valid_calibration(message: Dictionary) -> bool:
	if not reworked:
		return true
	return (
		message.size() == 4 and message.get("generation") == generation \
				and message.get("round_token") == round_token
		and calibration_context.is_valid()
	) \
			and calibration_context.call(round_token)
