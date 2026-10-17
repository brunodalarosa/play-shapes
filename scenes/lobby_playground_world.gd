class_name LobbyPlaygroundWorld
extends Node3D
## The Playground plaza. Reconciles host registry records into one character per player
## identity. Bodies simulate on a hidden 2D action plane, where one-way landings, FALL and
## player bounce already exist; each body's 3D Squircle mirrors it in the plaza at depth zero.

const CHARACTER: PackedScene = preload("res://characters/lobby_squircle.tscn")
const VISUAL: PackedScene = preload("res://characters/squircle_3d.tscn")
const ACTIVE_PRESETS: ActivePresets = preload("res://Tuning/Active Presets.tres")
const MAX_SEQUENCE := 9007199254740991.0
## Plane pixels per world unit. One unit is one character height, the motor's 96-pixel body.
const PIXELS_PER_UNIT := 96.0
## Landing collision depth below its top, plane pixels.
const LANDING_THICKNESS := 10.0
const PLATFORM_LAYER := 128

## Movement preset. Empty uses the active lobby preset.
@export var movement: LobbyMovementTuning
## A body falling this far below the ground, in world units, respawns.
@export var fall_reset_depth: float = 3.0

var _characters: Dictionary = { }
var _last_sequence: Dictionary = { }

@onready var billboard: PlazaBillboard = $Plaza/Billboard
@onready var camera: Camera3D = $Camera3D
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _visuals: Node3D = $Characters
@onready var _surfaces: Node2D = $Simulation/PlatformSurfaces
@onready var _bodies: Node2D = $Simulation/Bodies


func _ready() -> void:
	if movement == null:
		# Looked up by path: scripts compiled before autoloads register cannot name SessionHost.
		var host := get_node_or_null(^"/root/SessionHost")
		var presets: ActivePresets = host.active_presets if host != null else ACTIVE_PRESETS
		movement = presets.lobby_movement
	for landing: PlazaLanding in landings():
		_surfaces.add_child(_surface_for(landing))


static func to_plane(point: Vector3) -> Vector2:
	return Vector2(point.x, -point.y) * PIXELS_PER_UNIT


static func to_world(point: Vector2) -> Vector3:
	return Vector3(point.x, -point.y, 0.0) / PIXELS_PER_UNIT


func landings() -> Array[PlazaLanding]:
	var found: Array[PlazaLanding] = []
	for node: Node in $Plaza.find_children("*", "PlazaLanding", true, false):
		found.append(node as PlazaLanding)
	return found


func surface_named(surface_name: String) -> PlatformSurface:
	return _surfaces.get_node_or_null(surface_name) as PlatformSurface


func spawn_point(seat: int) -> Vector2:
	return to_plane((_spawn_points.get_child(seat - 1) as Node3D).global_position)


func reconcile(players: Array[Dictionary]) -> void:
	var present: Dictionary = { }
	for player: Dictionary in players:
		var player_id := String(player.player_id)
		var seat := int(player.seat)
		if seat < 1 or seat > _spawn_points.get_child_count():
			continue
		present[player_id] = true
		var character := _characters.get(player_id) as LobbySquircle
		if character == null:
			character = _spawn(player, seat)
			_characters[player_id] = character
		else:
			character.refresh_player(player)
		if String(player.state) != "connected":
			_last_sequence.erase(player_id)
	for player_id: String in _characters.keys():
		if present.has(player_id):
			continue
		var character := _characters[player_id] as LobbySquircle
		character.queue_free()
		_characters.erase(player_id)
		_last_sequence.erase(player_id)


func clear_all_input() -> void:
	for character: LobbySquircle in _characters.values():
		character.clear_input()


func reset_sequence(player_id: String) -> void:
	_last_sequence.erase(player_id)
	var character := character_for(player_id)
	if character != null:
		character.clear_input()


func character_for(player_id: String) -> LobbySquircle:
	return _characters.get(player_id) as LobbySquircle


func handle_input(player: Dictionary, message: Dictionary, now_msec: int) -> Dictionary:
	if player.is_empty() or String(player.get("state", "")) != "connected":
		return _rejected("not_joined")
	var player_id := String(player.player_id)
	var character := character_for(player_id)
	if character == null or not character.connected:
		return _rejected("not_in_lobby")
	var raw_sequence: Variant = message.get("input_seq")
	if typeof(raw_sequence) not in [TYPE_INT, TYPE_FLOAT]:
		return _rejected("invalid_sequence")
	var sequence := float(raw_sequence)
	if (
		is_nan(sequence) or is_inf(sequence) or sequence < 1.0 or sequence > MAX_SEQUENCE \
				or floor(sequence) != sequence
		or sequence <= float(_last_sequence.get(player_id, 0))
	):
		return _rejected("stale_sequence")
	var kind: Variant = message.get("type", "")
	if kind not in ["lobby_move", "lobby_jump_release", "lobby_fall_release"]:
		return _rejected("unsupported_message")
	var action := ""
	if kind == "lobby_jump_release":
		action = "jump"
	elif kind == "lobby_fall_release":
		action = "fall"
	var snapshot := PlatformInput.validate(message, action)
	if not snapshot.accepted:
		return _rejected(snapshot.code)
	_last_sequence[player_id] = int(sequence)
	# Releases carry their own latest axes; apply atomically before host eligibility.
	character.motor.set_input(snapshot.axes, snapshot.stance, now_msec)
	if action == "jump":
		return { "accepted": true, "jumped": character.motor.request_jump() }
	if action == "fall":
		return { "accepted": true, "dropped": character.motor.request_fall() }
	return { "accepted": true }


func _process(_delta: float) -> void:
	for character: LobbySquircle in _characters.values():
		var visual := character.visual
		visual.position = to_world(character.position)
		visual.set_travel(character.velocity.x / PIXELS_PER_UNIT)


func _spawn(player: Dictionary, seat: int) -> LobbySquircle:
	var visual := VISUAL.instantiate() as Squircle3D
	_visuals.add_child(visual)
	var character := CHARACTER.instantiate() as LobbySquircle
	_apply_movement(character.get_node("PlatformMotor") as PlatformMotor)
	character.configure(player, spawn_point(seat), visual)
	_bodies.add_child(character)
	visual.position = to_world(character.position)
	return character


func _apply_movement(motor: PlatformMotor) -> void:
	motor.move_speed = movement.move_speed * PIXELS_PER_UNIT
	motor.acceleration = movement.acceleration * PIXELS_PER_UNIT
	motor.gravity = movement.gravity * PIXELS_PER_UNIT
	motor.jump_impulse = movement.jump_impulse() * PIXELS_PER_UNIT
	motor.fall_reset_y = fall_reset_depth * PIXELS_PER_UNIT


func _surface_for(landing: PlazaLanding) -> PlatformSurface:
	var surface := PlatformSurface.new()
	# Landings share a node name inside their props, so the surface takes the prop's name.
	surface.name = landing.get_parent().name if landing.name == &"Landing" else landing.name
	surface.drop_rule = landing.drop_rule
	surface.collision_layer = PLATFORM_LAYER
	surface.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "LandingTop"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(landing.width * PIXELS_PER_UNIT, LANDING_THICKNESS)
	shape.shape = rectangle
	shape.one_way_collision = landing.one_way
	shape.position = to_plane(landing.global_position) + Vector2(0.0, LANDING_THICKNESS * 0.5)
	surface.add_child(shape)
	return surface


func _rejected(code: String) -> Dictionary:
	return { "accepted": false, "code": code, "message": "Lobby input was not accepted" }
