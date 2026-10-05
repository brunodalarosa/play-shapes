class_name TiltShiftTuning
extends Resource
## Provisional rules/content profile. The owner tunes duration and control separation.

@export_group("Shift rules")
## Scoring window in seconds. Higher gives more time; lower shortens each round. Default: 45.
## Safe range: 1-300. At the deadline, catches are rejected without a settling period.
@export_range(1.0, 300.0, 0.25, "suffix:s")
var round_duration_seconds: float = 45.0:
	set(value):
		round_duration_seconds = clampf(value, 1.0, 300.0)
## Rounds in one shift. Higher lengthens play. Default: 4. Safe range: 1-24.
## Change the basket mapping with this value; missing and surplus entries are invalid.
@export_range(1, 24, 1) var round_count: int = 4:
	set(value):
		round_count = clampi(value, 1, 24)
## Center distance defining neighbors in every direction, in arena-width units. Default: 0.24.
## Safe range: 0.01-2. Higher requests wider separation; this does not measure collider overlap.
@export_range(0.01, 2.0, 0.01) var neighbor_distance: float = 0.24:
	set(value):
		neighbor_distance = clampf(value, 0.01, 2.0)

@export_group("Selected content")
## One ten-paddle layout for the entire shift. Positions and teams stay fixed between rounds.
@export
var paddle_layout: TiltShiftPaddleLayout
## Array entry zero selects round one. Exactly round_count valid mirrored presets are required.
@export var baskets_by_round: Array[TiltShiftBasketPreset] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(round_duration_seconds) or not is_finite(neighbor_distance):
		errors.append("Tilt Shift: duration and neighbor distance must be finite.")
	if paddle_layout == null:
		errors.append("Tilt Shift: select a paddle layout.")
	else:
		errors.append_array(paddle_layout.validation_errors())
	if baskets_by_round.size() != round_count:
		errors.append(
			"Tilt Shift: map exactly %d rounds; found %d basket entries."
			% [round_count, baskets_by_round.size()]
		)
	for index: int in baskets_by_round.size():
		var basket := baskets_by_round[index]
		if basket == null:
			errors.append("Tilt Shift round %d: select a basket preset." % (index + 1))
			continue
		for error: String in basket.validation_errors():
			errors.append("Tilt Shift round %d: %s" % [index + 1, error])
		if (
			paddle_layout != null
			and absf(basket.arena_width - paddle_layout.arena_size.x) \
					> TiltShiftBasketPreset.REFLECTION_TOLERANCE
		):
			errors.append(
				"Tilt Shift round %d: basket floor width must match paddle arena width."
				% (index + 1)
			)
	return errors
