class_name HybridCharacterAnimator
extends Node
## Production detached-sprite animation component. Gameplay supplies semantic state only.

const DIRECTIONS: Array[StringName] = [&"up", &"left", &"right", &"down"]
const DANCE_STYLES: Array[StringName] = [&"bounce", &"swing", &"disco"]
const REACTIONS: Array[StringName] = [&"none", &"life_loss", &"survived"]
const RESULT_MOODS: Array[StringName] = [&"none", &"happy", &"moody"]
const PART_NAMES: Array[StringName] = [&"Body", &"Face", &"LeftHand", &"RightHand", &"LeftFoot", &"RightFoot"]
const HANDS: Dictionary = {
	&"closed": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_closed.png"),
	&"open": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_open.png"),
	&"peace": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_peace.png"),
	&"point": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_point.png"),
	&"rock": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_rock.png"),
	&"thumb": preload("res://assets/Kenney_Shape_Characters/PNG/Double/blue_hand_thumb.png"),
}
const DANCE_HANDS: Array[StringName] = [&"closed", &"open", &"closed", &"open", &"peace", &"open", &"closed", &"point", &"open", &"closed", &"rock", &"open", &"closed", &"thumb"]

var dance_beats_per_second := 1.7
var body_bounce := 6.0
var body_jiggle_degrees := 4.0
var body_sway := 7.0
var visual_follow_speed := 12.0
var secondary_motion_strength := 1.0
var lead_emphasis := 1.16
var reaction_seconds := 0.7
var result_cycle_seconds := 1.8
var pose_flow_hold_seconds := 0.45

var _character: ShapeCharacter
var _parts: Dictionary = {}
var _base: Dictionary = {}
var _expression := CharacterExpression.new()
var _dance_style: StringName = &"bounce"
var _dance_time := 0.0
var _phase_offset := 0.0
var _is_lead := false
var _dance_active := true
var _pose_direction: StringName = &""
var _pose_charge := 0.0
var _pose_held := false
var _visual_charge := 0.0
var _reaction: StringName = &"none"
var _reaction_time := 0.0
var _eliminated := false
var _result_mood: StringName = &"none"
var _frozen_targets: Dictionary = {}
var _lead_flow_direction: StringName = &""
var _lead_flow_left := 0.0
var _jiggle_random := RandomNumberGenerator.new()
var _jiggle_clock := 0.0
var _jiggle_speed := 1.0
var _jiggle_mode_left := 0.0
var _slow_jiggle := false


func apply_tuning(tuning: SimonSaysTuning) -> void:
	dance_beats_per_second = tuning.dance_beats_per_second
	body_bounce = tuning.body_bounce
	body_jiggle_degrees = tuning.body_jiggle_degrees
	body_sway = tuning.body_sway
	visual_follow_speed = tuning.visual_follow_speed
	secondary_motion_strength = tuning.secondary_motion_strength
	lead_emphasis = tuning.lead_emphasis
	reaction_seconds = tuning.reaction_seconds
	result_cycle_seconds = tuning.result_cycle_seconds
	pose_flow_hold_seconds = tuning.pose_flow_hold_seconds


func setup(character: ShapeCharacter, is_lead: bool = false, phase_index: int = 0, phase_count: int = 1) -> void:
	_character = character
	_is_lead = is_lead
	_phase_offset = 0.0 if is_lead else float(maxi(phase_index, 0)) / float(maxi(phase_count, 1))
	for part_name: StringName in PART_NAMES:
		var part := _character.get_node(NodePath(part_name)) as Sprite2D
		_parts[part_name] = part
		_base[part_name] = _transform(part.position, part.rotation_degrees, part.scale)
	set_variation_seed(phase_index + 1201)


func set_dance_style(style: StringName) -> void:
	if style in DANCE_STYLES:
		_dance_style = style


## Accepts authoritative normalized charge. It never determines pose success.
func set_pose_state(direction: StringName, normalized_charge: float, held: bool) -> void:
	_pose_direction = direction if direction in DIRECTIONS else &""
	_pose_charge = clampf(normalized_charge, 0.0, 1.0) if not _pose_direction.is_empty() else 0.0
	_pose_held = held


