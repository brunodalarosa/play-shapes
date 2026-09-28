class_name LobbySquircle
extends CharacterBody2D
## Host-owned Playground body using the approved Squircle v1 animation sheets.

const INPUT_TIMEOUT_MSEC := 350

## Horizontal top speed in world pixels per second.
@export var move_speed: float = 330.0
## Horizontal acceleration on the ground and in the air.
@export var acceleration: float = 1900.0
@export var gravity: float = 1350.0
## Reaches the next shelf from the one below at the default gravity.
@export var jump_impulse: float = 940.0
## A small rebound when landing on another Playground character.
@export_range(0.0, 1.0) var player_bounce_factor: float = 0.45
@export var player_bounce_max_impulse: float = 420.0
@export var player_bounce_min_fall_speed: float = 160.0
@export var visual_scale: float = 0.58
@export var run_threshold: float = 0.72
@export var fall_reset_y: float = 1160.0

var player_id: String = ""
var spawn_point: Vector2 = Vector2.ZERO
var connected: bool = true
var _horizontal: float = 0.0
var _last_input_msec: int = 0
var _jump_queued: bool = false
var _blink_elapsed: float = 0.0
var _initial_player: Dictionary = {}

@onready var _character: SquircleV1Playback = $SquircleV1Playback
@onready var _nameplate: Label = $Nameplate


func _ready() -> void:
	_character.visual_scale = visual_scale
	_character.play("idle", "front")
	if not _initial_player.is_empty():
		_update_player(_initial_player)
	set_connected(connected)


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
	_character.player_color = Color(String(player.character_color))
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
	if not connected or _jump_queued or not is_on_floor() or velocity.y < 0.0:
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
	var falling_speed := velocity.y
	move_and_slide()
	if falling_speed >= player_bounce_min_fall_speed:
		for index in get_slide_collision_count():
			var collision := get_slide_collision(index)
			if collision.get_collider() is LobbySquircle and collision.get_normal().y < -0.7:
				velocity.y = -minf(falling_speed * player_bounce_factor, player_bounce_max_impulse)
				break
	if position.y > fall_reset_y:
		position = spawn_point
		velocity = Vector2.ZERO
		clear_input()
	var action := "idle" if absf(velocity.x) < 20.0 else "run" if absf(_horizontal) >= run_threshold else "walk"
	var view := "front" if action == "idle" else "three-quarter"
	_character.play(action, view)
	if absf(velocity.x) > 20.0:
		# The source three-quarter frames face left before mirroring.
		var face_left := velocity.x > 0.0
		_character.flip_h = face_left


func _process(delta: float) -> void:
	_blink_elapsed = fmod(_blink_elapsed + delta, 4.2)
	_character.face_blink = _blink_elapsed < 0.12
