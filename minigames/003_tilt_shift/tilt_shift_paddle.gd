@tool
class_name TiltShiftPaddle
extends Resource
## One fixed paddle anchor, in arena-width units on both axes.

## Stable identity, independent of array order and player assignment.
@export var paddle_id: String = ""
## Team owning this paddle throughout a shift. Trash is not a paddle team.
@export var team: TiltShiftTypes.Team = TiltShiftTypes.Team.ORANGE
## Anchor measured from the arena's top-left. Both axes use arena-width units.
@export var position: Vector2 = Vector2.ZERO


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if paddle_id.is_empty():
		errors.append("Paddle: assign a nonempty stable ID.")
	if not TiltShiftTypes.is_player_team(team):
		errors.append("Paddle %s: select Orange or Blue, not trash." % paddle_id)
	if not position.is_finite():
		errors.append("Paddle %s: position must be finite." % paddle_id)
	return errors
