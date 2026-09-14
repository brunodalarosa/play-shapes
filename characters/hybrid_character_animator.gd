class_name HybridCharacterAnimator
extends Node
## Lab-only hybrid motion: authored part targets plus restrained procedural bounce.

@export_range(0.1, 3.0, 0.05) var dance_beats_per_second: float = 1.7
@export_range(0.0, 16.0, 0.5) var body_bounce: float = 6.0
@export_range(0.0, 12.0, 0.5) var body_jiggle_degrees: float = 4.0
@export_range(0.0, 16.0, 0.5) var body_sway: float = 7.0
@export_range(1.0, 30.0, 0.5) var visual_follow_speed: float = 12.0

const HANDS: Dictionary = {
	&"closed": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_closed.png"),
	&"open": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_open.png"),
	&"peace": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_peace.png"),
	&"point": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_point.png"),
	&"rock": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_rock.png"),
	&"thumb": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_thumb.png"),
}
# Open and closed dominate; accent silhouettes remain occasional punctuation.
const DANCE_HANDS: Array[StringName] = [
	&"closed", &"open", &"closed", &"open", &"peace", &"open", &"closed",
	&"point", &"open", &"closed", &"rock", &"open", &"closed", &"thumb"
]

var charge_state: PoseCharge
var _character: ShapeCharacter
var _dance_time: float = 0.0
var _visual_charge: float = 0.0
var _parts: Dictionary = {}
var _base: Dictionary = {}
var _expression := CharacterExpression.new()
var _jiggle_random := RandomNumberGenerator.new()
var _jiggle_clock: float = 0.0
var _jiggle_speed: float = 1.0
var _jiggle_mode_left: float = 0.0
var _slow_jiggle: bool = false

func setup(character: ShapeCharacter, state: PoseCharge) -> void:
	_character = character
	charge_state = state
	for part_name: StringName in [&"Body", &"Face", &"LeftHand", &"RightHand", &"LeftFoot", &"RightFoot"]:
		var part := _character.get_node(NodePath(part_name)) as Sprite2D
		_parts[part_name] = part
		_base[part_name] = _transform(part.position, part.rotation_degrees, part.scale)
	set_jiggle_seed(-1)

func _process(delta: float) -> void:
	if _character == null or charge_state == null:
		return
	if not charge_state.is_committed():
		_dance_time += delta
		_update_jiggle_pattern(delta)
	var target_charge := charge_state.charge
	_visual_charge = move_toward(_visual_charge, target_charge, visual_follow_speed * delta)
	var dance := _dance_targets(_dance_time)
	var pose := _pose_targets(charge_state.direction)
	var blend := smoothstep(0.0, 1.0, _visual_charge)
	for part_name: StringName in _parts:
		var part: Sprite2D = _parts[part_name]
		var target: Dictionary = _mix_transform(dance[part_name], pose[part_name], blend)
		part.position = target.position
		part.rotation_degrees = target.rotation
		part.scale = target.scale
	_update_living_details(delta)

func _update_living_details(delta: float) -> void:
	var committed := charge_state.is_committed()
	var face: Sprite2D = _parts[&"Face"]
	if committed:
		face.texture = CharacterExpression.FACES[_pose_face(charge_state.direction)]
	else:
		face.texture = _expression.advance(delta)

	var hand_shape := _pose_hand_shape(charge_state.direction) if charge_state.charge > 0.15 else &""
	if hand_shape.is_empty():
		# One change every five beats is an 80% reduction from the first prototype.
		var shapes := dance_hand_shapes_at(_dance_time)
		_set_hands(shapes[0], shapes[1])
	elif charge_state.direction == &"left":
		_set_hands(&"open", &"peace")
	elif charge_state.direction == &"down":
		_set_hands(&"thumb", &"open")
	else:
		_set_hands(hand_shape, hand_shape)

