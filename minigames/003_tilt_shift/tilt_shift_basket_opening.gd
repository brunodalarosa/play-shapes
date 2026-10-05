class_name TiltShiftBasketOpening
extends Resource
## A floor opening. Physics reports its ID; only the rules controller awards points.

## Stable opening identity within a basket preset.
@export var basket_id: String = ""
## One point for the selected team, or no point for trash.
@export var team: TiltShiftTypes.Team = TiltShiftTypes.Team.TRASH
## Horizontal center in arena-width units. Default: 0.5.
@export var center: float = 0.5
## Opening width in arena-width units. Must be positive. Default: 0.12.
@export var width: float = 0.12


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if basket_id.is_empty():
		errors.append("Basket: assign a nonempty stable ID.")
	if team < TiltShiftTypes.Team.ORANGE or team > TiltShiftTypes.Team.TRASH:
		errors.append("Basket %s: select Orange, Blue or trash." % basket_id)
	if not is_finite(center) or not is_finite(width) or width <= 0.0:
		errors.append("Basket %s: center and positive width must be finite." % basket_id)
	return errors
