@tool
class_name FlappyRaceTuning
extends Resource
## The Flappy Race rules profile, selected in Tuning/Active Presets.tres. A preset is one file
## holding its flight, course and view parts. Values are starting points from the Flappy Bird
## reference; human play decides them.

## The flappy shape gameplay values, shared with the phone.
@export var flight: FlappyFlightTuning
## How the course is generated.
@export var course: FlappyRaceCourseTuning
## How the race looks and feels on the phone and the shared screen.
@export var view: FlappyRaceViewTuning

@export_group("Race")
## 3, 2, 1, GO before forward motion and gravity start, s. Default: 3.
@export_range(0.0, 10.0, 0.5, "suffix:s") var countdown_seconds: float = 3.0
## The race ends when this runs out, if not everyone has finished, s. Default: 360.
@export_range(10.0, 1800.0, 1.0, "suffix:s") var race_seconds: float = 360.0
## The large countdown at the end of the race timer, s. Default: 10.
@export_range(0.0, 60.0, 1.0, "suffix:s") var last_seconds: float = 10.0
## How far behind its clock the host settles every flight, so a tap reaching it this late
## still counts at the tick the phone applied it (decision 0048), s. Default: 0.25.
@export_range(0.0, 1.0, 0.05, "suffix:s") var tap_window_seconds: float = 0.25
## How often each phone receives its own settled flight. Default: 20.
@export_range(1, 60, 1, "suffix:Hz") var state_hz: int = 20


## Whole simulation ticks in [param seconds].
static func ticks(seconds: float) -> int:
	return FlappyFlightTuning.ticks(seconds)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if flight == null or course == null or view == null:
		errors.append("Flappy Race: the flight, course and view tuning must be set.")
		return errors

	errors.append_array(flight.validation_errors())
	errors.append_array(course.validation_errors())
	errors.append_array(view.validation_errors())
	if not errors.is_empty():
		return errors

	var half := flight.hit_half()
	if course.respawn_distance < half:
		errors.append("Flappy Race: a respawn spot must keep the hit box out of its obstacle.")
	var closest := course.shortest_possible_spacing()
	if closest - course.obstacle_width < course.respawn_distance + half:
		errors.append("Flappy Race: obstacles must leave room for the respawn spot between them.")
	if view.farthest_visible_height < course.view_height:
		errors.append("Flappy Race: the shared screen cannot zoom in past the view height.")
	if FlappyRaceCourseTuning.curve_range(course.gap_height).x <= half * 2.0:
		errors.append("Flappy Race: every gap must be taller than the hit box.")
	var largest_pickup_gap := course.pickup_size + course.pickup_edge_distance
	if FlappyRaceCourseTuning.curve_range(course.gap_height).x < largest_pickup_gap:
		errors.append("Flappy Race: a pickup must fit inside its gap.")
	if course.start_height - half <= 0.0:
		errors.append("Flappy Race: the start height must be above the ground.")
	if ticks(race_seconds) < 1 or last_seconds > race_seconds:
		errors.append("Flappy Race: the race must last, and longer than its last seconds.")
	if countdown_seconds < 0.0 or tap_window_seconds < 0.0:
		errors.append("Flappy Race: the countdown and the tap window cannot be negative.")
	if state_hz < 1 or state_hz > FlappyFlightTuning.TICK_RATE:
		errors.append("Flappy Race: phones get their state between once and 60 times a second.")
	return errors