func set_dance_active(active: bool) -> void:
	if _dance_active == active:
		return
	_dance_active = active
	if not active:
		_frozen_targets = _current_targets()


## Briefly flows a lead through a canonical command pose while music continues.
func play_lead_pose_flow(direction: StringName) -> void:
	if _is_lead and _dance_active and direction in DIRECTIONS:
		_lead_flow_direction = direction
		_lead_flow_left = pose_flow_hold_seconds


func play_reaction(reaction: StringName) -> void:
	if not _eliminated and reaction in REACTIONS and reaction != &"none":
		_result_mood = &"none"
		_reaction = reaction
		_reaction_time = 0.0


func set_eliminated(eliminated: bool) -> void:
	_eliminated = eliminated
	_reaction = &"none"
	_result_mood = &"none"
	_visual_charge = 0.0


func set_result_mood(mood: StringName) -> void:
	if not _eliminated:
		_result_mood = mood if mood in RESULT_MOODS else &"none"
		_reaction = &"none"


func semantic_state() -> Dictionary:
	return {"dance_style": _dance_style, "pose_direction": _pose_direction, "pose_charge": _pose_charge, "pose_held": _pose_held, "reaction": _reaction, "eliminated": _eliminated, "result_mood": _result_mood, "dance_active": _dance_active, "phase_offset": _phase_offset, "is_lead": _is_lead}


func _process(delta: float) -> void:
	if _character == null:
		return
	if _dance_active and not _eliminated:
		_dance_time += delta
		_update_jiggle_pattern(delta)
	if _lead_flow_left > 0.0:
		_lead_flow_left = maxf(_lead_flow_left - delta, 0.0)
		if is_zero_approx(_lead_flow_left): _lead_flow_direction = &""
	if _reaction != &"none":
		_reaction_time += delta
		if _reaction_time >= reaction_seconds:
			_reaction = &"none"
			_reaction_time = 0.0
	_visual_charge = move_toward(_visual_charge, _pose_charge, visual_follow_speed * delta)
	var targets := _current_targets()
	for part_name: StringName in _parts:
		var part: Sprite2D = _parts[part_name]
		var target: Dictionary = targets[part_name]
		part.position = target.position
		part.rotation_degrees = target.rotation
		part.scale = target.scale
	_update_living_details(delta)


func _current_targets() -> Dictionary:
	if _eliminated: return _eliminated_targets()
	if _reaction != &"none": return _reaction_targets(_reaction, _reaction_time)
	if _result_mood != &"none": return _result_targets(_result_mood, _dance_time)
	var dance := _dance_targets(_dance_time + _phase_seconds())
	if not _dance_active and _visual_charge < 1.0 and not _frozen_targets.is_empty(): dance = _frozen_targets
	if _pose_direction.is_empty() and not _lead_flow_direction.is_empty():
		var flow_progress := _lead_flow_left / maxf(pose_flow_hold_seconds, 0.001)
		return _mix_targets(dance, _pose_targets(_lead_flow_direction), sin(flow_progress * PI) * 0.92)
	if _pose_direction.is_empty(): return dance
	return _mix_targets(dance, _pose_targets(_pose_direction), smoothstep(0.0, 1.0, _visual_charge))


func _phase_seconds() -> float:
	return _phase_offset * 4.0 / maxf(dance_beats_per_second, 0.001)


func _update_living_details(delta: float) -> void:
	var face: Sprite2D = _parts[&"Face"]
	if _eliminated:
		face.texture = CharacterExpression.FACES[&"sad"]
		_set_hands(&"closed", &"closed")
		return
	if _reaction == &"life_loss" or _result_mood == &"moody": face.texture = CharacterExpression.FACES[&"worried"]
	elif _reaction == &"survived" or _result_mood == &"happy": face.texture = CharacterExpression.FACES[&"delighted"]
	elif _pose_held and is_equal_approx(_pose_charge, 1.0): face.texture = CharacterExpression.FACES[_pose_face(_pose_direction)]
	else: face.texture = _expression.advance(delta)
	var hand_shape := _pose_hand_shape(_pose_direction) if _pose_charge > 0.15 else &""
	if _reaction == &"survived" or _result_mood == &"happy": _set_hands(&"rock", &"rock")
	elif hand_shape.is_empty():
		var shapes := dance_hand_shapes_at(_dance_time + _phase_seconds())
		_set_hands(shapes[0], shapes[1])
	elif _pose_direction == &"left": _set_hands(&"open", &"peace")
	elif _pose_direction == &"down": _set_hands(&"thumb", &"open")
	else: _set_hands(hand_shape, hand_shape)


