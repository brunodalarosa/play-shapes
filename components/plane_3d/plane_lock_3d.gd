class_name PlaneLock3D
extends RefCounted
## Keeps 3D bodies on one vertical gameplay plane at depth zero: the depth axis and every
## rotation axis are locked, so contacts can only push a body along X and Y.


## Locks [param body] to the plane and moves it onto depth zero.
static func lock(body: PhysicsBody3D) -> void:
	body.axis_lock_linear_z = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true
	body.position.z = 0.0
	if body is RigidBody3D:
		(body as RigidBody3D).gravity_scale = 0.0


## The point of the plane at [param point], for movers that are not physics bodies.
static func on_plane(point: Vector2) -> Vector3:
	return Vector3(point.x, point.y, 0.0)


## The plane coordinates of a 3D position, dropping its depth.
static func plane_point(position: Vector3) -> Vector2:
	return Vector2(position.x, position.y)


## True when [param body] is at depth zero with no rotation, within [param tolerance].
static func is_on_plane(body: Node3D, tolerance := 0.001) -> bool:
	var basis := body.global_transform.basis.orthonormalized()
	return (absf(body.global_position.z) <= tolerance and basis.is_equal_approx(Basis.IDENTITY))
