@tool
class_name TiltShift3DPhysicsTuning
extends Resource
## Arena-local physics and delivery. Both axes use the layout's arena-width unit; the arena
## multiplies them by its world width.

@export_group("Delivery")
## Positive balls per round, independent of curve shape. Default: 60. Range: 0-1000.
@export_range(0, 1000, 1)
var ball_count: int = 60
## Piecewise-linear (progress, relative intensity) points. Default: constant one.
## Progress must increase from zero to one; intensity is finite and nonnegative.
@export var delivery_curve: PackedVector2Array = PackedVector2Array([Vector2(0, 1), Vector2(1, 1)])
## Negative balls per round, independent of curve shape. Default: 20. Range: 0-1000.
@export_range(0, 1000, 1) var negative_ball_count: int = 20
## Negative ball fill tint; the white outline is independent. Default: #176dd1.
@export_color_no_alpha var negative_ball_color: Color = Color("176dd1")
## Smooth progress/intensity points across the full round; zero spans remain empty.
## Default: starts at 20%, rises gently, peaks at 70%, and stops at 90%.
@export var negative_delivery_curve: PackedVector2Array = PackedVector2Array(
	[
		Vector2(0, 0),
		Vector2(0.2, 0),
		Vector2(0.35, 0.15),
		Vector2(0.7, 1),
		Vector2(0.9, 0),
		Vector2(1, 0),
	]
)
## Use the supplied position seed instead of choosing a fresh sequence at shift start.
@export var use_position_seed: bool = false
## Seed affects positions only, never team allocation or physics outcomes. Default: 1.
@export var position_seed: int = 1
## Half-width around the arena center. Default: 0.40 widths. Range: 0-0.49.
## Higher spreads entries; the ball radius must still fit within both walls.
@export_range(0.0, 0.49, 0.01) var spawn_half_width: float = 0.40

## Empty gap beyond the whole ball above the fitted visible top, in arena widths.
@export_range(0.0, 0.5, 0.01) var spawn_height: float = 0.03
## Positive delivery lead time before scoring closes; negative progress uses the full round.
@export_range(0.0, 300.0, 0.5) var delivery_cutoff_seconds: float = 0.0

@export_group("Geometry and motion")
## Shared circular ball radius. Default: 0.01587 widths. Range: 0.003-0.02.
@export_range(0.003, 0.02, 0.00001)
var ball_radius: float = 0.01587
## Paddle length. Default: 0.10 widths. Range: 0.02-0.20.
@export_range(0.02, 0.20, 0.005) var paddle_length: float = 0.10
## Paddle thickness for layouts that do not set their own. Default: 0.04 widths.
## Range: 0.006-0.1. The face is drawn at a share of it, so thinner paddles shrink the face.
@export_range(0.006, 0.1, 0.001) var paddle_thickness: float = 0.04
## Corner radius as a share of the paddle's thickness. Default: 0.35. Range: 0-0.5.
## The radius never follows the length, so the rounded ends keep their shape.
@export_range(0.0, 0.5, 0.01) var corner_radius_ratio: float = 0.35
## Paddle depth, front to back, as a share of its thickness. Default: 1. Range: 0.5-3.
## The depth must exceed the ball's diameter, so a ball cannot pass a paddle's edge.
@export_range(0.5, 3.0, 0.05) var depth_ratio: float = 1.0
## Height of the bin band under the floor and the bin mouths. Default: 0.07 widths.
## Range: 0-0.2. The floor sits this far above the arena's bottom edge.
@export_range(0.0, 0.2, 0.0025) var bin_band: float = 0.07
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
	for channel: float in [negative_ball_color.r, negative_ball_color.g, negative_ball_color.b]:
		_check_range(errors, channel, 0.0, 1.0, "Negative ball color")
	if not is_equal_approx(negative_ball_color.a, 1.0):
		errors.append("Tilt Shift 3D physics: negative ball color must be opaque.")
	_check_range(errors, spawn_height, 0.0, 0.5, "Spawn height")
	_check_range(errors, delivery_cutoff_seconds, 0.0, 300.0, "Delivery cutoff")
	_check_range(errors, spawn_half_width, 0.0, 0.49, "Spawn half width")
	_check_range(errors, ball_radius, 0.003, 0.02, "Ball radius")
	_check_range(errors, paddle_length, 0.02, 0.20, "Paddle length")
	_check_range(errors, paddle_thickness, 0.006, 0.1, "Paddle thickness")
	_check_range(errors, corner_radius_ratio, 0.0, 0.5, "Corner radius ratio")
	_check_range(errors, depth_ratio, 0.5, 3.0, "Depth ratio")
	_check_range(errors, bin_band, 0.0, 0.2, "Bin band")
	_check_range(errors, gravity, 0.0, 2.0, "Gravity")
	_check_range(errors, entry_speed, 0.0, 1.0, "Entry speed")
	_check_range(errors, rotation_speed_degrees, 1.0, 180.0, "Rotation speed")
	_check_range(errors, ball_friction, 0.0, 1.0, "Ball friction")
	_check_range(errors, paddle_friction, 0.0, 1.0, "Paddle friction")
	_check_range(errors, ball_bounce, 0.0, 1.0, "Ball restitution")
	_check_range(errors, paddle_bounce, 0.0, 1.0, "Paddle restitution")
	_validate_delivery(errors, ball_count, delivery_curve, "positive")
	_validate_delivery(errors, negative_ball_count, negative_delivery_curve, "negative")
	return errors


func _validate_delivery(
	errors: PackedStringArray,
	count: int,
	points: PackedVector2Array,
	kind: String,
) -> void:
	var prefix := "Tilt Shift 3D %s delivery: " % kind
	if count < 0 or count > 1000:
		errors.append(prefix + "ball count must be between 0 and 1000.")
	if points.size() < 2 or points.size() > 64:
		errors.append(prefix + "provide 2-64 intensity points.")
		return
	if points[0].x != 0.0 or points[-1].x != 1.0:
		errors.append(prefix + "progress must start at zero and end at one.")
	var previous := -1.0
	for point: Vector2 in points:
		if not point.is_finite() or point.x <= previous or point.x > 1.0 or point.y < 0:
			errors.append(prefix + "increasing progress and nonnegative intensity required.")
			break
		previous = point.x
	if count > 0 and TiltShift3DDelivery.total_weight(points) <= 0.0:
		errors.append(prefix + "positive ball count requires positive curve weight.")


func _check_range(
	errors: PackedStringArray,
	value: float,
	minimum: float,
	maximum: float,
	label: String,
) -> void:
	if not is_finite(value) or value < minimum or value > maximum:
		errors.append(
			"Tilt Shift 3D physics: %s must be finite and between %s and %s."
			% [label, minimum, maximum]
		)
