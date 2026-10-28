class_name Cubio3D
extends Node3D
## Real-time 3D Cubio: the exported rig and clips with a player tint, a shape face that blinks
## on its own, held stances and turning toward travel. Presentation only; no input or game state.

const LOOPING_CLIPS: Array[String] = ["idle", "walk", "run", "lever_pull"]
const HELD_CLIPS: Array[String] = ["look_up", "crouch"]
const CLIP_FRAMES := {
	"idle": 48,
	"walk": 24,
	"run": 16,
	"lever_pull": 24,
	"look_up": 9,
	"crouch": 9,
}
const CLIP_FPS := 24.0
## Forward travel of each locomotion clip in source metres per second.
const CLIP_TRAVEL := { "walk": 1.65, "run": 3.6 }
## Source standing height in metres, from the sole to the top of the body.
const SOURCE_HEIGHT := 2.62
const TINTED_MESHES: Array[String] = ["Body", "HandL", "HandR", "FootL", "FootR"]
const TINT_SHADER: Shader = preload("res://characters/cubio_tint.gdshader")
const FACE_ANCHOR_PATH := "res://assets/runtime/animated_characters/cubio/face_anchor.json"
## The face a Cubio shows when nothing else is asked of it.
const DEFAULT_FACE := "face_slightly_smiling"

static var _tints: Dictionary = { }
static var _prepared_libraries: Dictionary = { }
static var _face_anchor: ShapeFaceAnchor
static var _face_manifest: ShapeFaceManifest

## Standing height in world units; the model is scaled to fit.
@export var standing_height: float = 1.0
## Yaw toward the direction of travel, degrees. Zero faces the camera.
@export_range(0.0, 90.0) var travel_turn_degrees: float = 62.0
## Yaw change rate, degrees per second.
@export var turn_speed_degrees: float = 540.0
## Blend between clips, seconds.
@export var clip_blend: float = 0.12
## Range of seconds between natural blinks.
@export var blink_interval := Vector2(2.4, 5.6)
## Duration of one blink, seconds.
@export var blink_duration: float = 0.12
## Fastest locomotion playback rate when travel outpaces the clip's stride.
@export var max_stride_rate: float = 2.2

var player_color := Color("#1e88e5"):
	set = set_player_color
var action: String = ""
## The drawn face, on the model's face anchor.
var face: ShapeFace3D
## Which face [member face] shows, and its natural blinks.
var expressions := ShapeFaceExpressions.new()
## When true, clips and their speed are left to whoever drives [method animation_player], as a
## lab does; [method play] and [method set_travel] still record what they are asked.
var manual_playback := false
var _player: AnimationPlayer
var _model: Node3D
var _tinted: Array[MeshInstance3D] = []
var _held: String = ""
var _held_time: float = 0.0
var _held_direction: float = 1.0
var _after_release: String = ""
var _yaw_target: float = 0.0
var _rate: float = 1.0
## This Cubio's own tint once it has been dithered, so other Cubios of its colour stay whole.
var _own_tint: ShaderMaterial
var _dither := 0.0

@onready var nameplate: Label3D = $Nameplate


func _ready() -> void:
	_model = $Model
	_model.scale = Vector3.ONE * (standing_height / SOURCE_HEIGHT)
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_prepare_library(_player)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name) in TINTED_MESHES:
			_tinted.append(mesh)
	var anchor := _model.find_child("FaceAnchor", true, false) as Node3D
	assert(anchor != null and _tinted.size() == TINTED_MESHES.size(), "Cubio model is incomplete")
	set_player_color(player_color)
	_add_face(anchor)
	play("idle")


func set_player_color(value: Color) -> void:
	player_color = value
	if _tinted.is_empty():
		return
	if _own_tint != null:
		_own_tint.set_shader_parameter("player_color", value)
		return
	var material := _tint_material(value)
	for mesh: MeshInstance3D in _tinted:
		mesh.material_override = material


func set_player_name(value: String) -> void:
	nameplate.text = value
	# Long names shrink a little so neighbours' nameplates overlap less.
	nameplate.font_size = maxi(36, 48 - 2 * maxi(0, value.length() - 11))


## Leaves out [param amount] of this Cubio's pixels in an ordered pattern, so a Cubio behind it
## shows through (decision 0051). Zero draws it whole.
func set_dither(amount: float) -> void:
	if is_equal_approx(amount, _dither) or _tinted.is_empty():
		return
	_dither = amount
	if _own_tint == null:
		_own_tint = _tint_material(player_color).duplicate() as ShaderMaterial
		for mesh: MeshInstance3D in _tinted:
			mesh.material_override = _own_tint
	_own_tint.set_shader_parameter("dither", amount)
	face.dither = amount


func dither() -> float:
	return _dither


## Places the face on its anchor; see [ShapeFaceAnchor].
func set_face_placement(placement: ShapeFaceAnchor) -> void:
	face.position = Vector3(placement.offset.x, placement.offset.y, 0.0)
	face.height = placement.height


