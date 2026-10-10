@tool
class_name TiltShiftPaddleLayout
extends Resource
## Named round geometry; runtime history never mutates this Resource.

## Name used by validation output and the future workshop.
@export var preset_name: String = "Paddle layout"
## Arena dimensions in width units, independent of the host viewport. Default: 1 by 0.5625.
@export var arena_size: Vector2 = Vector2(1.0, 0.5625)
## Stable exposure identity, independent of the editable display name.
@export var layout_id: String = "legacy"
## Player length in arena widths; zero retains legacy physics-profile dimensions.
@export_range(0.0, 0.4, 0.005) var player_length: float = 0.0
## Player thickness in arena widths; zero retains legacy dimensions.
@export_range(0.0, 0.06, 0.001) var player_thickness: float = 0.0
## Independently editable neutral paddle length in arena widths.
@export_range(0.02, 0.4, 0.005) var auto_length: float = 0.20
## Neutral paddle thickness in arena widths.
@export_range(0.006, 0.06, 0.001) var auto_thickness: float = 0.016
## Continuous neutral rotation speed in degrees per second, during active play only.
@export_range(1.0, 180.0, 1.0) var auto_speed_degrees: float = 45.0
## First appearance turns clockwise; later appearances alternate within the playthrough.
@export var auto_clockwise: bool = true
## Equal team counts, one to five each, plus up to four neutral anchors.
@export var paddles: Array[TiltShiftPaddle] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not arena_size.is_finite() or arena_size.x <= 0.0 or arena_size.y <= 0.0:
		errors.append("%s: arena dimensions must be finite and positive." % preset_name)
	if layout_id.is_empty():
		errors.append("%s: provide a stable layout identity." % preset_name)
	var ranges := {
		"player_length": [0.0, 0.4],
		"player_thickness": [0.0, 0.06],
		"auto_length": [0.02, 0.4],
		"auto_thickness": [0.006, 0.06],
		"auto_speed_degrees": [1.0, 180.0],
	}
	for field: String in ranges:
		var value := float(get(field))
		if not is_finite(value) or value < ranges[field][0] or value > ranges[field][1]:
			errors.append("%s: invalid %s." % [preset_name, field])
	var ids := PackedStringArray()
	var counts: Array[int] = [0, 0]
	for paddle: TiltShiftPaddle in paddles:
		if paddle == null:
			errors.append("%s: replace a missing paddle reference." % preset_name)
			continue
		for error: String in paddle.validation_errors():
			errors.append("%s: %s" % [preset_name, error])
		if ids.has(paddle.paddle_id):
			errors.append("%s: duplicate paddle ID %s." % [preset_name, paddle.paddle_id])
		ids.append(paddle.paddle_id)
		if TiltShiftTypes.is_player_team(paddle.team):
			counts[paddle.team] += 1
		var position := paddle.position
		if position.x < 0.0 or position.y < 0.0 or position.x > arena_size.x \
				or position.y > arena_size.y:
			errors.append("%s: paddle %s is outside the arena." % [preset_name, paddle.paddle_id])
	if counts[0] != counts[1] or counts[0] < 1 or counts[0] > 5:
		errors.append("%s: assign equal teams of one to five paddles." % preset_name)
	if paddles.size() - counts[0] - counts[1] > 4:
		errors.append("%s: at most four neutral paddles are supported." % preset_name)
	return errors


func paddle_size(team: int, physics: TiltShiftPhysicsTuning) -> Vector2:
	if team == 2:
		return Vector2(auto_length, auto_thickness)
	return Vector2(
		player_length if player_length > 0 else physics.paddle_length,
		player_thickness if player_thickness > 0 else physics.paddle_thickness,
	)
