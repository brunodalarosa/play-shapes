class_name Squircle3D
extends Node3D
## Real-time 3D Squircle: the exported rig and clips with a player tint, natural blinking,
## held stances and turning toward travel. Presentation only; no input or game state.

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
const FACE_NEUTRAL: Texture2D = preload(
	"res://assets/runtime/animated_characters/squircle/v1/model/face-neutral.png"
)
const FACE_BLINK: Texture2D = preload(
	"res://assets/runtime/animated_characters/squircle/v1/model/face-blink.png"
)
const TINT_SHADER: Shader = preload("res://characters/squircle_tint.gdshader")
const FACE_SHADER: Shader = preload("res://characters/squircle_face.gdshader")

static var _tints: Dictionary = { }
static var _faces: Dictionary = { }
static var _prepared_libraries: Dictionary = { }

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
var _player: AnimationPlayer
var _model: Node3D
var _face: MeshInstance3D
var _tinted: Array[MeshInstance3D] = []
var _held: String = ""
var _held_time: float = 0.0
var _held_direction: float = 1.0
var _after_release: String = ""
var _blink_wait: float = 0.0
var _blink_left: float = 0.0
var _yaw_target: float = 0.0
var _rate: float = 1.0

@onready var nameplate: Label3D = $Nameplate


func _ready() -> void:
	_model = $Model
	_model.scale = Vector3.ONE * (standing_height / SOURCE_HEIGHT)
	_player = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_prepare_library(_player)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "Face":
			_face = mesh
		elif String(mesh.name) in TINTED_MESHES:
			_tinted.append(mesh)
	assert(_face != null and _tinted.size() == TINTED_MESHES.size(), "Squircle model is incomplete")
	set_player_color(player_color)
	_face.material_override = _face_material(false)
	_blink_wait = randf_range(blink_interval.x, blink_interval.y)
	play("idle")


func set_player_color(value: Color) -> void:
	player_color = value
	if _tinted.is_empty():
		return
	var material := _tint_material(value)
	for mesh: MeshInstance3D in _tinted:
		mesh.material_override = material


func set_player_name(value: String) -> void:
	nameplate.text = value
	# Long names shrink a little so neighbours' nameplates overlap less.
	nameplate.font_size = maxi(36, 48 - 2 * maxi(0, value.length() - 11))


## Plays a looping clip, or enters a held stance and keeps its last frame. Requesting
## anything else while a stance is held first releases it by reversing from its progress.
func play(next: String) -> void:
	assert(next in LOOPING_CLIPS or next in HELD_CLIPS, "Unknown Squircle clip %s" % next)
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
	return _blink_left > 0.0


func _process(delta: float) -> void:
	_advance_held(delta)
	_player.speed_scale = _rate if _held == "" else 1.0
	_model.rotation.y = rotate_toward(
		_model.rotation.y,
		_yaw_target,
		deg_to_rad(turn_speed_degrees) * delta,
	)
	_advance_blink(delta)


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


func _advance_blink(delta: float) -> void:
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_face.material_override = _face_material(false)
			_blink_wait = randf_range(blink_interval.x, blink_interval.y)
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_left = blink_duration
		_face.material_override = _face_material(true)


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


static func _face_material(blink: bool) -> ShaderMaterial:
	if not _faces.has(blink):
		var material := ShaderMaterial.new()
		material.shader = FACE_SHADER
		material.set_shader_parameter("face", FACE_BLINK if blink else FACE_NEUTRAL)
		_faces[blink] = material
	return _faces[blink]