func _set_hands(left_shape: StringName, right_shape: StringName) -> void:
	(_parts[&"LeftHand"] as Sprite2D).texture = HANDS[left_shape]
	(_parts[&"RightHand"] as Sprite2D).texture = HANDS[right_shape]

func _pose_hand_shape(direction: StringName) -> StringName:
	match direction:
		&"up":
			return &"rock"
		&"right":
			return &"open"
		&"left":
			return &"open"
		&"down":
			return &"thumb"
	return &""

func _pose_face(direction: StringName) -> StringName:
	match direction:
		&"up", &"left":
			return &"delighted"
		&"right":
			return &"cheeky"
		&"down":
			return &"blink"
	return &"neutral"

func set_expression_seed(seed: int) -> void:
	_expression.reset(seed)

func expression_tag() -> StringName:
	return _expression.current_tag()

func dance_hand_shapes_at(time: float) -> Array[StringName]:
	var beat := floori(time * dance_beats_per_second / 5.0)
	return [DANCE_HANDS[posmod(beat, DANCE_HANDS.size())], DANCE_HANDS[posmod(beat + 2, DANCE_HANDS.size())]]

func set_jiggle_seed(seed: int) -> void:
	if seed < 0:
		_jiggle_random.randomize()
	else:
		_jiggle_random.seed = seed
	_slow_jiggle = false
	_jiggle_speed = 1.0
	_jiggle_mode_left = _jiggle_random.randf_range(6.0, 11.0)

func jiggle_is_slow() -> bool:
	return _slow_jiggle

func _update_jiggle_pattern(delta: float) -> void:
	_jiggle_mode_left -= delta
	if _jiggle_mode_left <= 0.0:
		_slow_jiggle = not _slow_jiggle
		_jiggle_mode_left = _jiggle_random.randf_range(1.8, 3.2) if _slow_jiggle else _jiggle_random.randf_range(6.0, 11.0)
	var target_speed := 0.42 if _slow_jiggle else 1.0
	_jiggle_speed = move_toward(_jiggle_speed, target_speed, delta * 1.4)
	_jiggle_clock += delta * _jiggle_speed

func _dance_targets(time: float) -> Dictionary:
	var beat_position := fmod(time * dance_beats_per_second, 4.0)
	var beat_index := floori(beat_position)
	var beat_blend := smoothstep(0.0, 1.0, beat_position - beat_index)
	var result := _mix_targets(_dance_pose(beat_index), _dance_pose((beat_index + 1) % 4), beat_blend)

	# Secondary motion supports the authored limb choreography without defining it.
	var pulse := sin(_jiggle_clock * dance_beats_per_second * TAU)
	var lift := (sin(_jiggle_clock * dance_beats_per_second * TAU * 2.0 - PI * 0.5) + 1.0) * 0.5
	var sway := sin(_jiggle_clock * dance_beats_per_second * TAU * 0.5 + 0.7) * body_sway
	result[&"Body"] = _transform(Vector2(sway, -body_bounce * lift), body_jiggle_degrees * pulse, Vector2(0.5 + 0.025 * lift, 0.5 - 0.02 * lift))
	result[&"Face"] = _transform(Vector2(sway, -body_bounce * lift), body_jiggle_degrees * pulse, Vector2.ONE * 0.5)
	return result

