class_name ShapeFaceExpressions
extends RefCounted
## Which face a character shows, and when it blinks. A base face holds until it is replaced;
## timed expressions with a priority cover it while they last, the highest priority first.
## Natural blinks close the eyes briefly at random intervals. Time is passed in, in seconds,
## so callers and tests choose the clock. It never touches physics.

## The face shown when no expression is active.
var base_face := "face_a"
## Seconds between blinks, drawn at random within this range.
var blink_interval := Vector2(2.4, 5.6)
## How long a blink keeps the eyes closed.
var blink_seconds := 0.12

var _expressions: Dictionary[String, Vector2] = { }
var _next_blink := -1.0
var _random := RandomNumberGenerator.new()


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		_random.seed = seed_value
	else:
		_random.randomize()


## Shows [param face] until [param now] + [param seconds] unless something of higher priority
## covers it. Calling it again for the same face extends or shortens it, so a condition that
## holds can refresh it every frame.
func show(face: String, seconds: float, priority: int, now: float) -> void:
	_expressions[face] = Vector2(now + maxf(seconds, 0.0), priority)


## Ends [param face] early.
func clear(face: String) -> void:
	_expressions.erase(face)


## Ends every timed expression, leaving the base face.
func clear_all() -> void:
	_expressions.clear()


## The timed expression showing at [param now], or an empty string.
func active_expression(now: float) -> String:
	var best := ""
	var best_priority := -INF
	for face: String in _expressions.keys():
		var entry := _expressions[face]
		if entry.x <= now:
			_expressions.erase(face)
		elif entry.y > best_priority:
			best = face
			best_priority = entry.y
	return best


## The priority of the expression showing at [param now], or -1 for the base face.
func active_priority(now: float) -> int:
	var face := active_expression(now)
	return -1 if face.is_empty() else int(_expressions[face].y)


## The face to draw at [param now].
func face_at(now: float) -> String:
	var face := active_expression(now)
	return base_face if face.is_empty() else face


## True while a natural blink closes the eyes at [param now]. Calls must move forward in time.
func blinking_at(now: float) -> bool:
	if _next_blink < 0.0:
		_next_blink = now + _interval()
	while now >= _next_blink + blink_seconds:
		_next_blink += blink_seconds + _interval()
	return now >= _next_blink


func _interval() -> float:
	return _random.randf_range(blink_interval.x, maxf(blink_interval.x, blink_interval.y))
