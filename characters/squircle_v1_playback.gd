class_name SquircleV1Playback
extends Node2D
## Shared Squircle v1 sheet playback for the Playground and Bubbles.

const MANIFEST_PATH := "res://assets/runtime/animated_characters/squircle/v1/manifest.json"
const ASSET_ROOT := "res://assets/runtime/animated_characters/squircle/v1/"
const TINT_SHADER: Shader = preload("res://assets/runtime/animated_characters/squircle/v1/render_tint.gdshader")

static var _clips: Dictionary = {}
static var _sheets: Dictionary = {}
static var _manifest_tile_size := Vector2i(256, 256)
static var _live_instances := 0

var player_color: Color = Color("1e88e5"):
	set(value):
		player_color = value
		if _colorable != null:
			(_colorable.material as ShaderMaterial).set_shader_parameter("player_color", value)
var visual_scale: float = 1.0:
	set(value):
		visual_scale = value
		if _colorable != null:
			_apply_clip()
var face_blink := false:
	set(value):
		face_blink = value
		if _face != null:
			_face.visible = not value
			_blink.visible = value
var flip_h := false:
	set(value):
		flip_h = value
		if _colorable != null:
			for sprite: Sprite2D in [_colorable, _face, _blink]:
				sprite.flip_h = value

var _colorable: Sprite2D
var _face: Sprite2D
var _blink: Sprite2D
var _clip_key := "idle-front"
var _elapsed_msec := 0.0
var _external_time_msec := -1
var _tile_size := Vector2i(256, 256)


func _ready() -> void:
	_live_instances += 1
	_load_manifest()
	_colorable = _make_sprite("Colorable")
	_face = _make_sprite("Face")
	_blink = _make_sprite("Blink")
	var material := ShaderMaterial.new()
	material.shader = TINT_SHADER
	_colorable.material = material
	(_colorable.material as ShaderMaterial).set_shader_parameter("player_color", player_color)
	_apply_clip()
	face_blink = face_blink
	flip_h = flip_h


func _exit_tree() -> void:
	_live_instances -= 1
	if _live_instances == 0:
		_sheets.clear()
		_clips.clear()


func _process(delta: float) -> void:
	if _external_time_msec < 0:
		_elapsed_msec += delta * 1000.0
	var clip: Dictionary = _clips[_clip_key]
	var time_msec := float(_external_time_msec) if _external_time_msec >= 0 else _elapsed_msec
	var frame := int(floor(time_msec * float(clip.fps) / 1000.0)) % int(clip.frames)
	var columns := int(clip.sheet_columns)
	var tile := Rect2(frame % columns * _tile_size.x,
		floori(float(frame) / float(columns)) * _tile_size.y, _tile_size.x, _tile_size.y)
	for sprite: Sprite2D in [_colorable, _face, _blink]:
		sprite.region_rect = tile


func play(action: String = "idle", view: String = "front") -> void:
	var key := "%s-%s" % [action, view]
	if key == _clip_key or not _clips.has(key):
		return
	_clip_key = key
	_elapsed_msec = 0.0
	if _colorable != null:
		_apply_clip()


func set_playback_time_msec(value: int) -> void:
	_external_time_msec = value


func _apply_clip() -> void:
	var clip: Dictionary = _clips[_clip_key]
	var anchor := Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
	for layer: String in ["colorable", "neutral", "blink"]:
		var sprite: Sprite2D = _colorable if layer == "colorable" else _face if layer == "neutral" else _blink
		sprite.texture = _sheet(_clip_key, layer)
		sprite.position = -anchor * visual_scale
		sprite.scale = Vector2.ONE * visual_scale


func _make_sprite(sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)
	return sprite


func _load_manifest() -> void:
	if not _clips.is_empty():
		_tile_size = _manifest_tile_size
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert(file != null, "Rendered squircle manifest is missing")
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	_manifest_tile_size = Vector2i(int(data.resolution[0]), int(data.resolution[1]))
	_tile_size = _manifest_tile_size
	for clip: Dictionary in data.clips:
		_clips["%s-%s" % [clip.name, clip.view]] = clip


static func _sheet(clip_key: String, layer: String) -> Texture2D:
	var key := "%s-%s" % [clip_key, layer]
	if not _sheets.has(key):
		var path := "%s%s.png" % [ASSET_ROOT, key]
		var texture := ResourceLoader.load(path) as Texture2D
		assert(texture != null, "Rendered squircle sheet is missing: " + path)
		_sheets[key] = texture
	return _sheets[key] as Texture2D
