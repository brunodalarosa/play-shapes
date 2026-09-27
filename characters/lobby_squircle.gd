class_name LobbySquircle
extends CharacterBody2D
## Host-owned Playground body. The rendered layers remain a lobby-only workaround.

const MANIFEST_PATH := "res://debug/squircle_preview/manifest.json"
const ASSET_ROOT := "res://debug/squircle_preview/assets/"
const TINT_SHADER: Shader = preload("res://debug/squircle_preview/render_tint.gdshader")
const TILE_SIZE := 256
const INPUT_TIMEOUT_MSEC := 350

static var _clips: Dictionary = {}
static var _sheets: Dictionary = {}
static var _live_instances: int = 0

## Horizontal top speed in world pixels per second.
@export var move_speed: float = 330.0
## Horizontal acceleration on the ground and in the air.
@export var acceleration: float = 1900.0
@export var gravity: float = 1350.0
## Reaches the next shelf from the one below at the default gravity.
@export var jump_impulse: float = 940.0
@export var visual_scale: float = 0.58
@export var run_threshold: float = 0.72
@export var fall_reset_y: float = 1160.0

var player_id: String = ""
var spawn_point: Vector2 = Vector2.ZERO
var connected: bool = true
var _horizontal: float = 0.0
var _last_input_msec: int = 0
var _jump_queued: bool = false
var _elapsed: float = 0.0
var _blink_elapsed: float = 0.0
var _clip_key: String = ""
var _initial_player: Dictionary = {}

@onready var _colorable: Sprite2D = $Colorable
@onready var _face: Sprite2D = $Face
@onready var _blink: Sprite2D = $Blink
@onready var _nameplate: Label = $Nameplate


func _ready() -> void:
	_live_instances += 1
	_load_manifest()
	var material := ShaderMaterial.new()
	material.shader = TINT_SHADER
	_colorable.material = material
	_change_clip("idle-front")
	if not _initial_player.is_empty():
		_update_player(_initial_player)
	set_connected(connected)


func _exit_tree() -> void:
	_live_instances -= 1
	if _live_instances == 0:
		_sheets.clear()
		_clips.clear()


func configure(player: Dictionary, anchor: Vector2) -> void:
	player_id = String(player.player_id)
	spawn_point = anchor
	position = anchor
	connected = String(player.state) == "connected"
	if is_node_ready():
		_update_player(player)
		set_connected(connected)
	else:
		_initial_player = player


func _update_player(player: Dictionary) -> void:
	_nameplate.text = String(player.name)
	_nameplate.add_theme_font_size_override("font_size", maxi(18, 24 - maxi(0, _nameplate.text.length() - 11)))
	(_colorable.material as ShaderMaterial).set_shader_parameter("player_color", Color(String(player.character_color)))
	set_connected(String(player.state) == "connected")


func refresh_player(player: Dictionary) -> void:
	_update_player(player)


func set_connected(value: bool) -> void:
	connected = value
	if not connected:
		clear_input()
		velocity = Vector2.ZERO
	set_physics_process(connected)


func set_horizontal(value: float, now_msec: int) -> void:
	_horizontal = value
	_last_input_msec = now_msec


func clear_input() -> void:
	_horizontal = 0.0
	_jump_queued = false


func request_jump() -> bool:
	if not connected or _jump_queued or not is_on_floor():
		return false
	_jump_queued = true
	return true


func _physics_process(delta: float) -> void:
	if Time.get_ticks_msec() - _last_input_msec > INPUT_TIMEOUT_MSEC:
		_horizontal = 0.0
	velocity.x = move_toward(velocity.x, _horizontal * move_speed, acceleration * delta)
	if _jump_queued:
		velocity.y = -jump_impulse
		_jump_queued = false
	else:
		velocity.y += gravity * delta
	move_and_slide()
	if position.y > fall_reset_y:
		position = spawn_point
		velocity = Vector2.ZERO
		clear_input()
	var action := "idle" if absf(velocity.x) < 20.0 else "run" if absf(_horizontal) >= run_threshold else "walk"
	var view := "front" if action == "idle" else "three-quarter"
	_change_clip("%s-%s" % [action, view])
	if absf(velocity.x) > 20.0:
		var face_left := velocity.x < 0.0
		_colorable.flip_h = face_left
		_face.flip_h = face_left
		_blink.flip_h = face_left


func _process(delta: float) -> void:
	_elapsed += delta
	_blink_elapsed = fmod(_blink_elapsed + delta, 4.2)
	_blink.visible = _blink_elapsed < 0.12
	_face.visible = not _blink.visible
	var clip: Dictionary = _clips[_clip_key]
	var frame := int(_elapsed * float(clip.fps)) % int(clip.frames)
	var tile := Rect2(frame % int(clip.sheet_columns) * TILE_SIZE,
		floori(float(frame) / float(clip.sheet_columns)) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	for sprite: Sprite2D in [_colorable, _face, _blink]:
		sprite.region_rect = tile


func _change_clip(key: String) -> void:
	if _clip_key == key:
		return
	_clip_key = key
	_elapsed = 0.0
	var clip: Dictionary = _clips[key]
	var anchor := Vector2(float(clip.anchor_px[0]), float(clip.anchor_px[1]))
	for layer: String in ["colorable", "neutral", "blink"]:
		var sprite: Sprite2D = _colorable if layer == "colorable" else _face if layer == "neutral" else _blink
		sprite.texture = _sheet(key, layer)
		sprite.position = -anchor * visual_scale
		sprite.scale = Vector2.ONE * visual_scale


static func _load_manifest() -> void:
	if not _clips.is_empty():
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	assert(file != null, "Rendered squircle manifest is missing")
	var data: Dictionary = JSON.parse_string(file.get_as_text())
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
