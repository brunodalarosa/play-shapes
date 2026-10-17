class_name LobbyMovementTuning
extends Resource
## Playground lobby movement, in character heights. One height is one plaza world unit.
## Changes apply when the lobby next opens.

## Horizontal top speed, heights per second. Higher crosses the plaza sooner; lower gives finer
## placement. Default: 3.44. Safe range: 1-8.
@export_range(1.0, 8.0, 0.01, "suffix:H/s") var move_speed: float = 3.44:
	set(value):
		move_speed = clampf(value, 1.0, 8.0)
## Horizontal acceleration on ground and in air, heights per second squared. Higher feels snappier;
## lower feels floatier. Default: 19.8. Safe range: 4-60.
@export_range(4.0, 60.0, 0.1, "suffix:H/s²") var acceleration: float = 19.8:
	set(value):
		acceleration = clampf(value, 4.0, 60.0)
## Downward acceleration, heights per second squared. Higher makes jumps shorter and snappier;
## lower makes them hang. Default: 14.06. Safe range: 4-40.
@export_range(4.0, 40.0, 0.01, "suffix:H/s²") var gravity: float = 14.06:
	set(value):
		gravity = clampf(value, 4.0, 40.0)
## Height of a standing jump's apex above its start, in heights. The café roof is 3.2 above a
## tabletop. Higher reaches more; lower may strand the roof. Default: 4. Safe range: 1-8.
@export_range(1.0, 8.0, 0.05, "suffix:H") var jump_height: float = 4.0:
	set(value):
		jump_height = clampf(value, 1.0, 8.0)


func jump_impulse() -> float:
	return sqrt(2.0 * gravity * jump_height)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if acceleration < move_speed:
		errors.append("Lobby movement: acceleration must reach top speed within one second.")
	return errors
