extends TestScript
## A Flappy Race preset is one file: its flight, course and view parts live inside it, and the
## Default preset keeps the documented values.

const DEFAULT_PATH := "res://minigames/006_flappy_race/tuning/Default.tres"


func _run() -> void:
	var preset: FlappyRaceTuning = load(DEFAULT_PATH)
	check(preset.validation_errors().is_empty(), "The Default preset is valid")
	for part: Resource in [preset.flight, preset.course, preset.view]:
		check(part != null, "The Default preset holds every part")
		if part != null:
			check(part.resource_path.begins_with(DEFAULT_PATH + "::"), "A part lives in the preset")

	check(_same(preset.flight, FlappyFlightTuning.new()), "Flight keeps its documented values")
	check(_same(preset.view, FlappyRaceViewTuning.new()), "View keeps its documented values")
	var course := preset.course
	check(course.perfect_run_seconds == 120.0, "Course keeps a 2-minute perfect run")
	check(_ends(course.obstacle_spacing, 16.1, 12.65), "Spacing runs from 16.1 m to 12.65 m")
	check(_ends(course.gap_height, 8.4, 7.0), "Gap height runs from 8.4 m to 7 m")
	check(_ends(course.largest_gap_change, 4.0, 9.0), "Largest gap change runs from 4 m to 9 m")
	check(_ends(course.pickup_chance, 0.1, 0.25), "Pickup chance runs from 0.1 to 0.25")


func _same(part: Resource, fresh: Resource) -> bool:
	for property: Dictionary in fresh.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if part.get(property.name) != fresh.get(property.name):
			return false
	return true


func _ends(curve: Curve, start: float, end: float) -> bool:
	return is_equal_approx(curve.sample(0.0), start) and is_equal_approx(curve.sample(1.0), end)
