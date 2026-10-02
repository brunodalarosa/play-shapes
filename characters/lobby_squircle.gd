class_name LobbySquircle
extends CharacterBody2D
## Host-owned Playground body using the approved Squircle v1 animation sheets.

## Scale of the shared Squircle sheet playback.
@export var visual_scale: float = 0.58

var player_id: String = ""
var spawn_point: Vector2 = Vector2.ZERO
var connected: bool = true
var _blink_elapsed: float = 0.0
var _initial_player: Dictionary = {}

@onready var motor: PlatformMotor = $PlatformMotor
@onready var _character: SquircleV1Playback = $SquircleV1Playback
@onready var _nameplate: Label = $Nameplate


func _ready() -> void:
	motor.fall_reset_requested.connect(_respawn)
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
	motor.set_enabled(value)
	set_physics_process(connected)
	if not connected:
		_character.play("idle", "front")


func clear_input() -> void:
	motor.clear_input()
	_character.play("idle", "front")


func _respawn() -> void:
	position = spawn_point
	_character.play("idle", "front")


func _physics_process(_delta: float) -> void:
	var action := motor.presentation_action()
	var view := "front" if action in ["idle", "look_up", "crouch"] else "three-quarter"
	_character.play(action, view)
	if absf(velocity.x) > 20.0:
		# The source three-quarter frames face left before mirroring.
		_character.flip_h = velocity.x > 0.0


func _process(delta: float) -> void:
	_blink_elapsed = fmod(_blink_elapsed + delta, 4.2)
	_character.face_blink = _blink_elapsed < 0.12
