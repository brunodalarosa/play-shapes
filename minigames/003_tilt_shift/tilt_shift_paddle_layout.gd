class_name TiltShiftPaddleLayout
extends Resource
## One selected layout stays fixed for the entire shift.

## Name used by validation output and the future workshop.
@export var preset_name: String = "Paddle layout"
## Arena dimensions in width units, independent of the host viewport. Default: 1 by 0.5625.
@export var arena_size: Vector2 = Vector2(1.0, 0.5625)
## Exactly ten stable anchors, five per team. Closeness is a diagnostic, not an error.
@export var paddles: Array[TiltShiftPaddle] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not arena_size.is_finite() or arena_size.x <= 0.0 or arena_size.y <= 0.0:
		errors.append("%s: arena dimensions must be finite and positive." % preset_name)
	if paddles.size() != 10:
		errors.append("%s: provide exactly ten paddles." % preset_name)
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
	if counts != [5, 5]:
		errors.append("%s: assign five paddles to each team." % preset_name)
	return errors
