class_name CharacterExpression
extends RefCounted
## Life-like face timing kept separate from pose charge and transform animation.

const FACES: Dictionary = {
	&"neutral": preload("res://assets/runtime/shape_characters/faces/neutral.png"),
	&"blink": preload("res://assets/runtime/shape_characters/faces/blink.png"),
	&"delighted": preload("res://assets/runtime/shape_characters/faces/delighted.png"),
	&"cheeky": preload("res://assets/runtime/shape_characters/faces/cheeky.png"),
	&"sad": preload("res://assets/runtime/shape_characters/faces/sad.png"),
	&"worried": preload("res://assets/runtime/shape_characters/faces/worried.png"),
}
const EXPRESSION_DECK: Array[StringName] = [
	&"delighted", &"cheeky", &"delighted", &"cheeky", &"sad", &"delighted", &"worried"
]
const BLINK_SECONDS_MIN := 0.09 * 1.3
const BLINK_SECONDS_MAX := 0.15 * 1.3

var _random := RandomNumberGenerator.new()
var _tag: StringName = &"neutral"
var _blink_in: float = 0.0
var _expression_in: float = 0.0
var _state_left: float = 0.0

func _init(seed: int = -1) -> void:
	reset(seed)

func reset(seed: int = -1) -> void:
	if seed < 0:
		_random.randomize()
	else:
		_random.seed = seed
	_tag = &"neutral"
	_blink_in = _random.randf_range(1.8, 4.8)
	_expression_in = _random.randf_range(5.0, 9.0)
	_state_left = 0.0

func advance(delta: float, allow_emotion: bool = true) -> Texture2D:
	if _state_left > 0.0:
		_state_left -= delta
		if _state_left <= 0.0:
			_tag = &"neutral"
		return FACES[_tag]

	_blink_in -= delta
	_expression_in -= delta
	if _blink_in <= 0.0:
		_tag = &"blink"
		# The source face needs enough screen time to read as a blink, not a flicker.
		_state_left = _random.randf_range(BLINK_SECONDS_MIN, BLINK_SECONDS_MAX)
		_blink_in = _random.randf_range(2.0, 5.5)
	elif allow_emotion and _expression_in <= 0.0:
		_tag = EXPRESSION_DECK[_random.randi_range(0, EXPRESSION_DECK.size() - 1)]
		_state_left = _random.randf_range(0.45, 0.9)
		_expression_in = _random.randf_range(5.5, 11.0)
	return FACES[_tag]

func current_tag() -> StringName:
	return _tag
