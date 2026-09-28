extends Control
## Focused desktop review of approved Squircle v1 motion at both reference sizes.

const MANIFEST_PATH := "res://assets/runtime/animated_characters/squircle/v1/manifest.json"
const ASSET_ROOT := "res://assets/runtime/animated_characters/squircle/v1/"
const RENDERED_SAMPLE: Script = preload("res://debug/squircle_preview/rendered_sample.gd")
const ACTIONS := ["idle", "walk", "run"]
const VIEWS := ["front", "three-quarter"]
const EXPRESSIONS := ["neutral", "blink"]

var _clips: Dictionary = {}
var _textures: Dictionary = {}
var _loaded_clip: String = ""
var _samples: Array[SquircleRenderedSample] = []
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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(data.get("schema") == "play-shapes.squircle-animation.v1")
	assert(data.get("shape_id") == "squircle")
	assert(int(data.resolution[0]) == 256 and int(data.resolution[1]) == 256)
	for clip: Dictionary in data.clips:
		assert(int(clip.first_frame) == 1 and int(clip.last_frame) == int(clip.frames))
		_clips["%s-%s" % [clip.name, clip.view]] = clip
	assert(_clips.size() == ACTIONS.size() * VIEWS.size())


func _sheet(key: String, layer: String, clip: Dictionary) -> Texture2D:
	var sheet_key := "%s-%s" % [key, layer]
	if not _textures.has(sheet_key):
		var path := "%s%s.png" % [ASSET_ROOT, sheet_key]
		var sheet := ResourceLoader.load(path) as Texture2D
		assert(sheet != null, "Missing Squircle v1 sheet: " + path)
		assert(sheet.get_width() == int(clip.sheet_columns) * 256)
		assert(sheet.get_height() == ceili(float(clip.frames) / float(clip.sheet_columns)) * 256)
		_textures[sheet_key] = sheet
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
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ANIMATION LAB"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("ffd166"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Squircle v1 · Approved rendered motion"
	subtitle.add_theme_font_size_override("font_size", 19)
	column.add_child(subtitle)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 18)
	column.add_child(controls)
	_add_picker(controls, "Action", ACTIONS, 0, func(index: int) -> void:
		_action = ACTIONS[index]
		_update_selection())
	_add_picker(controls, "View", VIEWS, 0, func(index: int) -> void:
		_view = VIEWS[index]
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
	_play_button.pressed.connect(_toggle_play)
	controls.add_child(_play_button)

	var stage := HBoxContainer.new()
	stage.add_theme_constant_override("separation", 40)
	column.add_child(stage)
	_add_sample(stage, "256 px · full reference", 256)
	_add_sample(stage, "128 px · small reference", 128)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 19)
	column.add_child(_info)
	var note := Label.new()
	note.text = "Each change starts at frame 1. Pause holds the current frame; Play resumes it. F12 opens the debug launcher."
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


func _add_sample(parent: HBoxContainer, title: String, size: int) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 12)
	parent.add_child(group)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 19)
	group.add_child(label)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(size, size)
	canvas.clip_contents = true
	group.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("405170")
	backdrop.size = Vector2(size, size)
	canvas.add_child(backdrop)
	var floor := ColorRect.new()
	floor.color = Color("92a6a0")
	floor.position = Vector2(0, 204.0 * size / 256.0)
	floor.size = Vector2(size, 1)
	canvas.add_child(floor)
	var sample := RENDERED_SAMPLE.new() as SquircleRenderedSample
	sample.position = Vector2(size / 2.0, 204.0 * size / 256.0)
	sample.scale = Vector2.ONE * float(size) / 256.0
	canvas.add_child(sample)
	_samples.append(sample)


func _update_selection() -> void:
	_elapsed = 0.0
	var key := "%s-%s" % [_action, _view]
	var clip: Dictionary = _clips[key]
	if _loaded_clip != key:
		_textures.clear()
		_loaded_clip = key
	var base := _sheet(key, "colorable", clip)
	var face := _sheet(key, _expression, clip)
	for sample: SquircleRenderedSample in _samples:
		sample.configure(clip, base, face, Color(String(_color.hex)))
	var anchor := Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
	_info.text = "%s · %s · %s · %s  |  %d frames · %d fps · anchor (%.2f, %.2f)" % [
		_action.capitalize(), _view.capitalize(), _color.name, _expression.capitalize(),
		clip.frames, clip.fps, anchor.x, anchor.y]
	_update_frame()


func _update_frame() -> void:
	if _samples.is_empty():
		return
	var clip: Dictionary = _clips["%s-%s" % [_action, _view]]
	var frame := int(_elapsed * float(clip.fps)) % int(clip.frames)
	for sample: SquircleRenderedSample in _samples:
		sample.show_frame(frame)


func _toggle_play() -> void:
	_playing = not _playing
	_play_button.text = "Pause" if _playing else "Play"
