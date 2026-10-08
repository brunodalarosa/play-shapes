@tool
class_name TiltShiftPhysicsTuning
extends Resource
## Arena-local physics and delivery. Both axes use the layout's arena-width unit.

@export_group("Delivery")
## Balls per round, independent of curve shape. Default: 60. Range: 0-1000.
@export_range(0, 1000, 1)
var ball_count: int = 60
## Piecewise-linear (progress, relative intensity) points. Default: constant one.
## Progress must increase from zero to one; intensity is finite and nonnegative.
@export var delivery_curve: PackedVector2Array = PackedVector2Array([Vector2(0, 1), Vector2(1, 1)])
## Use the supplied position seed instead of choosing a fresh sequence at shift start.
@export var use_position_seed: bool = false
## Seed affects positions only, never team allocation or physics outcomes. Default: 1.
@export var position_seed: int = 1
## Half-width around the arena center. Default: 0.40 widths. Range: 0-0.49.
## Higher spreads entries; the ball radius must still fit within both walls.
@export_range(0.0, 0.49, 0.01) var spawn_half_width: float = 0.40

## Empty gap beyond the whole ball above the fitted visible top, in arena widths.
@export_range(0.0, 0.5, 0.01) var spawn_height: float = 0.03
## Lead time before scoring closes; the full ball budget uses the shortened window.
@export_range(0.0, 300.0, 0.5) var delivery_cutoff_seconds: float = 0.0

@export_group("Geometry and motion")
## Circular ball radius. Default: 0.012 widths. Range: 0.003-0.02.
@export_range(0.003, 0.02, 0.001)
var ball_radius: float = 0.012
## Paddle length. Default: 0.10 widths. Range: 0.02-0.20.
@export_range(0.02, 0.20, 0.005) var paddle_length: float = 0.10
## Paddle thickness. Default: 0.01 widths. Range: 0.006-0.03.
@export_range(0.006, 0.03, 0.001) var paddle_thickness: float = 0.01
## Downward acceleration. Default: 0.18 widths/s². Range: 0-2.
## Higher accelerates free fall; this never changes the project's gravity.
@export_range(0.0, 2.0, 0.01) var gravity: float = 0.18
## Initial downward speed, separate from acceleration. Default: 0.05 widths/s. Range: 0-1.
@export_range(0.0, 1.0, 0.01) var entry_speed: float = 0.05
## Maximum physical rotation speed. Default: 180 degrees/s. Range: 1-180.
## Unwrapped targets retain full turns; the actual pose approaches them without teleporting.
@export_range(1.0, 180.0, 1.0) var rotation_speed_degrees: float = 180.0

@export_group("Contact materials")
## Ball friction. Default: 0.2. Range: 0-1; lower permits more sliding.
@export_range(0.0, 1.0, 0.05)
var ball_friction: float = 0.2
## Paddle friction. Default: 0.4. Range: 0-1; lower permits more sliding.
## Rough paddles select the greater of both contacting friction values.
@export_range(0.0, 1.0, 0.05) var paddle_friction: float = 0.4
## Ball restitution. Default: 0.0. Range: 0-1; higher adds material rebound.
@export_range(0.0, 1.0, 0.05) var ball_bounce: float = 0.0
## Paddle restitution. Default: 0.0. Range: 0-1; both materials contribute rebound.
## Zero on both suppresses material rebound; a moving paddle can still push a ball.
@export_range(0.0, 1.0, 0.05) var paddle_bounce: float = 0.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_check_range(errors, spawn_height, 0.0, 0.5, "Spawn height")
	_check_range(errors, delivery_cutoff_seconds, 0.0, 300.0, "Delivery cutoff")
	_check_range(errors, spawn_half_width, 0.0, 0.49, "Spawn half width")
	_check_range(errors, ball_radius, 0.003, 0.02, "Ball radius")
	_check_range(errors, paddle_length, 0.02, 0.20, "Paddle length")
	_check_range(errors, paddle_thickness, 0.006, 0.03, "Paddle thickness")
	_check_range(errors, gravity, 0.0, 2.0, "Gravity")
	_check_range(errors, entry_speed, 0.0, 1.0, "Entry speed")
	_check_range(errors, rotation_speed_degrees, 1.0, 180.0, "Rotation speed")
	_check_range(errors, ball_friction, 0.0, 1.0, "Ball friction")
	_check_range(errors, paddle_friction, 0.0, 1.0, "Paddle friction")
	_check_range(errors, ball_bounce, 0.0, 1.0, "Ball restitution")
	_check_range(errors, paddle_bounce, 0.0, 1.0, "Paddle restitution")
	if ball_count < 0 or ball_count > 1000:
		errors.append("Tilt Shift delivery: ball count must be between 0 and 1000.")
	if delivery_curve.size() < 2 or delivery_curve.size() > 64:
		errors.append("Tilt Shift delivery: provide 2-64 intensity points.")
		return errors
	if delivery_curve[0].x != 0.0 or delivery_curve[-1].x != 1.0:
		errors.append("Tilt Shift delivery: progress must start at zero and end at one.")
	var previous := -1.0
	for point: Vector2 in delivery_curve:
		if not point.is_finite() or point.x <= previous or point.x > 1.0 or point.y < 0:
			errors.append(
				"Tilt Shift delivery: increasing progress and nonnegative intensity required."
			)
			break
		previous = point.x
	if ball_count > 0 and TiltShiftDelivery.total_weight(delivery_curve) <= 0.0:
		errors.append("Tilt Shift delivery: positive ball count requires positive curve weight.")
	return errors


func _check_range(
	errors: PackedStringArray,
	value: float,
	minimum: float,
	maximum: float,
	label: String,
) -> void:
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append(
			"Tilt Shift physics: %s must be finite and between %s and %s."
			% [label, minimum, maximum]
		)
