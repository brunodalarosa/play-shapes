class_name FlappyRaceCourse
extends RefCounted
## A seeded Flappy Race course: obstacle pairs and speed pickups between the start line and the
## finish line. Only the host generates it; phones receive [method to_dictionary]. The same seed
## and tuning always give the same course.

const STALAGMITE := "stalagmite"
const ROCK_STACK := "rock_stack"
const CRYSTAL_CLUSTER := "crystal_cluster"
## Geometry is snapped to 1/64 m, which JSON carries exactly to the phone (decision 0047).
const SNAP := 1.0 / 64.0

var course_seed := 0
var length := 0.0
var view_height := 0.0
var flight := FlappyFlightCourse.new()
## The look of each obstacle's ground half, in obstacle order. The hanging half is always a
## stalactite.
var ground_kinds := PackedStringArray()


static func generate(seed_value: int, tuning: FlappyRaceTuning) -> FlappyRaceCourse:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var settings := tuning.course
	var speed := tuning.flight.forward_speed
	var half := tuning.flight.hit_half()

	var course := FlappyRaceCourse.new()
	course.course_seed = seed_value
	course.length = _snap(settings.perfect_run_seconds * speed)
	course.view_height = settings.view_height
	course.flight.start_y = _snap(settings.start_height)
	course.flight.finish_x = course.length

	var lowest := settings.view_height * settings.gap_lowest_share
	var highest := settings.view_height * settings.gap_highest_share
	var last_end := course.length - settings.finish_clear_seconds * speed
	var x := settings.start_clear_seconds * speed
	var centre := settings.start_height
	var previous: FlappyFlightObstacle = null
	while x + settings.obstacle_width <= last_end:
		var progress := x / course.length
		var gap := settings.gap_height.sample(progress)
		var change := settings.largest_gap_change.sample(progress)
		var lowest_centre := lowest + gap * 0.5
		var highest_centre := highest - gap * 0.5
		var low := maxf(lowest_centre, centre - change)
		var high := minf(highest_centre, centre + change)
		if previous != null:
			var reach := _reach(previous, x, gap, tuning.flight)
			low = maxf(low, reach.x)
			high = minf(high, reach.y)
		var gap_centre := clampf(low, lowest_centre, highest_centre)
		if low <= high:
			gap_centre = rng.randf_range(low, high)

		var obstacle := FlappyFlightObstacle.new()
		obstacle.x_start = _snap(x)
		obstacle.x_end = _snap(x + settings.obstacle_width)
		obstacle.gap_bottom = _snap(gap_centre - gap * 0.5)
		obstacle.gap_top = _snap(gap_centre + gap * 0.5)
		var after_previous := (previous.x_end if previous != null else 0.0) + half
		obstacle.respawn_x = _snap(maxf(x - settings.respawn_distance, after_previous))
		obstacle.respawn_y = _snap(obstacle.gap_centre())
		course.flight.obstacles.append(obstacle)
		course.ground_kinds.append(_ground_kind(rng.randf(), settings))

		# Rolled for every obstacle, so a pickup change never shifts the obstacles after it.
		var roll := rng.randf()
		var on_top := rng.randf() < 0.5
		if roll < settings.pickup_chance.sample(progress):
			course.flight.pickups.append(_pickup(obstacle, on_top, settings))

		centre = gap_centre
		previous = obstacle
		x += settings.obstacle_spacing.sample(progress)
	return course


static func _snap(value: float) -> float:
	return snappedf(value, SNAP)


## The lowest and highest gap centre a Cubio can still reach after [param previous], for a gap
## of [param gap] starting at [param x]. Between the two, the hit box has the clear stretch at
## boosted speed. Down, it falls from rest at the bottom of the previous gap; up, it flaps every
## tick from the top. Both are slower than the best a player can do.
static func _reach(
	previous: FlappyFlightObstacle,
	x: float,
	gap: float,
	flight: FlappyFlightTuning,
) -> Vector2:
	var half := flight.hit_half()
	var travel := maxf(x - previous.x_end - half * 2.0, 0.0)
	var time := travel / flight.boosted_speed()
	var cap_time := flight.max_fall_speed / flight.gravity
	var fall := 0.5 * flight.gravity * time * time
	if time > cap_time:
		fall = 0.5 * flight.gravity * cap_time * cap_time + flight.max_fall_speed * (
			time - cap_time
		)
	var climb := flight.flap_velocity * time

	var lowest := previous.gap_bottom + half - fall - gap * 0.5 + half
	var highest := previous.gap_top - half + climb + gap * 0.5 - half
	return Vector2(lowest, highest)


static func _ground_kind(roll: float, settings: FlappyRaceCourseTuning) -> String:
	var total := settings.stalagmite_weight + settings.rock_stack_weight
	total += settings.crystal_cluster_weight
	var pick := roll * total
	if pick < settings.stalagmite_weight:
		return STALAGMITE
	if pick < settings.stalagmite_weight + settings.rock_stack_weight:
		return ROCK_STACK
	return CRYSTAL_CLUSTER


static func _pickup(
	obstacle: FlappyFlightObstacle,
	on_top: bool,
	settings: FlappyRaceCourseTuning,
) -> FlappyFlightPickup:
	var pickup := FlappyFlightPickup.new()
	pickup.half_size = _snap(settings.pickup_size * 0.5)
	pickup.x = _snap((obstacle.x_start + obstacle.x_end) * 0.5)
	var inset := settings.pickup_edge_distance + pickup.half_size
	pickup.y = _snap(obstacle.gap_top - inset if on_top else obstacle.gap_bottom + inset)
	return pickup


func to_dictionary() -> Dictionary:
	return {
		"length": length,
		"view_height": view_height,
		"flight": flight.to_dictionary(),
		"ground_kinds": Array(ground_kinds),
	}
