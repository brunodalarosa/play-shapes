class_name MotionOrientation
extends RefCounted
## W3C intrinsic Z-X'-Y'' device rotation -> Godot Y-up. No gyro integration.


static func device_basis(angles: Array) -> Basis:
	var raw := Basis(Vector3.BACK, deg_to_rad(float(angles[0]))) * Basis(
		Vector3.RIGHT,
		deg_to_rad(float(angles[1])),
	) * Basis(Vector3.UP, deg_to_rad(float(angles[2])))
	return Basis(Vector3.RIGHT, -PI / 2.0) * raw


static func screen_basis(angles: Array, screen_angle: float) -> Basis:
	return device_basis(angles) * Basis(Vector3.BACK, -deg_to_rad(screen_angle))


static func physical_basis(angles: Array, screen_angle: float) -> Basis:
	# Undo screen-axis compensation for a portrait-shaped physical phone model.
	# Otherwise autorotating UI would spuriously rotate the hardware slab.
	return screen_basis(angles, screen_angle) * Basis(Vector3.BACK, deg_to_rad(screen_angle))
