class_name TiltShift3DProtocol
extends MinigameProtocol
## The phones' view of a running Tilt Shift 3D shift: a copy-only snapshot per player and the
## READY action. Tilt itself arrives through the shared motion channel, not through here.

const READY := "tilt_shift_3d_ready"
const SNAPSHOT := "tilt_shift_3d_snapshot"

var generation := ""
var sequence := 0
var phase := ""
var round_number := 0
var round_token := ""
var panel_visible := false
var reworked := false
var ready_action: Callable
var calibration_context: Callable
var _players: Dictionary[String, TiltShift3DState.Player] = { }
var _motion: Dictionary[String, Dictionary] = { }
var _faces: Dictionary[String, String] = { }
var _angles: Dictionary[String, float] = { }
var _sizes: Array[Vector2] = [Vector2(0.2, 0.04), Vector2(0.2, 0.04)]
var _look: Dictionary = { }
var _play_face := "face_a"


func _init(token: String = "") -> void:
	generation = token


func handles(message_type: String) -> bool:
	return message_type == READY


## A stale or invalid READY is dropped without an error; the sender gets its
## current snapshot back so its button shows the true state.
func handle_message(player: Dictionary, message: Dictionary, host_msec: int) -> Dictionary:
	var accepted := handle_ready(String(player.get("player_id", "")), message, host_msec)
	return { "accepted": true, "snapshot": not accepted }


## Sets what every snapshot says about how paddles look and which face a player without an
## expression shows.
func set_look(profile: TiltShift3DTuning) -> void:
	_look = look_of(profile)
	_play_face = profile.expressions.play_face


## How the phone draws a paddle: the shared screen's proportions and colours. Team outlines are
## orange, blue, then the neutral outline used before teams exist.
static func look_of(profile: TiltShift3DTuning) -> Dictionary:
	var look := profile.presentation
	var physics := profile.physics
	return {
		"corner_ratio": physics.corner_radius_ratio,
		"depth_ratio": physics.depth_ratio,
		"gap_ratio": look.gap_ratio,
		"outline_ratio": look.outline_ratio,
		"face_ratio": look.face_height_ratio,
		"gap_color": look.gap_color.to_html(false),
		"outline_colors": [
			look.orange_outline_color.to_html(false),
			look.blue_outline_color.to_html(false),
			look.neutral_outline_color.to_html(false),
		],
		"wall_colors": [look.wall_top_color.to_html(false), look.wall_bottom_color.to_html(false)],
	}


func apply_snapshot(state: TiltShift3DState.Snapshot) -> void:
	phase = String(state.phase)
	round_token = state.round_token
	panel_visible = state.panel_visible
	reworked = state.reworked
	round_number = state.round_number
	for team: int in 2:
		_sizes[team] = state.paddle_layout.paddle_size(team, state.physics)
	_players.clear()
	for player: TiltShift3DState.Player in state.players:
		_players[player.player_id] = TiltShift3DState.copy_player(player)
	sequence += 1


func apply_player(player: TiltShift3DState.Player) -> void:
	_players[player.player_id] = TiltShift3DState.copy_player(player)
	sequence += 1


## Records the strongest face across [param player_id]'s paddles. Returns true when it changed.
func apply_face(player_id: String, face: String) -> bool:
	if _faces.get(player_id, "") == face:
		return false
	_faces[player_id] = face
	sequence += 1
	return true


## Records the physical angle of [param player_id]'s paddles. Returns true when it moved.
func apply_angle(player_id: String, radians: float) -> bool:
	if absf(_angles.get(player_id, 0.0) - radians) < 0.0005:
		return false
	_angles[player_id] = radians
	sequence += 1
	return true


func apply_motion(player_id: String, state: Dictionary) -> void:
	_motion[player_id] = state.duplicate(true)
	sequence += 1


func player_ids() -> PackedStringArray:
	return PackedStringArray(_players.keys())


## Asks the service to send [param player_id] their current snapshot.
func publish(player_id: String, coalesce := true) -> void:
	var message := snapshot_for(player_id)
	if not message.is_empty():
		send_requested.emit(player_id, message, coalesce)


func snapshot_for(player_id: String) -> Dictionary:
	var player := _players.get(player_id) as TiltShift3DState.Player
	if player == null:
		return { }
	var motion: Dictionary = _motion.get(player_id, { })
	var size := _sizes[clampi(player.team, 0, 1)]
	var face: String = _faces.get(player_id, "")
	return {
		"type": SNAPSHOT,
		"generation": generation,
		"sequence": sequence,
		"phase": phase,
		"round": round_number,
		"round_token": round_token,
		"selected": player.selected,
		"ready": player.ready,
		"ready_available": panel_visible and player.selected and phase == "preparing",
		"calibration_available": phase in ["preparing", "countdown", "start", "between_rounds"],
		"calibrated": motion.get("calibrated", false),
		"usable": motion.get("usable", false),
		"landscape": motion.get("landscape", false),
		"team": player.team,
		"angle_radians": _angles.get(player_id, player.angle_radians) if player.selected else 0.0,
		"paddle_ids": Array(player.paddle_ids),
		"paddle_size": [size.x, size.y],
		"color": TiltShift3DPresentation.player_color(player.character_color).to_html(false),
		"face": face if not face.is_empty() else _play_face,
		"look": _look,
	}


func handle_ready(player_id: String, message: Dictionary, now: int) -> bool:
	if (
		not ready_action.is_valid() or message.size() != 4
		or message.get("generation") != generation
		or message.get("round_token") != round_token or not message.get("ready") is bool
	):
		return false
	return ready_action.call(player_id, message.ready, round_token, now)


## Called by the WebSocket service before a calibration is accepted.
func valid_calibration(message: Dictionary) -> bool:
	if not reworked:
		return true
	return (
		message.size() == 4 and message.get("generation") == generation
		and message.get("round_token") == round_token
		and calibration_context.is_valid() and calibration_context.call(round_token)
	)


func detach() -> void:
	ready_action = Callable()
	calibration_context = Callable()