func animation_player() -> AnimationPlayer:
	return _player


## Plays a looping clip, or enters a held stance and keeps its last frame. Requesting
## anything else while a stance is held first releases it by reversing from its progress.
func play(next: String) -> void:
	assert(next in LOOPING_CLIPS or next in HELD_CLIPS, "Unknown Cubio clip %s" % next)
	if _held != "":
		if next == _held:
			_held_direction = 1.0
			_after_release = ""
		else:
			_held_direction = -1.0
			_after_release = next
		return
	if next == action:
		return
	action = next
	if manual_playback:
		return
	if next in HELD_CLIPS:
		_held = next
		_held_time = 0.0
		_held_direction = 1.0
		_player.play(next, clip_blend)
		_player.pause()
		_player.seek(0.0, true)
		return
	_player.play(next, clip_blend)


## Turns toward horizontal travel, in world units per second, and matches the stride.
func set_travel(velocity_x: float) -> void:
	if action in CLIP_TRAVEL and absf(velocity_x) > 0.01:
		_yaw_target = deg_to_rad(travel_turn_degrees) * signf(velocity_x)
		var stride := float(CLIP_TRAVEL[action]) * standing_height / SOURCE_HEIGHT
		_rate = clampf(absf(velocity_x) / stride, 1.0, max_stride_rate)
	else:
		_yaw_target = 0.0
		_rate = 1.0


## Current yaw of the model, radians. Positive turns toward +X.
func facing_yaw() -> float:
	return _model.rotation.y


func is_blinking() -> bool:
	return face.blinking


## The face placement every Cubio starts with, read once from its anchor file.
static func face_anchor() -> ShapeFaceAnchor:
	if _face_anchor == null:
		_face_anchor = ShapeFaceAnchor.load_file(FACE_ANCHOR_PATH)
		assert(_face_anchor != null, "Cubio's face anchor file is missing or malformed")
	return _face_anchor


## Makes [param placement] the face placement every Cubio starts with, and writes it to
## [param path]. Returns false when the file cannot be written.
static func store_face_anchor(placement: ShapeFaceAnchor, path := FACE_ANCHOR_PATH) -> bool:
	if not placement.save_file(path):
		return false
	_face_anchor = ShapeFaceAnchor.load_file(path)
	return _face_anchor != null


func _process(delta: float) -> void:
	_model.rotation.y = rotate_toward(
		_model.rotation.y,
		_yaw_target,
		deg_to_rad(turn_speed_degrees) * delta,
	)
	if manual_playback:
		return
	_advance_held(delta)
	_player.speed_scale = _rate if _held == "" else 1.0


func _add_face(anchor: Node3D) -> void:
	if _face_manifest == null:
		_face_manifest = ShapeFaceManifest.load_default()
	expressions.base_face = DEFAULT_FACE
	expressions.blink_interval = blink_interval
	expressions.blink_seconds = blink_duration
	face = ShapeFace3D.new()
	face.name = "ShapeFace"
	face.manifest = _face_manifest
	face.face_name = DEFAULT_FACE
	face.expressions = expressions
	# The body's push of 2.0 plus a margin: the body's front is two large triangles, and close to
	# the camera their interpolated depth can reach past a face lying just on top of them.
	face.front_push = 2.1
	set_face_placement(face_anchor())
	anchor.add_child(face)


func _advance_held(delta: float) -> void:
	if _held == "":
		return
	var length := _player.get_animation(_held).length
	_held_time = clampf(_held_time + _held_direction * delta, 0.0, length)
	_player.seek(_held_time, true)
	if _held_direction < 0.0 and _held_time <= 0.0:
		var next := _after_release
		_held = ""
		action = ""
		_after_release = ""
		play(next if next != "" else "idle")


## Imported clips end on their last exported key. Loops need one more frame of length so
## the wrap interpolates back to frame one; held stances stop on their final key.
static func _prepare_library(player: AnimationPlayer) -> void:
	for library_name: StringName in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		if _prepared_libraries.has(library.get_instance_id()):
			continue
		_prepared_libraries[library.get_instance_id()] = true
		for clip: String in CLIP_FRAMES:
			if not library.has_animation(clip):
				continue
			var animation := library.get_animation(clip)
			var frames := int(CLIP_FRAMES[clip])
			if clip in LOOPING_CLIPS:
				animation.loop_mode = Animation.LOOP_LINEAR
				animation.length = frames / CLIP_FPS
			else:
				animation.loop_mode = Animation.LOOP_NONE
				animation.length = (frames - 1) / CLIP_FPS


static func _tint_material(color: Color) -> ShaderMaterial:
	var key := color.to_html(false)
	if not _tints.has(key):
		var material := ShaderMaterial.new()
		material.shader = TINT_SHADER
		material.set_shader_parameter("player_color", color)
		_tints[key] = material
	return _tints[key]
