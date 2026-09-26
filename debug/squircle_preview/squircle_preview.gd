extends Control
## Local art comparison. Inputs change only this scene's presentation.

const MANIFEST_PATH := "res://debug/squircle_preview/manifest.json"
const ASSET_ROOT := "res://debug/squircle_preview/assets/"
const TINT_SHADER: Shader = preload("res://debug/squircle_preview/render_tint.gdshader")
const CURRENT_CHARACTER: PackedScene = preload("res://characters/shape_character.tscn")
const ACTIONS := ["idle", "walk", "run"]
const VIEWS := ["front", "three-quarter"]
const EXPRESSIONS := ["neutral", "blink"]

var _clips: Dictionary = {}
var _textures: Dictionary = {}
var _loaded_clip: String = ""
var _samples: Array[Dictionary] = []
var _action: String = "idle"
var _view: String = "front"
var _expression: String = "neutral"
var _color: Dictionary = CharacterSelection.COLORS[5]
var _elapsed: float = 0.0
var _playing: bool = true
var _info: Label
var _play_button: Button


func _ready() -> void:
	_load_manifest()
	_build_ui()
	_update_selection()


func _process(delta: float) -> void:
	if _playing:
		_elapsed += delta
	_update_frame()


func _load_manifest() -> void:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert(file != null, "PS-058 preview metadata is missing")
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	assert(data.get("shape_id") == "squircle")
	assert(int(data.resolution[0]) == 256 and int(data.resolution[1]) == 256)
	for clip: Dictionary in data.clips:
		var key := "%s-%s" % [clip.name, clip.view]
		assert(int(clip.first_frame) == 1 and int(clip.last_frame) == int(clip.frames))
		_clips[key] = clip


func _sheet(key: String, layer: String, clip: Dictionary) -> Texture2D:
	var sheet_key := "%s-%s" % [key, layer]
	if not _textures.has(sheet_key):
		var path := "%s%s.png" % [ASSET_ROOT, sheet_key]
		var image := Image.new()
		assert(image.load(path) == OK, "Missing preview sheet: " + path)
		assert(image.get_width() == 2048)
		assert(image.get_height() == 256 * ceili(float(clip.frames) / 8.0))
		_textures[sheet_key] = ImageTexture.create_from_image(image)
	return _textures[sheet_key] as Texture2D


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("172131")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	margin.add_child(column)
	var title := Label.new()
	title.text = "RENDERED SQUIRCLE · GODOT ART PREVIEW"
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Compare the PS-057 render with the current 2D squircle. F12 opens the debug launcher."
	column.add_child(subtitle)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 18)
	column.add_child(controls)
	_add_picker(controls, "Action", ACTIONS, 0, func(index: int) -> void:
		_action = ACTIONS[index]
		_elapsed = 0.0
		_update_selection())
	_add_picker(controls, "View", VIEWS, 0, func(index: int) -> void:
		_view = VIEWS[index]
		_elapsed = 0.0
		_update_selection())
	var color_names: Array[String] = []
	for option: Dictionary in CharacterSelection.COLORS:
		color_names.append(String(option.name))
	_add_picker(controls, "Player color", color_names, 5, func(index: int) -> void:
		_color = CharacterSelection.COLORS[index]
		_update_selection())
	_add_picker(controls, "Face", EXPRESSIONS, 0, func(index: int) -> void:
		_expression = EXPRESSIONS[index]
		_update_selection())
	_play_button = Button.new()
	_play_button.text = "Pause"
	_play_button.pressed.connect(func() -> void:
		_playing = not _playing
		_play_button.text = "Pause" if _playing else "Play")
	controls.add_child(_play_button)

	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", 24)
	column.add_child(stage)
	_add_sample(stage, "Rendered · shared screen · 256 px", 256, true)
	_add_sample(stage, "Current 2D · shared screen", 256, false)
	_add_sample(stage, "Rendered · phone preview · 128 px", 128, true)
	_add_sample(stage, "Current 2D · phone preview", 128, false)
	_info = Label.new()
	column.add_child(_info)
	var note := Label.new()
	note.text = "Comparison canvases are reference sizes; phone display and owner art approval require separate review."
	column.add_child(note)