func _set_hands(left_shape: StringName, right_shape: StringName) -> void:
	(_parts[&"LeftHand"] as Sprite2D).texture = HANDS[left_shape]
	(_parts[&"RightHand"] as Sprite2D).texture = HANDS[right_shape]


func _pose_hand_shape(direction: StringName) -> StringName:
	match direction:
		&"up": return &"rock"
		&"right", &"left": return &"open"
		&"down": return &"thumb"
	return &""


func _pose_face(direction: StringName) -> StringName:
	match direction:
		&"up", &"left": return &"delighted"
		&"right": return &"cheeky"
		&"down": return &"blink"
	return &"neutral"


func set_expression_seed(seed: int) -> void: _expression.reset(seed)
func expression_tag() -> StringName: return _expression.current_tag()
func dance_hand_shapes_at(time: float) -> Array[StringName]:
	var beat := floori(time * dance_beats_per_second / 5.0)
	return [DANCE_HANDS[posmod(beat, DANCE_HANDS.size())], DANCE_HANDS[posmod(beat + 2, DANCE_HANDS.size())]]
func set_variation_seed(seed: int) -> void:
	_expression.reset(seed)
	_jiggle_random.seed = seed
	_slow_jiggle = false
	_jiggle_speed = 1.0
	_jiggle_mode_left = _jiggle_random.randf_range(6.0, 11.0)
func set_jiggle_seed(seed: int) -> void: set_variation_seed(seed if seed >= 0 else randi())
func jiggle_is_slow() -> bool: return _slow_jiggle


func _update_jiggle_pattern(delta: float) -> void:
	_jiggle_mode_left -= delta
	if _jiggle_mode_left <= 0.0:
		_slow_jiggle = not _slow_jiggle
		_jiggle_mode_left = _jiggle_random.randf_range(1.8, 3.2) if _slow_jiggle else _jiggle_random.randf_range(6.0, 11.0)
	_jiggle_speed = move_toward(_jiggle_speed, 0.42 if _slow_jiggle else 1.0, delta * 1.4)
	_jiggle_clock += delta * _jiggle_speed


func _dance_targets(time: float) -> Dictionary:
	var count := 6 if _dance_style == &"disco" else 4
	var speed := 0.8 if _dance_style == &"swing" else 1.12 if _dance_style == &"disco" else 1.0
	var beat := fmod(time * dance_beats_per_second * speed, float(count))
	var index := floori(beat)
	var result := _mix_targets(_dance_pose(_dance_style, index), _dance_pose(_dance_style, (index + 1) % count), smoothstep(0.0, 1.0, beat - index))
	var emphasis := lead_emphasis if _is_lead else 1.0
	var pulse := sin(_jiggle_clock * dance_beats_per_second * TAU)
	var lift := (sin(_jiggle_clock * dance_beats_per_second * TAU * 2.0 - PI * 0.5) + 1.0) * 0.5
	var sway := sin(_jiggle_clock * dance_beats_per_second * TAU * 0.5 + 0.7) * body_sway * emphasis
	result[&"Body"] = _transform(Vector2(sway, -body_bounce * lift * emphasis), body_jiggle_degrees * pulse * secondary_motion_strength, Vector2(0.5 + 0.025 * lift, 0.5 - 0.02 * lift))
	result[&"Face"] = _transform(Vector2(sway, -body_bounce * lift * emphasis), body_jiggle_degrees * pulse * secondary_motion_strength, Vector2.ONE * 0.5)
	return result


