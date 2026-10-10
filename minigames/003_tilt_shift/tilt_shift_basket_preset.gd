@tool
class_name TiltShiftBasketPreset
extends Resource
## Reflection exchanges team colors and preserves trash. No strategic fairness claim.

const REFLECTION_TOLERANCE := 0.00001

## Name included in actionable preset/round errors.
@export var preset_name: String = "Basket preset"
## Floor width, in the same units as the selected paddle layout. Default: 1.
@export var arena_width: float = 1.0
## Configurable number of nonoverlapping, mirrored floor openings.
@export var openings: Array[TiltShiftBasketOpening] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(arena_width) or arena_width <= 0.0:
		errors.append("%s: floor width must be finite and positive." % preset_name)
	if openings.is_empty():
		errors.append("%s: provide basket openings." % preset_name)
	var ids := PackedStringArray()
	for index: int in openings.size():
		var opening := openings[index]
		if opening == null:
			errors.append("%s: replace missing opening %d." % [preset_name, index + 1])
			continue
		for error: String in opening.validation_errors():
			errors.append("%s: %s" % [preset_name, error])
		if ids.has(opening.basket_id):
			errors.append("%s: duplicate basket ID %s." % [preset_name, opening.basket_id])
		ids.append(opening.basket_id)
		if opening.center - opening.width * 0.5 < 0.0 \
				or opening.center + opening.width * 0.5 > arena_width:
			errors.append("%s: basket %s is outside the floor." % [preset_name, opening.basket_id])
		if not _has_reflection(opening):
			var instruction := (
				"needs an equal-width reflected opening " + "of the opposite team or trash."
			)
			errors.append("%s: basket %s %s" % [preset_name, opening.basket_id, instruction])
		for previous: int in index:
			var other := openings[previous]
			if (
				other != null
				and absf(opening.center - other.center) \
						< (opening.width + other.width) * 0.5 - REFLECTION_TOLERANCE
			):
				errors.append(
					"%s: baskets %s and %s overlap."
					% [preset_name, opening.basket_id, other.basket_id]
				)
	return errors


func _has_reflection(opening: TiltShiftBasketOpening) -> bool:
	var reflected_team: int = opening.team
	if TiltShiftTypes.is_player_team(opening.team):
		reflected_team = 1 - opening.team
	for other: TiltShiftBasketOpening in openings:
		if other == null or other.team != reflected_team:
			continue
		if absf(other.center - (arena_width - opening.center)) <= REFLECTION_TOLERANCE \
				and absf(other.width - opening.width) <= REFLECTION_TOLERANCE:
			return true
	return false
