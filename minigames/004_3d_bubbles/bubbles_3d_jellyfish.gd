class_name Bubbles3DJellyfish
extends Area3D
## One free jellyfish on the gameplay plane: a sensor that watches for bubbles, wandering slowly.
## Its look lives in the arena's shared swarm; host timestamps decide when it can be caught.

const TURN_INTERVAL_MSEC := 1600
const BLINK_INTERVAL_MSEC := 120

var creature_id := 0
var released := false
var radius := 0.14
var velocity := Vector2.ZERO
var spawned_at_msec := 0
var collectible_at_msec := 0
var _next_turn_msec := 0
var _sphere := SphereShape3D.new()


func _init() -> void:
	monitorable = false
	var shape := CollisionShape3D.new()
	shape.shape = _sphere
	add_child(shape)


func configure(
	id: int,
	tuning: Bubbles3DTuning,
	at_msec: int,
	at: Vector2,
	movement: Vector2,
	watched_layers: int,
	own_layer: int,
	from_pop := false,
	release_lockout_msec := 0,
) -> void:
	creature_id = id
	released = from_pop
	radius = tuning.jellyfish_collider_radius
	_sphere.radius = radius
	collision_layer = own_layer
	collision_mask = watched_layers
	spawned_at_msec = at_msec
	var entrance_msec := roundi(tuning.jellyfish_entrance_seconds * 1000.0)
	collectible_at_msec = at_msec + (maxi(1, release_lockout_msec) if from_pop else entrance_msec)
	_next_turn_msec = at_msec + TURN_INTERVAL_MSEC
	position = PlaneLock3D.on_plane(at)
	var heading := movement.normalized() if movement != Vector2.ZERO else Vector2.ZERO
	velocity = heading * tuning.jellyfish_speed


func simulate_step(delta: float, host_time_msec: int, random_unit: float = 0.5) -> void:
	if host_time_msec >= _next_turn_msec:
		velocity = velocity.rotated((clampf(random_unit, 0.0, 1.0) - 0.5) * PI / 3.0)
		_next_turn_msec = host_time_msec + TURN_INTERVAL_MSEC
	position += Vector3(velocity.x, velocity.y, 0.0) * delta


func needs_turn(host_time_msec: int) -> bool:
	return host_time_msec >= _next_turn_msec


func is_collectible(host_time_msec: int) -> bool:
	return host_time_msec >= collectible_at_msec and host_time_msec >= spawned_at_msec


func plane_position() -> Vector2:
	return PlaneLock3D.plane_point(position)


func is_outside(area: Rect2) -> bool:
	return not area.grow(radius + 0.3).has_point(plane_position())


## Drawn size from 0 to 1: a fresh jellyfish grows in from the background.
func entrance_scale(host_time_msec: int) -> float:
	if released or collectible_at_msec <= spawned_at_msec:
		return 1.0
	var span := float(collectible_at_msec - spawned_at_msec)
	return 0.15 + 0.85 * clampf(float(host_time_msec - spawned_at_msec) / span, 0.0, 1.0)


## Scattered jellyfishes blink white until they can be caught again.
func flashes_white(host_time_msec: int) -> bool:
	return (
		released and not is_collectible(host_time_msec)
		and (host_time_msec / BLINK_INTERVAL_MSEC) % 2 == 0
	)
