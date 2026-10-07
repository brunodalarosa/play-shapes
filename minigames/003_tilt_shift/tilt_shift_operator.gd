class_name TiltShiftOperator
extends Node2D
## Cosmetic progress follows accepted angle changes and stays held without input.

const VIEW := "three-quarter"
var player_id: String
var character: SquircleV1Playback
var accepted_angle := 0.0
var loop_progress := 0.0
var _clip: Dictionary
var _tuning: TiltShiftPresentationTuning
var _shaft: Sprite2D
var _grip: Sprite2D
var _socket: Vector2
var _grip_path: String
var _frame := -1
var _blink_time := 0.0
var _has_angle := false


func configure(player: TiltShiftState.Player, selected: TiltShiftPresentationTuning) -> void:
	_tuning = selected
	player_id = player.player_id
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(SquircleV1Playback.MANIFEST_PATH)
	)
	for clip: Dictionary in manifest.clips:
		if clip.name == "lever_pull" and clip.view == VIEW:
			_clip = clip
	assert(_clip.hand_centers_px.size() == int(_clip.frames))
	var mirrored := player.team == 0
	scale.x = -1.0 if mirrored else 1.0
	var base := TiltShiftArt.sprite("stations/station_base", selected.station_width)
	base.position.y = 12.0
	base.z_index = 3
	add_child(base)
	var base_region := TiltShiftArt.bounds("stations/station_base")
	var base_scale := selected.station_width / base_region.size.x
	_socket = base.position + (
		TiltShiftArt.anchor("stations/station_base", "socket_mount") - base_region.get_center()
	) * base_scale
	_shaft = Sprite2D.new()
	_shaft.texture = TiltShiftArt.texture("stations/lever_shaft")
	_shaft.centered = false
	_shaft.z_index = 2
	add_child(_shaft)
	_grip_path = "stations/grip_orange" if player.team == 0 else "stations/grip_blue"
	_grip = Sprite2D.new()
	_grip.texture = TiltShiftArt.texture(_grip_path)
	_grip.centered = false
	_grip.z_index = 4
	add_child(_grip)
	var socket := TiltShiftArt.sprite("stations/pivot_socket", 14.0)
	socket.position = _socket
	socket.z_index = 6
	add_child(socket)
	character = SquircleV1Playback.new()
	character.player_color = _player_color(player.character_color)
	character.scale = Vector2.ONE * selected.character_size / 256.0
	character.position = Vector2(-10, -10)
	character.z_index = 5
	add_child(character)
	_blink_time = float(player.seat) * 0.37
	apply_player(player)


func _ready() -> void:
	character.set_process(false)
	_update_pose()


func apply_player(player: TiltShiftState.Player) -> void:
	if _has_angle:
		var angle_delta := player.angle_radians - accepted_angle
		var loop_angle := TAU * _tuning.turns_per_loop
		loop_progress = fposmod(loop_progress + angle_delta / loop_angle, 1.0)
	accepted_angle = player.angle_radians
	_has_angle = true
	if is_node_ready():
		_update_pose()


func pose_frame() -> int:
	return _frame


func _process(delta: float) -> void:
	_blink_time = fposmod(_blink_time + delta, 3.7)
	character.face_blink = _blink_time > 2.84 and _blink_time < 2.98


func _update_pose() -> void:
	var frame := mini(int(loop_progress * int(_clip.frames)), int(_clip.frames) - 1)
	if frame == _frame:
		return
	_frame = frame
	character.seek_clip("lever_pull", VIEW, float(frame) * 1000.0 / float(_clip.fps))
	var hand := TiltShiftArt.point(_clip.hand_centers_px[frame])
	hand = character.position + (hand - TiltShiftArt.point(_clip.anchor_px)) * character.scale
	var direction := hand - _socket
	var angle := Vector2.UP.angle_to(direction)
	var grip_scale := 0.075
	var grip_contact := TiltShiftArt.anchor(_grip_path, "hand_contact")
	var grip_mount := TiltShiftArt.anchor(_grip_path, "shaft_mount")
	var shaft_end := hand + ((grip_mount - grip_contact) * grip_scale).rotated(angle)
	var shaft_pivot := TiltShiftArt.anchor("stations/lever_shaft", "rotation_pivot")
	var shaft_mount := TiltShiftArt.anchor("stations/lever_shaft", "grip_mount")
	var shaft_scale := Vector2(
		0.045,
		shaft_end.distance_to(_socket) / absf(shaft_mount.y - shaft_pivot.y),
	)
	_shaft.scale = shaft_scale
	_shaft.rotation = angle
	_shaft.position = _socket - (shaft_pivot * shaft_scale).rotated(angle)
	_grip.scale = Vector2.ONE * grip_scale
	_grip.rotation = angle
	_grip.position = hand - (grip_contact * grip_scale).rotated(angle)


func _player_color(id: String) -> Color:
	for color: Dictionary in CharacterSelection.COLORS:
		if color.id == id or String(color.hex).to_lower() == id.to_lower():
			return Color(String(color.hex))
	return Color("1e88e5")
