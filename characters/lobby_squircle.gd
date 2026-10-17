class_name LobbySquircle
extends CharacterBody2D
## Host-owned Playground body on the plaza's action plane. It simulates in plane pixels and
## drives a 3D Squircle that the lobby world places in the plaza.

var player_id: String = ""
var spawn_point: Vector2 = Vector2.ZERO
var connected: bool = true
var visual: Squircle3D

@onready var motor: PlatformMotor = $PlatformMotor


func _ready() -> void:
	motor.fall_reset_requested.connect(_respawn)
	set_connected(connected)


func configure(player: Dictionary, anchor: Vector2, presentation: Squircle3D) -> void:
	player_id = String(player.player_id)
	spawn_point = anchor
	position = anchor
	visual = presentation
	refresh_player(player)


func refresh_player(player: Dictionary) -> void:
	if visual != null and visual.is_node_ready():
		visual.set_player_name(String(player.name))
		visual.player_color = Color(String(player.character_color))
	set_connected(String(player.state) == "connected")


func set_connected(value: bool) -> void:
	connected = value
	if not is_node_ready():
		return
	motor.set_enabled(value)
	set_physics_process(connected)
	if not connected and visual != null:
		visual.play("idle")


func clear_input() -> void:
	motor.clear_input()
	if visual != null:
		visual.play("idle")


func _respawn() -> void:
	position = spawn_point
	if visual != null:
		visual.play("idle")


func _physics_process(_delta: float) -> void:
	if visual != null:
		visual.play(motor.presentation_action())


func _exit_tree() -> void:
	if is_instance_valid(visual):
		visual.queue_free()
