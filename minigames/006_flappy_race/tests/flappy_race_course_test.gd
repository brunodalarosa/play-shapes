extends TestScript
## The seeded course generator: determinism, the difficulty curves, the clear stretches,
## respawn spots, pickup placement and the course size at the default tuning.

const SNAP := FlappyRaceCourse.SNAP
const TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")


func _run() -> void:
	check(TUNING.validation_errors().is_empty(), "The default Flappy Race tuning is valid")
	_check_determinism()
	_check_shape()
	_check_curves()
	_check_respawn_spots()
	_check_pickups_and_looks()
	_check_message()
	_check_validation()


func _check_determinism() -> void:
	var first := JSON.stringify(FlappyRaceCourse.generate(7, TUNING).to_dictionary())
	var again := JSON.stringify(FlappyRaceCourse.generate(7, TUNING).to_dictionary())
	var other := JSON.stringify(FlappyRaceCourse.generate(8, TUNING).to_dictionary())
	check(first == again, "The same seed and tuning give the same course")
	check(first != other, "Different seeds give different courses")


func _check_shape() -> void:
	var course := FlappyRaceCourse.generate(1, TUNING)
	var obstacles := course.flight.obstacles
	check(course.length == 1200.0, "A 2-minute perfect run at 10 m/s is 1200 m")
	check(course.flight.finish_x == course.length, "The finish line ends the course")
	check(course.flight.start_x == 0.0 and course.flight.start_y == 17.0, "GO is at 17 m")
	check(obstacles.size() > 85 and obstacles.size() < 95, "About 90 obstacles")
	check(obstacles[0].x_start == 30.0, "3 s of clear travel before the first obstacle")
	check(obstacles.back().x_end <= course.length - 30.0, "3 s of clear travel before the finish")
	check(course.view_height == 34.0, "The course is made for a 34 m view")


func _check_curves() -> void:
	var settings: FlappyRaceCourseTuning = TUNING.course
	for seed_value: int in range(1, 21):
		var course := FlappyRaceCourse.generate(seed_value, TUNING)
		var obstacles := course.flight.obstacles
		var previous_centre := 17.0
		for index: int in obstacles.size():
			var obstacle := obstacles[index]
			var progress := obstacle.x_start / course.length
			var gap := obstacle.gap_top - obstacle.gap_bottom
			var change := absf(obstacle.gap_centre() - previous_centre)
			if not (
				check(_on_grid(obstacle), "Course geometry is snapped to 1/64 m")
				and check(
					absf(obstacle.x_end - obstacle.x_start - settings.obstacle_width) <= SNAP,
					"Every obstacle is 6 m wide",
				)
				and check(
					absf(gap - settings.gap_height.sample(progress)) <= SNAP * 2.0,
					"The gap height follows its curve",
				)
				and check(
					change <= settings.largest_gap_change.sample(progress) + SNAP * 2.0,
					"The gap change stays within its curve",
				)
				and check(
					obstacle.gap_bottom >= 34.0 * 0.2 - SNAP
					and obstacle.gap_top <= 34.0 * 0.8 + SNAP,
					"Gaps stay between 20% and 80% of the view height",
				)
			):
				return

			previous_centre = obstacle.gap_centre()
			if index == 0:
				continue

			var spacing := obstacle.x_start - obstacles[index - 1].x_start
			var expected := settings.obstacle_spacing.sample(
				obstacles[index - 1].x_start / course.length
			)
			if not check(absf(spacing - expected) <= SNAP * 2.0, "The spacing follows its curve"):
				return

	var course := FlappyRaceCourse.generate(1, TUNING)
	var first := course.flight.obstacles[1].x_start - course.flight.obstacles[0].x_start
	var last := course.flight.obstacles.size() - 1
	var final := course.flight.obstacles[last].x_start - course.flight.obstacles[last - 1].x_start
	check(first > 13.5 and final < 11.5, "Obstacles close in from 14 m to 11 m apart")