func _add_picker(parent: HBoxContainer, title: String, names: Array, initial: int, changed: Callable) -> void:
	var group := VBoxContainer.new()
	parent.add_child(group)
	var label := Label.new()
	label.text = title
	group.add_child(label)
	var picker := OptionButton.new()
	for name: String in names:
		picker.add_item(name.capitalize())
	picker.selected = initial
	picker.item_selected.connect(changed)
	group.add_child(picker)


func _add_sample(parent: HBoxContainer, title: String, size: int, rendered: bool) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 12)
	parent.add_child(group)
	var label := Label.new()
	label.text = title
	group.add_child(label)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(size, size)
	canvas.clip_contents = true
	group.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("405170")
	backdrop.custom_minimum_size = Vector2(size, size)
	canvas.add_child(backdrop)
	var floor := ColorRect.new()
	floor.color = Color("92a6a0")
	floor.position = Vector2(0, 204.0 * size / 256.0)
	floor.size = Vector2(size, 1)
	canvas.add_child(floor)
	var scale_factor := float(size) / 256.0
	if rendered:
		var root := Node2D.new()
		root.position = Vector2(size / 2.0, 204.0 * scale_factor)
		root.scale = Vector2.ONE * scale_factor
		canvas.add_child(root)
		var base := Sprite2D.new()
		base.centered = false
		base.region_enabled = true
		base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var material := ShaderMaterial.new()
		material.shader = TINT_SHADER
		base.material = material
		root.add_child(base)
		var face := Sprite2D.new()
		face.centered = false
		face.region_enabled = true
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(face)
		_samples.append({"rendered": true, "base": base, "face": face, "material": material})
	else:
		var current := CURRENT_CHARACTER.instantiate() as ShapeCharacter
		current.body_shape = &"squircle"
		current.position = Vector2(size / 2.0, 140.0 * scale_factor)
		current.scale = Vector2.ONE * scale_factor
		canvas.add_child(current)
		for hand_name: String in ["LeftHand", "RightHand"]:
			(current.get_node(hand_name) as Sprite2D).texture = preload("res://assets/runtime/shape_characters/hands/open.png")
		_samples.append({"rendered": false, "character": current})


func _update_selection() -> void:
	var key := "%s-%s" % [_action, _view]
	var clip: Dictionary = _clips[key]
	if _loaded_clip != key:
		_textures.clear()
		_loaded_clip = key
	var anchor := Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
	var base_sheet := _sheet(key, "colorable", clip)
	var face_sheet := _sheet(key, _expression, clip)
	for sample: Dictionary in _samples:
		if sample.rendered:
			var base := sample.base as Sprite2D
			var face := sample.face as Sprite2D
			base.texture = base_sheet
			face.texture = face_sheet
			base.position = -anchor
			face.position = -anchor
			(sample.material as ShaderMaterial).set_shader_parameter("player_color", Color(String(_color.hex)))
		else:
			var current := sample.character as ShapeCharacter
			current.player_color = Color(String(_color.hex))
			(current.get_node("Face") as Sprite2D).texture = load("res://assets/runtime/shape_characters/faces/%s.png" % _expression)
	_info.text = "%s · %s · %s (%s) · %d frames at %d fps · anchor (%.2f, %.2f)" % [
		_action.capitalize(), _view.capitalize(), _color.name, _color.id,
		clip.frames, clip.fps, anchor.x, anchor.y]
	_update_frame()


func _update_frame() -> void:
	if _samples.is_empty():
		return
	var clip: Dictionary = _clips["%s-%s" % [_action, _view]]
	var frame := int(_elapsed * float(clip.fps)) % int(clip.frames)
	var tile := Rect2(frame % int(clip.sheet_columns) * 256, floori(float(frame) / float(clip.sheet_columns)) * 256, 256, 256)
	for sample: Dictionary in _samples:
		if sample.rendered:
			(sample.base as Sprite2D).region_rect = tile
			(sample.face as Sprite2D).region_rect = tile
