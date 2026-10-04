extends TestScript

const Classifier = preload(
	"res://minigames/002_bubbles_and_jellyfishes/bubbles_gesture_classifier.gd"
)


func _run() -> void:
	var tuning := BubblesTuning.new()
	var short_swipe := Classifier.classify([[0.2, 0.2], [0.3, 0.2]], tuning)
	check(short_swipe.action == &"swipe", "Short swipe is recognized")
	check(Classifier.classify([
			[0.2, 0.2],
			[0.22, 0.2],
			[0.24, 0.2],
			[0.26, 0.2],
			[0.28, 0.2],
			[0.3, 0.2],
		], tuning).action == &"swipe", "Sampled straight swipe is recognized")
	var long_swipe: Dictionary = Classifier.classify([[0.1, 0.2], [0.8, 0.2]], tuning)
	check(
		long_swipe.action == &"swipe" and long_swipe.strength == tuning.swipe_impulse,
		"Long swipe has fixed strength",
	)
	var tiny_trace := Classifier.classify([[0.2, 0.2], [0.21, 0.2]], tuning)
	check(tiny_trace.action == &"none", "Tiny trace has no action")
	var clockwise := _circle(2.0, false)
	var counterclockwise := _circle(2.0, true)
	check(
		Classifier.classify(clockwise, tuning).action == &"spin",
		"Two clockwise circles charge one spin",
	)
	check(
		Classifier.classify(counterclockwise, tuning).action == &"spin",
		"Two counterclockwise circles charge one spin",
	)
	var partial: Dictionary = Classifier.classify(_circle(1.5, false), tuning)
	check(
		partial.action == &"none" and partial.reason == &"incomplete_circle",
		"Partial circle cannot become a swipe",
	)
	var half_circle := Classifier.classify(_circle(0.5, false), tuning)
	check(half_circle.action == &"none", "Half-circle remains discarded")
	check(not Classifier.classify([], tuning).accepted, "Empty trace is rejected")
	check(not Classifier.classify(_many_points(), tuning).accepted, "Oversized trace is rejected")
	var non_finite := Classifier.classify([[0.1, 0.2], [INF, 0.2]], tuning)
	check(not non_finite.accepted, "Non-finite point is rejected")
	var out_of_range := Classifier.classify([[0.1, 0.2], [1.1, 0.2]], tuning)
	check(not out_of_range.accepted, "Out-of-range point is rejected")
	var string_coordinate := Classifier.classify([[0.1, 0.2], ["0.3", 0.2]], tuning)
	check(not string_coordinate.accepted, "String coordinate is rejected")


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