func _dance_pose(index: int) -> Dictionary:
	var result := _copy_base()
	match index:
		0:
			result[&"LeftHand"] = _transform(Vector2(-66, -16), -38, Vector2.ONE * 0.5)
			result[&"RightHand"] = _transform(Vector2(53, 30), 24, Vector2.ONE * 0.5)
			result[&"LeftFoot"] = _transform(Vector2(-30, 55), -12, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(21, 62), 4, Vector2.ONE * 0.5)
		1:
			result[&"LeftHand"] = _transform(Vector2(-52, 28), -12, Vector2.ONE * 0.5)
			result[&"RightHand"] = _transform(Vector2(68, -22), 42, Vector2.ONE * 0.5)
			result[&"LeftFoot"] = _transform(Vector2(-21, 62), -4, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(31, 54), 13, Vector2.ONE * 0.5)
		2:
			result[&"LeftHand"] = _transform(Vector2(-61, 8), -25, Vector2.ONE * 0.5)
			result[&"RightHand"] = _transform(Vector2(61, 8), 25, Vector2.ONE * 0.5)
			result[&"LeftFoot"] = _transform(Vector2(-32, 60), -8, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(32, 60), 8, Vector2.ONE * 0.5)
		3:
			result[&"LeftHand"] = _transform(Vector2(-70, -25), -44, Vector2.ONE * 0.5)
			result[&"RightHand"] = _transform(Vector2(48, 34), 16, Vector2.ONE * 0.5)
			result[&"LeftFoot"] = _transform(Vector2(-28, 53), -14, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(23, 63), 5, Vector2.ONE * 0.5)
	return result

func _pose_targets(direction: StringName) -> Dictionary:
	var result := _copy_base()
	match direction:
		&"up":
			result[&"LeftHand"] = _transform(Vector2(-40, -72), -28, Vector2.ONE * 0.55)
			result[&"RightHand"] = _transform(Vector2(40, -72), 28, Vector2.ONE * 0.55)
			result[&"LeftFoot"] = _transform(Vector2(-29, 60), -8, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(29, 60), 8, Vector2.ONE * 0.5)
		&"left":
			result[&"Body"] = _transform(Vector2(-5, 0), -8, Vector2(0.52, 0.48))
			result[&"Face"] = _transform(Vector2(-5, -2), -8, Vector2.ONE * 0.5)
			result[&"LeftHand"] = _transform(Vector2(-82, -30), -42, Vector2.ONE * 0.55)
			result[&"RightHand"] = _transform(Vector2(-58, 6), -24, Vector2.ONE * 0.55)
			result[&"LeftFoot"] = _transform(Vector2(-31, 60), -8, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(23, 60), -3, Vector2.ONE * 0.5)
		&"right":
			result[&"Body"] = _transform(Vector2(3, 1), 10, Vector2(0.51, 0.49))
			result[&"Face"] = _transform(Vector2(3, 1), 10, Vector2.ONE * 0.5)
			result[&"LeftHand"] = _transform(Vector2(-67, -55), -28, Vector2.ONE * 0.54)
			result[&"RightHand"] = _transform(Vector2(76, 35), 38, Vector2.ONE * 0.58)
			result[&"LeftFoot"] = _transform(Vector2(-24, 60), -4, Vector2.ONE * 0.5)
			result[&"RightFoot"] = _transform(Vector2(35, 56), 12, Vector2.ONE * 0.5)
		&"down":
			result[&"Body"] = _transform(Vector2(0, 30), -6, Vector2(0.58, 0.39))
			result[&"Face"] = _transform(Vector2(0, 23), -6, Vector2(0.53, 0.44))
			result[&"LeftHand"] = _transform(Vector2(-67, 38), -18, Vector2.ONE * 0.54)
			result[&"RightHand"] = _transform(Vector2(67, 27), 24, Vector2.ONE * 0.54)
			result[&"LeftFoot"] = _transform(Vector2(-43, 72), -16, Vector2.ONE * 0.52)
			result[&"RightFoot"] = _transform(Vector2(43, 72), 16, Vector2.ONE * 0.52)
	return result

func _copy_base() -> Dictionary:
	return _base.duplicate(true)

func _transform(position: Vector2, rotation: float, scale: Vector2) -> Dictionary:
	return {"position": position, "rotation": rotation, "scale": scale}

func _mix_transform(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	return _transform(
		(from.position as Vector2).lerp(to.position as Vector2, weight),
		lerpf(float(from.rotation), float(to.rotation), weight),
		(from.scale as Vector2).lerp(to.scale as Vector2, weight)
	)

func _mix_targets(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	for part_name: StringName in from:
		result[part_name] = _mix_transform(from[part_name], to[part_name], weight)
	return result
