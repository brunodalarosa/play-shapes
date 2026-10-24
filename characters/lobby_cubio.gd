class_name LobbyCubio
extends CharacterBody3D
## Host-owned Playground body on the plaza's action plane, locked to depth zero by its
## PlatformMotor. Its 3D Cubio rides along as a child.

var player_id: String = ""
var spawn_point: Vector3 = Vector3.ZERO
var connected: bool = true

@onready var motor: PlatformMotor = $PlatformMotor
@onready var visual: Cubio3D = $Cubio3D


func _ready() -> void:
	motor.fall_reset_requested.connect(_respawn)
	set_connected(connected)


## Places a body that is already in the tree at its seat and applies the player's look.
func configure(player: Dictionary, anchor: Vector3) -> void:
	player_id = String(player.player_id)
	spawn_point = anchor
	position = anchor
	refresh_player(player)


func refresh_player(player: Dictionary) -> void:
	visual.set_player_name(String(player.name))
	visual.player_color = Color(String(player.character_color))
	set_connected(String(player.state) == "connected")


func set_connected(value: bool) -> void:
	connected = value
	if not is_node_ready():
		return
	motor.set_enabled(value)
	set_physics_process(connected)
	if not connected:
		visual.play("idle")


func clear_input() -> void:
	motor.clear_input()
	visual.play("idle")


func _respawn() -> void:
	position = spawn_point
	visual.play("idle")


func _physics_process(_delta: float) -> void:
	visual.play(motor.presentation_action())
	visual.set_travel(velocity.x)
