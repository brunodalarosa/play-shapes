@tool
class_name FlappyRaceTuning
extends Resource
## The Flappy Race rules profile, selected in Tuning/Active Presets.tres. Values are starting
## points from the Flappy Bird reference; human play decides them.

## The flappy shape gameplay values, shared with the phone.
@export var flight: FlappyFlightTuning = preload(
	"res://minigames/006_flappy_race/tuning/Flight.tres"
)
## How the course is generated.
@export var course: FlappyRaceCourseTuning = preload(
	"res://minigames/006_flappy_race/tuning/Course.tres"
)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if flight == null or course == null:
		errors.append("Flappy Race: the flight and course tuning must be set.")
		return errors

	errors.append_array(flight.validation_errors())
	errors.append_array(course.validation_errors())
	if not errors.is_empty():
		return errors

	var half := flight.hit_half()
	if course.respawn_distance < half:
		errors.append("Flappy Race: a respawn spot must keep the hit box out of its obstacle.")
	var closest := FlappyRaceCourseTuning.curve_range(course.obstacle_spacing).x
	if closest - course.obstacle_width < course.respawn_distance + half:
		errors.append("Flappy Race: obstacles must leave room for the respawn spot between them.")
	if FlappyRaceCourseTuning.curve_range(course.gap_height).x <= half * 2.0:
		errors.append("Flappy Race: every gap must be taller than the hit box.")
	var largest_pickup_gap := course.pickup_size + course.pickup_edge_distance
	if FlappyRaceCourseTuning.curve_range(course.gap_height).x < largest_pickup_gap:
		errors.append("Flappy Race: a pickup must fit inside its gap.")
	if course.start_height - half <= 0.0:
		errors.append("Flappy Race: the start height must be above the ground.")
	return errors
