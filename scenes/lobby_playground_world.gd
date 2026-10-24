class_name LobbyPlaygroundWorld
extends Node3D
## The Playground plaza. Reconciles host registry records into one character per player
## identity. Characters are plane-locked Jolt bodies at depth zero; their PlatformMotor makes
## the landings one-way, permits FALL and bounces players off each other. One world unit is
## one character height.

const CHARACTER: PackedScene = preload("res://characters/lobby_cubio.tscn")
const ACTIVE_PRESETS: ActivePresets = preload("res://Tuning/Active Presets.tres")
const MAX_SEQUENCE := 9007199254740991.0
## Landing collision depth below its top, world units.
const LANDING_THICKNESS := 0.1
## Extent of landings and walls across the plane, world units. Bodies stay at depth zero, so
## any depth that covers the capsule works.
const COLLISION_DEPTH := 2.0
const PLATFORM_LAYER := 128
## Half the width of a lobby body: the capsule radius in lobby_cubio.tscn, world units.
const BODY_HALF_WIDTH := 0.24
const WALL_THICKNESS := 0.42
## Walls run from below the ground to far above the highest jump, world units.
const WALL_SPAN := Vector2(-5.0, 40.0)
## Height at which the walls meet the screen edges, world units: mid-way up the play area.
const WALL_FIT_HEIGHT := 3.0

## Movement preset. Empty uses the active lobby preset.
@export var movement: LobbyMovementTuning
## A body falling this far below the ground, in world units, respawns.
@export var fall_reset_depth: float = 3.0

var _characters: Dictionary = { }
var _last_sequence: Dictionary = { }

@onready var billboard: PlazaBillboard = $Plaza/Billboard
@onready var logo_sign: Node3D = $Plaza/Cafe/LogoSign
@onready var camera: Camera3D = $Camera3D
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _bodies: Node3D = $Characters
@onready var _surfaces: Node3D = $PlatformSurfaces


func _ready() -> void:
	if movement == null:
		# Looked up by path: scripts compiled before autoloads register cannot name SessionHost.
		var host := get_node_or_null(^"/root/SessionHost")
		var presets: ActivePresets = host.active_presets if host != null else ACTIVE_PRESETS
		movement = presets.lobby_movement
	for landing: PlazaLanding in landings():
		_surfaces.add_child(_surface_for(landing))
	for wall_name: String in ["LeftWall", "RightWall"]:
		_surfaces.add_child(_wall(wall_name))
	get_viewport().size_changed.connect(fit_walls)
	fit_walls()


func landings() -> Array[PlazaLanding]:
	var found: Array[PlazaLanding] = []
	for node: Node in $Plaza.find_children("*", "PlazaLanding", true, false):
		found.append(node as PlazaLanding)
	return found


func surface_named(surface_name: String) -> PlatformSurface:
	return _surfaces.get_node_or_null(surface_name) as PlatformSurface


## Places the invisible side walls so a body stops with its centre on the screen edge: half of
## it may leave the view, never all of it.
func fit_walls() -> void:
	var view := get_viewport().get_visible_rect().size
	var fit_y := camera.unproject_position(Vector3(0.0, WALL_FIT_HEIGHT, 0.0)).y
	var stop := BODY_HALF_WIDTH + WALL_THICKNESS * 0.5
	var left := _on_action_plane(Vector2(0.0, fit_y)).x
	var right := _on_action_plane(Vector2(view.x, fit_y)).x
	(_surfaces.get_node("LeftWall") as Node3D).position.x = left - stop
	(_surfaces.get_node("RightWall") as Node3D).position.x = right + stop


func spawn_point(seat: int) -> Vector3:
	var marker := (_spawn_points.get_child(seat - 1) as Node3D).global_position
	return Vector3(marker.x, marker.y, 0.0)


func reconcile(players: Array[Dictionary]) -> void:
	var present: Dictionary = { }
	for player: Dictionary in players:
		var player_id := String(player.player_id)
		var seat := int(player.seat)
		if seat < 1 or seat > _spawn_points.get_child_count():
			continue
		present[player_id] = true
		var character := _characters.get(player_id) as LobbyCubio
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
		var character := _characters[player_id] as LobbyCubio
		character.queue_free()
		_characters.erase(player_id)
		_last_sequence.erase(player_id)


func clear_all_input() -> void:
	for character: LobbyCubio in _characters.values():
		character.clear_input()


func reset_sequence(player_id: String) -> void:
	_last_sequence.erase(player_id)
	var character := character_for(player_id)
	if character != null:
		character.clear_input()


func character_for(player_id: String) -> LobbyCubio:
	return _characters.get(player_id) as LobbyCubio


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


func _spawn(player: Dictionary, seat: int) -> LobbyCubio:
	var character := CHARACTER.instantiate() as LobbyCubio
	_apply_movement(character.get_node("PlatformMotor") as PlatformMotor)
	_bodies.add_child(character)
	character.configure(player, spawn_point(seat))
	return character


func _apply_movement(motor: PlatformMotor) -> void:
	motor.move_speed = movement.move_speed
	motor.acceleration = movement.acceleration
	motor.gravity = movement.gravity
	motor.jump_impulse = movement.jump_impulse()
	motor.fall_reset_y = -fall_reset_depth


func _surface_for(landing: PlazaLanding) -> PlatformSurface:
	var surface := PlatformSurface.new()
	# Landings share a node name inside their props, so the surface takes the prop's name.
	surface.name = landing.get_parent().name if landing.name == &"Landing" else landing.name
	surface.drop_rule = landing.drop_rule
	surface.one_way = landing.one_way
	surface.collision_layer = PLATFORM_LAYER
	surface.collision_mask = 0
	var top := landing.global_position
	surface.position = Vector3(top.x, top.y, 0.0)
	var shape := CollisionShape3D.new()
	shape.name = "LandingTop"
	var box := BoxShape3D.new()
	box.size = Vector3(landing.width, LANDING_THICKNESS, COLLISION_DEPTH)
	shape.shape = box
	shape.position.y = -LANDING_THICKNESS * 0.5
	surface.add_child(shape)
	return surface


func _on_action_plane(screen_point: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	return origin + direction * (-origin.z / direction.z)


func _wall(wall_name: String) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.collision_layer = PLATFORM_LAYER
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WALL_THICKNESS, WALL_SPAN.y - WALL_SPAN.x, COLLISION_DEPTH)
	shape.shape = box
	shape.position.y = (WALL_SPAN.x + WALL_SPAN.y) * 0.5
	wall.add_child(shape)
	return wall


func _rejected(code: String) -> Dictionary:
	return { "accepted": false, "code": code, "message": "Lobby input was not accepted" }
