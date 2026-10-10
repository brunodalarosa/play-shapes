@tool
class_name TiltShiftPaddle
extends Resource
## One fixed paddle anchor, in arena-width units on both axes.

## Stable identity, independent of array order and player assignment.
@export var paddle_id: String = ""
## Team owning this anchor. The third enum value denotes a neutral rotating paddle.
@export var team: TiltShiftTypes.Team = TiltShiftTypes.Team.ORANGE
## Anchor measured from the arena's top-left. Both axes use arena-width units.
@export var position: Vector2 = Vector2.ZERO


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if paddle_id.is_empty():
		errors.append("Paddle: assign a nonempty stable ID.")
	if team not in [0, 1, 2]:
		errors.append("Paddle %s: select Orange, Blue or neutral." % paddle_id)
	if not position.is_finite():
		errors.append("Paddle %s: position must be finite." % paddle_id)
	return errors
