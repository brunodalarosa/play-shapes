class_name ShapeCharactersLab
extends Control
## Host-only review of a shape character: turn it with the mouse, recolour it, play its clips
## one at a time and try every face. Saving the face placement changes the game's default.

const MODELS: Array[String] = ["Cubio"]
## Degrees the character turns per pixel dragged.
const TURN_PER_PIXEL := 0.4
const SPEED_RANGE := Vector2(0.1, 2.0)
const PLACEMENT_RANGE := 1.0
const HEIGHT_RANGE := Vector2(0.2, 2.0)
## A looping clip that has played once rests this many seconds short of its end: seeking to the
## full length would wrap it to the start, and the pose there is the same.
const LOOP_REST := 0.001

## Where Save writes the face placement; tests point it elsewhere.
var anchor_path := Cubio3D.FACE_ANCHOR_PATH
var _clip := ""
var _last_position := 0.0
var _placement := ShapeFaceAnchor.new()
var _color_buttons: Dictionary[String, Button] = { }
var _face_buttons: Dictionary[String, Button] = { }
var _dragging := false

@onready var cubio: Cubio3D = %Cubio
@onready var _turntable: Node3D = %Turntable
@onready var _zone_a: SubViewportContainer = %ZoneA
@onready var _models: VBoxContainer = %Models
@onready var _colors: GridContainer = %Colors
@onready var _clips: VBoxContainer = %Clips
@onready var _play_pause: Button = %PlayPause
@onready var _speed: HSlider = %Speed
@onready var _speed_value: Label = %SpeedValue
@onready var _clip_status: Label = %ClipStatus
@onready var _expressions: GridContainer = %Expressions
@onready var _blink: CheckButton = %Blink
@onready var _offset_x: HSlider = %OffsetX
@onready var _offset_y: HSlider = %OffsetY
@onready var _height: HSlider = %FaceHeight
@onready var _placement_value: Label = %PlacementValue
@onready var _face_status: Label = %FaceStatus


func _ready() -> void:
	cubio.manual_playback = true
	cubio.nameplate.visible = false
	_zone_a.gui_input.connect(_on_zone_a_input)
	_build_character_tab()
	_build_animation_tab()
	_build_face_tab()
	stop_clip()


func _process(_delta: float) -> void:
	_finish_looping_clip()
	_update_clip_status()


## Turns the character about its upright axis, in degrees.
func turn(degrees: float) -> void:
	_turntable.rotation.y = wrapf(_turntable.rotation.y + deg_to_rad(degrees), -PI, PI)


func select_color(hex: String) -> void:
	cubio.player_color = Color(hex)
	if _color_buttons.has(hex):
		_color_buttons[hex].button_pressed = true


## Plays [param clip] once from its first frame, from the start again if it is playing.
func play_clip(clip: String) -> void:
	var player := cubio.animation_player()
	# Airborne gestures swing below the standing sole, so lift their preview above the floor.
	_turntable.position.y = 0.25 if clip in Cubio3D.ONE_SHOT_CLIPS else 0.0
	_clip = clip
	player.play(clip)
	player.seek(0.0, true)
	player.speed_scale = _speed.value
	_last_position = 0.0
	_play_pause.text = "Pause"


func toggle_pause() -> void:
	var player := cubio.animation_player()
	if player.is_playing():
		player.pause()
		_play_pause.text = "Play"
	elif _clip.is_empty() or _at_end():
		play_clip(_clip if not _clip.is_empty() else "idle")
	else:
		player.play()
		_play_pause.text = "Pause"


func restart_clip() -> void:
	play_clip(_clip if not _clip.is_empty() else "idle")


## Stops the reviewed clip and lets Cubio idle as it does in the game.
func stop_clip() -> void:
	var player := cubio.animation_player()
	_turntable.position.y = 0.0
	_clip = ""
	player.speed_scale = 1.0
	player.play("idle")
	_play_pause.text = "Play"


func set_speed(value: float) -> void:
	_speed.set_value_no_signal(clampf(value, SPEED_RANGE.x, SPEED_RANGE.y))
	_speed_value.text = "%.2f×" % _speed.value
	if not _clip.is_empty():
		cubio.animation_player().speed_scale = _speed.value


func choose_face(face: String) -> void:
	cubio.expressions.base_face = face
	if not _blink.button_pressed:
		cubio.face.face_name = face
	if _face_buttons.has(face):
		_face_buttons[face].button_pressed = true


func set_blinking(enabled: bool) -> void:
	_blink.set_pressed_no_signal(enabled)
	cubio.face.expressions = cubio.expressions if enabled else null
	if not enabled:
		cubio.face.blinking = false
		cubio.face.face_name = cubio.expressions.base_face


## Neutral face, blinking on.
func reset_face() -> void:
	set_blinking(true)
	choose_face(Cubio3D.DEFAULT_FACE)


func set_placement(offset: Vector2, height: float) -> void:
	_placement.offset = offset
	_placement.height = height
	_offset_x.set_value_no_signal(offset.x)
	_offset_y.set_value_no_signal(offset.y)
	_height.set_value_no_signal(height)
	_placement_value.text = "Offset %+.3f, %+.3f · height %.3f" % [offset.x, offset.y, height]
	cubio.set_face_placement(_placement)


