@tool
class_name TiltShift3DTuning
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
@export var flow: TiltShift3DFlowTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Flow.tres"
)
## Selected calibrated phone control profile. Frozen by the motion consumer at preparation.
@export var motion: TiltShift3DMotionTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Motion.tres"
)
## Selected arena physics and delivery profile, frozen with the rules at launch.
@export var physics: TiltShift3DPhysicsTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Physics.tres"
)
## Compatibility layout for profiles without a numbered layout map.
@export var paddle_layout: TiltShift3DPaddleLayout
## Array entry zero selects round one. Empty maps load older single-layout profiles.
@export var layouts_by_round: Array[TiltShift3DPaddleLayout] = []
## Factory settings frozen with gameplay and editable in the workshop.
@export var presentation: TiltShift3DPresentationTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Presentation.tres"
)
## When paddle faces change and which face each moment shows.
@export var expressions: TiltShift3DExpressionTuning = preload(
	"res://minigames/005_3d_tilt_shift/tuning/Expressions.tres"
)
## Array entry zero selects round one. Exactly round_count valid mirrored presets are required.
@export var baskets_by_round: Array[TiltShift3DBasketPreset] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if presentation == null:
		errors.append("Tilt Shift 3D: select a presentation profile.")
	else:
		errors.append_array(presentation.validation_errors())
	if expressions == null:
		errors.append("Tilt Shift 3D: select an expression profile.")
	else:
		errors.append_array(expressions.validation_errors())
	if not layouts_by_round.is_empty():
		if layouts_by_round.size() != round_count:
			errors.append("Tilt Shift 3D: map exactly one paddle layout per round.")
		var identities: Dictionary[String, TiltShift3DPaddleLayout] = { }
		for layout: TiltShift3DPaddleLayout in layouts_by_round:
			if layout == null:
				errors.append("Tilt Shift 3D: replace a missing round layout.")
				continue
			errors.append_array(layout.validation_errors())
			if identities.has(layout.layout_id) and identities[layout.layout_id] != layout:
				errors.append("Tilt Shift 3D: distinct layouts need distinct exposure identities.")
			identities[layout.layout_id] = layout
	if flow == null:
		errors.append("Tilt Shift 3D: select a flow profile.")
	else:
		errors.append_array(flow.validation_errors())
	if motion == null:
		errors.append("Tilt Shift 3D: select a motion control profile.")
	else:
		errors.append_array(motion.validation_errors())
	if not is_finite(round_duration_seconds) or not is_finite(neighbor_distance):
		errors.append("Tilt Shift 3D: duration and neighbor distance must be finite.")
	if physics == null:
		errors.append("Tilt Shift 3D: select a physics and delivery profile.")
	else:
		errors.append_array(physics.validation_errors())
		if errors.is_empty():
			var duration := roundi(
				(round_duration_seconds - physics.delivery_cutoff_seconds) * 1000.0
			)
			var deliveries := TiltShift3DDelivery.schedule(
				physics.ball_count,
				physics.delivery_curve,
				duration,
			)
			if deliveries.size() != physics.ball_count:
				errors.append(
					"Tilt Shift 3D delivery: curve cannot fit deliveries before the deadline."
				)
			var negative := TiltShift3DDelivery.schedule(
				physics.negative_ball_count,
				physics.negative_delivery_curve,
				roundi(round_duration_seconds * 1000.0),
				true,
			)
			if negative.size() != physics.negative_ball_count:
				errors.append(
					"Tilt Shift 3D negative delivery: curve cannot fit before the deadline."
				)
		for index: int in round_count:
			var layout := layout_for(index)
			if layout != null and layout.arena_size.is_finite():
				var half_width := layout.arena_size.x * 0.5
				if physics.spawn_half_width + physics.ball_radius > half_width:
					errors.append(
						"Tilt Shift 3D delivery: symmetric spawn bounds must clear both walls."
					)
				for team: int in 3:
					var thickness := layout.paddle_size(team, physics).y
					if thickness * physics.depth_ratio <= physics.ball_radius * 2.0:
						errors.append(
							"Tilt Shift 3D %s: paddle depth must exceed the ball's diameter."
							% layout.preset_name
						)
						break
	if paddle_layout == null and layouts_by_round.is_empty():
		errors.append("Tilt Shift 3D: select a paddle layout.")
	elif layouts_by_round.is_empty():
		errors.append_array(paddle_layout.validation_errors())
	if baskets_by_round.size() != round_count:
		errors.append(
			"Tilt Shift 3D: map exactly %d rounds; found %d basket entries."
			% [round_count, baskets_by_round.size()]
		)
	for index: int in baskets_by_round.size():
		var basket := baskets_by_round[index]
		if basket == null:
			errors.append("Tilt Shift 3D round %d: select a basket preset." % (index + 1))
			continue
		for error: String in basket.validation_errors():
			errors.append("Tilt Shift 3D round %d: %s" % [index + 1, error])
		var layout := layout_for(index)
		if (
			layout != null
			and absf(basket.arena_width - layout.arena_size.x) \
					> TiltShift3DBasketPreset.REFLECTION_TOLERANCE
		):
			errors.append(
				"Tilt Shift 3D round %d: basket floor width must match paddle arena width."
				% (index + 1)
			)
	return errors


func layout_for(index: int) -> TiltShift3DPaddleLayout:
	if layouts_by_round.is_empty():
		return paddle_layout
	return layouts_by_round[index] if index >= 0 and index < layouts_by_round.size() else null