func _dance_pose(style: StringName, index: int) -> Dictionary:
	var result := _copy_base()
	if style == &"swing":
		var side := -1.0 if index % 2 == 0 else 1.0
		result[&"LeftHand"] = _transform(Vector2(-58 + 14 * side, -8 - 22 * side), -24 + 22 * side, Vector2.ONE * 0.5)
		result[&"RightHand"] = _transform(Vector2(58 + 14 * side, -8 + 22 * side), 24 + 22 * side, Vector2.ONE * 0.5)
		result[&"LeftFoot"] = _transform(Vector2(-27 - 10 * side, 59), -10 * side, Vector2.ONE * 0.5)
		result[&"RightFoot"] = _transform(Vector2(27 - 10 * side, 59), -10 * side, Vector2.ONE * 0.5)
	elif style == &"disco":
		var angle := float(index) / 6.0 * TAU
		result[&"LeftHand"] = _transform(Vector2(-58 + cos(angle) * 18, -4 + sin(angle) * 45), -32 + index * 12, Vector2.ONE * 0.5)
		result[&"RightHand"] = _transform(Vector2(58 - cos(angle) * 18, -4 - sin(angle) * 45), 32 + index * 12, Vector2.ONE * 0.5)
		result[&"LeftFoot"] = _transform(Vector2(-25 + sin(angle) * 13, 58), -12 + index * 4, Vector2.ONE * 0.5)
		result[&"RightFoot"] = _transform(Vector2(25 - sin(angle) * 13, 58), 12 - index * 4, Vector2.ONE * 0.5)
	else:
		var poses := [[Vector2(-66, -16), -38.0, Vector2(53, 30), 24.0], [Vector2(-52, 28), -12.0, Vector2(68, -22), 42.0], [Vector2(-61, 8), -25.0, Vector2(61, 8), 25.0], [Vector2(-70, -25), -44.0, Vector2(48, 34), 16.0]]
		var pose: Array = poses[index % poses.size()]
		result[&"LeftHand"] = _transform(pose[0], pose[1], Vector2.ONE * 0.5)
		result[&"RightHand"] = _transform(pose[2], pose[3], Vector2.ONE * 0.5)
		result[&"LeftFoot"] = _transform(Vector2(-30, 55 + (index % 2) * 7), -12, Vector2.ONE * 0.5)
		result[&"RightFoot"] = _transform(Vector2(30, 62 - (index % 2) * 8), 8, Vector2.ONE * 0.5)
	return result


## The sole canonical command-pose source shared by every style and role.
func _pose_targets(direction: StringName) -> Dictionary:
	var result := _copy_base()
	match direction:
		&"up":
			result[&"LeftHand"] = _transform(Vector2(-40, -72), -28, Vector2.ONE * 0.55); result[&"RightHand"] = _transform(Vector2(40, -72), 28, Vector2.ONE * 0.55)
		&"left":
			result[&"Body"] = _transform(Vector2(-5, 0), -8, Vector2(0.52, 0.48)); result[&"Face"] = _transform(Vector2(-5, -2), -8, Vector2.ONE * 0.5)
			result[&"LeftHand"] = _transform(Vector2(-82, -30), -42, Vector2.ONE * 0.55); result[&"RightHand"] = _transform(Vector2(-58, 6), -24, Vector2.ONE * 0.55)
		&"right":
			result[&"Body"] = _transform(Vector2(3, 1), 10, Vector2(0.51, 0.49)); result[&"Face"] = _transform(Vector2(3, 1), 10, Vector2.ONE * 0.5)
			result[&"LeftHand"] = _transform(Vector2(-67, -55), -28, Vector2.ONE * 0.54); result[&"RightHand"] = _transform(Vector2(76, 35), 38, Vector2.ONE * 0.58)
		&"down":
			result[&"Body"] = _transform(Vector2(0, 30), -6, Vector2(0.58, 0.39)); result[&"Face"] = _transform(Vector2(0, 23), -6, Vector2(0.53, 0.44))
			result[&"LeftHand"] = _transform(Vector2(-67, 38), -18, Vector2.ONE * 0.54); result[&"RightHand"] = _transform(Vector2(67, 27), 24, Vector2.ONE * 0.54)
			result[&"LeftFoot"] = _transform(Vector2(-43, 72), -16, Vector2.ONE * 0.52); result[&"RightFoot"] = _transform(Vector2(43, 72), 16, Vector2.ONE * 0.52)
	return result