func revert_placement() -> void:
	var saved := Cubio3D.face_anchor()
	set_placement(saved.offset, saved.height)
	_face_status.text = "Placement matches the saved default."


## Makes the current placement the default every Cubio starts with, on host and phones.
func save_placement() -> bool:
	var saved := Cubio3D.store_face_anchor(_placement, anchor_path)
	_face_status.text = (
		"Saved. New Cubios and phones that reload use this placement."
		if saved
		else "Could not write %s. Run from the project, not an export." % anchor_path
	)
	return saved


func _on_zone_a_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		turn(event.relative.x * TURN_PER_PIXEL)


func _build_character_tab() -> void:
	var models := ButtonGroup.new()
	for model: String in MODELS:
		var button := _choice(model, models)
		button.button_pressed = true
		_models.add_child(button)

	var colors := ButtonGroup.new()
	for entry: Dictionary in CharacterSelection.COLORS:
		var hex := String(entry.hex)
		var button := _choice(String(entry.name), colors)
		_paint(button, Color(hex))
		button.pressed.connect(select_color.bind(hex))
		_color_buttons[hex] = button
		_colors.add_child(button)
	select_color(cubio.player_color.to_html(false).to_upper().insert(0, "#"))


func _build_animation_tab() -> void:
	_speed.min_value = SPEED_RANGE.x
	_speed.max_value = SPEED_RANGE.y
	_speed.step = 0.05
	_speed.value_changed.connect(set_speed)
	set_speed(1.0)
	%Restart.pressed.connect(restart_clip)
	%Stop.pressed.connect(stop_clip)
	_play_pause.pressed.connect(toggle_pause)
	for clip: String in _clip_names():
		var button := Button.new()
		button.text = clip.capitalize()
		button.pressed.connect(play_clip.bind(clip))
		_clips.add_child(button)


func _build_face_tab() -> void:
	var faces := ButtonGroup.new()
	for face: String in cubio.face.manifest.faces:
		var button := _choice(face.trim_prefix("face_").capitalize(), faces)
		button.tooltip_text = face
		button.pressed.connect(choose_face.bind(face))
		_face_buttons[face] = button
		_expressions.add_child(button)
	_blink.toggled.connect(set_blinking)
	%ResetFace.pressed.connect(reset_face)
	%RevertPlacement.pressed.connect(revert_placement)
	%SavePlacement.pressed.connect(
		func() -> void:
			save_placement(),
	)
	for slider: HSlider in [_offset_x, _offset_y]:
		slider.min_value = -PLACEMENT_RANGE
		slider.max_value = PLACEMENT_RANGE
		slider.step = 0.005
	_height.min_value = HEIGHT_RANGE.x
	_height.max_value = HEIGHT_RANGE.y
	_height.step = 0.01
	for slider: HSlider in [_offset_x, _offset_y, _height]:
		slider.value_changed.connect(_on_placement_slider.unbind(1))
	reset_face()
	revert_placement()
	_face_status.text = ""


func _on_placement_slider() -> void:
	set_placement(Vector2(_offset_x.value, _offset_y.value), _height.value)
	_face_status.text = "Not saved."


## The model's clips, the known ones in their usual order and any new ones after.
func _clip_names() -> Array[String]:
	var player := cubio.animation_player()
	var result: Array[String] = []
	for clip: String in Cubio3D.CLIP_FRAMES:
		if player.has_animation(clip):
			result.append(clip)
	for clip: StringName in player.get_animation_list():
		if String(clip) not in result and clip != &"RESET":
			result.append(String(clip))
	return result


## Looping clips never finish on their own; one pass is a wrap back to the start.
func _finish_looping_clip() -> void:
	var player := cubio.animation_player()
	if _clip.is_empty() or not player.is_playing():
		return
	var position := player.current_animation_position
	if position < _last_position:
		player.seek(player.current_animation_length - LOOP_REST, true)
		player.pause()
		_play_pause.text = "Play"
	_last_position = player.current_animation_position


func _at_end() -> bool:
	var player := cubio.animation_player()
	return player.current_animation_position >= player.current_animation_length - 2.0 * LOOP_REST


func _update_clip_status() -> void:
	var player := cubio.animation_player()
	if _clip.is_empty():
		_clip_status.text = "Idling as in the game"
		return
	_clip_status.text = "%s · %.2f / %.2f s%s" % [
		_clip.capitalize(),
		player.current_animation_position,
		player.current_animation_length,
		"" if player.is_playing() else " · paused",
	]


func _choice(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	return button


func _paint(button: Button, color: Color) -> void:
	var text := Color.WHITE if color.get_luminance() < 0.6 else Color("133253")
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.15) if state == "hover" else color
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		# The chosen colour carries a thick outline, as on the phone's colour picker.
		style.set_border_width_all(4 if state == "pressed" else 0)
		style.border_color = Color("133253")
		style.draw_center = state != "focus"
		button.add_theme_stylebox_override(state, style)
	for name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(name, text)