func _check_respawn_spots() -> void:
	var half: float = TUNING.flight.hit_half()
	var course := FlappyRaceCourse.generate(3, TUNING)
	var obstacles := course.flight.obstacles
	for index: int in obstacles.size():
		var obstacle := obstacles[index]
		var previous_end := obstacles[index - 1].x_end if index > 0 else 0.0
		if not (
			check(obstacle.respawn_x == obstacle.x_start - 2.0, "Respawn 2 m before the face")
			and check(
				absf(obstacle.respawn_y - obstacle.gap_centre()) <= SNAP * 0.5,
				"Respawn at the height of the gap centre",
			)
			and check(
				obstacle.respawn_x - half >= previous_end
				and obstacle.respawn_x + half <= obstacle.x_start,
				"The respawn spot keeps the hit box in the clear space",
			)
		):
			return


func _check_pickups_and_looks() -> void:
	var total := 0
	var kinds := { }
	var half: float = TUNING.course.pickup_size * 0.5
	for seed_value: int in range(1, 21):
		var course := FlappyRaceCourse.generate(seed_value, TUNING)
		total += course.flight.pickups.size()
		check(
			course.ground_kinds.size() == course.flight.obstacles.size(),
			"Every obstacle has a look",
		)
		for kind: String in course.ground_kinds:
			kinds[kind] = int(kinds.get(kind, 0)) + 1
		for pickup: FlappyFlightPickup in course.flight.pickups:
			var obstacle := _obstacle_at(course, pickup.x)
			if not check(obstacle != null, "A pickup sits in the middle of an obstacle's gap"):
				return
			var near_top := absf(obstacle.gap_top - 0.4 - half - pickup.y) <= SNAP * 2.0
			var near_bottom := absf(obstacle.gap_bottom + 0.4 + half - pickup.y) <= SNAP * 2.0
			if not check(near_top or near_bottom, "A pickup sits 0.4 m inside a gap edge"):
				return
			check(absf(pickup.half_size - half) <= SNAP, "A pickup is 1.6 m across")

	# Over 20 courses of 91 obstacles at a 10% to 25% chance, about 16 pickups each.
	var average := total / 20.0
	check(average > 12.0 and average < 20.0, "Pickups follow their chance curve: %s" % average)
	check(kinds.size() == 3, "Every ground obstacle look appears")
	var stalagmites: int = kinds.get(FlappyRaceCourse.STALAGMITE, 0)
	check(stalagmites > kinds.get(FlappyRaceCourse.ROCK_STACK, 0), "Mostly stalagmites")
	check(
		kinds.get(FlappyRaceCourse.ROCK_STACK, 0) > kinds.get(FlappyRaceCourse.CRYSTAL_CLUSTER, 0),
		"Rock stacks are more common than crystal clusters",
	)


func _check_message() -> void:
	var course := FlappyRaceCourse.generate(5, TUNING)
	var data := course.to_dictionary()
	check(not data.has("seed"), "The seed stays on the host")
	var text := JSON.stringify(data)
	var parsed: Dictionary = JSON.parse_string(text)
	var copy := FlappyFlightCourse.from_dictionary(parsed.flight)
	check(
		JSON.stringify(copy.to_dictionary()) == JSON.stringify(course.flight.to_dictionary()),
		"The course survives JSON unchanged",
	)
	check(
		text.length() < 16000,
		"The course message, sent once, stays under 16 KB: %d" % text.length(),
	)


func _check_validation() -> void:
	var tuning: FlappyRaceTuning = TUNING.duplicate(true)
	tuning.course.obstacle_width = 12.0
	check(not tuning.validation_errors().is_empty(), "Obstacles wider than their spacing fail")

	tuning = TUNING.duplicate(true)
	tuning.course.respawn_distance = 0.5
	check(not tuning.validation_errors().is_empty(), "A respawn inside the obstacle fails")

	tuning = TUNING.duplicate(true)
	tuning.course.gap_height = null
	check(not tuning.validation_errors().is_empty(), "A missing curve fails")


func _on_grid(obstacle: FlappyFlightObstacle) -> bool:
	for value: float in [obstacle.x_start, obstacle.x_end, obstacle.gap_bottom, obstacle.gap_top]:
		if value * 64.0 != roundf(value * 64.0):
			return false
	return true


func _obstacle_at(course: FlappyRaceCourse, x: float) -> FlappyFlightObstacle:
	for obstacle: FlappyFlightObstacle in course.flight.obstacles:
		if absf((obstacle.x_start + obstacle.x_end) * 0.5 - x) <= SNAP:
			return obstacle
	return null