func _reaction_targets(kind: StringName, time: float) -> Dictionary:
	var result := _copy_base()
	var progress := clampf(time / maxf(reaction_seconds, 0.001), 0.0, 1.0)
	if kind == &"life_loss":
		var recoil := sin(progress * PI) * 24.0
		result[&"Body"] = _transform(Vector2(-recoil, recoil * 0.25), -sin(progress * PI) * 16.0, Vector2.ONE * 0.5); result[&"Face"] = result[&"Body"]
		result[&"LeftHand"] = _transform(Vector2(-75, 22 + recoil * 0.4), -58, Vector2.ONE * 0.5); result[&"RightHand"] = _transform(Vector2(75, 22 + recoil * 0.4), 58, Vector2.ONE * 0.5)
	else:
		var jump := sin(progress * PI) * 30.0
		result[&"Body"] = _transform(Vector2(0, -jump), sin(progress * TAU) * 8.0, Vector2(0.52, 0.48)); result[&"Face"] = _transform(Vector2(0, -jump), sin(progress * TAU) * 8.0, Vector2.ONE * 0.5)
		result[&"LeftHand"] = _transform(Vector2(-54, -55 - jump), -35, Vector2.ONE * 0.55); result[&"RightHand"] = _transform(Vector2(54, -55 - jump), 35, Vector2.ONE * 0.55)
	return result


func _eliminated_targets() -> Dictionary:
	var result := _copy_base()
	result[&"Body"] = _transform(Vector2(0, 18), 8, Vector2(0.55, 0.43)); result[&"Face"] = _transform(Vector2(0, 14), 8, Vector2.ONE * 0.5)
	result[&"LeftHand"] = _transform(Vector2(-59, 43), -18, Vector2.ONE * 0.5); result[&"RightHand"] = _transform(Vector2(59, 43), 18, Vector2.ONE * 0.5)
	return result


func _result_targets(mood: StringName, time: float) -> Dictionary:
	var result := _copy_base()
	var wave := sin(time / maxf(result_cycle_seconds, 0.001) * TAU)
	if mood == &"happy":
		result[&"Body"] = _transform(Vector2(0, -absf(wave) * 12), wave * 5, Vector2.ONE * 0.5); result[&"Face"] = result[&"Body"]
		result[&"LeftHand"] = _transform(Vector2(-55, -48 - wave * 8), -36, Vector2.ONE * 0.55); result[&"RightHand"] = _transform(Vector2(55, -48 + wave * 8), 36, Vector2.ONE * 0.55)
	else:
		result[&"Body"] = _transform(Vector2(wave * 3, 12), wave * 3, Vector2(0.52, 0.46)); result[&"Face"] = _transform(Vector2(wave * 3, 10), wave * 3, Vector2.ONE * 0.5)
		result[&"LeftHand"] = _transform(Vector2(-57, 36), -14, Vector2.ONE * 0.5); result[&"RightHand"] = _transform(Vector2(57, 36), 14, Vector2.ONE * 0.5)
	return result


func _copy_base() -> Dictionary: return _base.duplicate(true)
func _transform(position: Vector2, rotation: float, scale: Vector2) -> Dictionary: return {"position": position, "rotation": rotation, "scale": scale}
func _mix_transform(from: Dictionary, to: Dictionary, weight: float) -> Dictionary: return _transform((from.position as Vector2).lerp(to.position as Vector2, weight), lerpf(float(from.rotation), float(to.rotation), weight), (from.scale as Vector2).lerp(to.scale as Vector2, weight))
func _mix_targets(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result: Dictionary = {}
	for part_name: StringName in from: result[part_name] = _mix_transform(from[part_name], to[part_name], weight)
	return result
