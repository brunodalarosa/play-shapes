extends SceneTree

const Classifier = preload("res://minigames/bubbles_gesture_classifier.gd")
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tuning := BubblesTuning.new()
	_check(Classifier.classify([[0.2, 0.2], [0.3, 0.2]], tuning).action == &"swipe", "Short swipe is recognized")
	_check(Classifier.classify([[0.2, 0.2], [0.22, 0.2], [0.24, 0.2], [0.26, 0.2], [0.28, 0.2], [0.3, 0.2]], tuning).action == &"swipe", "Sampled straight swipe is recognized")
	var long_swipe: Dictionary = Classifier.classify([[0.1, 0.2], [0.8, 0.2]], tuning)
	_check(long_swipe.action == &"swipe" and long_swipe.strength == tuning.swipe_impulse, "Long swipe has fixed strength")
	_check(Classifier.classify([[0.2, 0.2], [0.21, 0.2]], tuning).action == &"none", "Tiny trace has no action")
	var clockwise := _circle(2.0, false)
	var counterclockwise := _circle(2.0, true)
	_check(Classifier.classify(clockwise, tuning).action == &"spin", "Two clockwise circles charge one spin")
	_check(Classifier.classify(counterclockwise, tuning).action == &"spin", "Two counterclockwise circles charge one spin")
	var partial: Dictionary = Classifier.classify(_circle(1.5, false), tuning)
	_check(partial.action == &"none" and partial.reason == &"incomplete_circle", "Partial circle cannot become a swipe")
	_check(Classifier.classify(_circle(0.5, false), tuning).action == &"none", "Half-circle remains discarded")
	_check(not Classifier.classify([], tuning).accepted, "Empty trace is rejected")
	_check(not Classifier.classify(_many_points(), tuning).accepted, "Oversized trace is rejected")
	_check(not Classifier.classify([[0.1, 0.2], [INF, 0.2]], tuning).accepted, "Non-finite point is rejected")
	_check(not Classifier.classify([[0.1, 0.2], [1.1, 0.2]], tuning).accepted, "Out-of-range point is rejected")
	_check(not Classifier.classify([[0.1, 0.2], ["0.3", 0.2]], tuning).accepted, "String coordinate is rejected")
	print("Bubbles classifier checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _circle(turns: float, reverse: bool) -> Array:
	var points: Array = []
	var steps := roundi(turns * 32.0)
	for index: int in steps + 1:
		var angle := float(index) / 32.0 * TAU * (-1.0 if reverse else 1.0)
		points.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return points


func _many_points() -> Array:
	var points: Array = []
	for index: int in 129:
		points.append([0.2, 0.2])
	return points


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
