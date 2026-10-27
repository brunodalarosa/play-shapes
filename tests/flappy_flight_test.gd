extends TestScript
## The flappy shape gameplay rules: flight, the ground, the open sky, the hit box, hearts,
## respawns, invulnerability and speed pickups.

const TICK := FlappyFlightTuning.TICK

var tuning := FlappyFlightTuning.new()


func _run() -> void:
	_check_tuning()
	_check_heart_diagram()
	_check_flight()
	_check_ground_hit_and_respawn()
	_check_hit_with_no_full_heart()
	_check_obstacles_and_open_sky()
	_check_hit_box_inset()
	_check_pickups()
	_check_invulnerability()
	_check_ground_past_the_last_obstacle()


func _check_tuning() -> void:
	check(tuning.validation_errors().is_empty(), "The default flight tuning is valid")
	var data := tuning.to_dictionary()
	check(data.heart_recovery_ticks == 600, "A heart refills in 600 ticks")
	check(data.respawn_cooldown_ticks == 120, "The respawn cooldown is 120 ticks")
	check(data.invulnerable_ticks == 60 and data.boost_ticks == 180, "Invulnerability and boost")
	check(is_equal_approx(tuning.hit_half(), 0.8), "The hit box is a 1.6 m square")

	var broken := FlappyFlightTuning.new()
	broken.hit_box_inset = 1.0
	check(not broken.validation_errors().is_empty(), "An inset that leaves no hit box is refused")


## The four panels of the design's heart diagram, with a 600-tick refill.
func _check_heart_diagram() -> void:
	var hearts := HeartRow.new(3, 600)
	check(hearts.full == 3 and not hearts.tick(), "Race start: three full hearts, nothing refills")

	hearts.hit()
	check(hearts.full == 2, "First hit: the rightmost heart flies out")
	_tick(hearts, 300)
	check(hearts.refill_ticks == 300, "First hit: heart 3 refills")

	hearts.hit()
	check(hearts.full == 1, "Second hit: heart 2 flies out")
	check(hearts.refill_ticks == 300, "Second hit: heart 2 takes over the refill progress")
	_tick(hearts, 299)
	check(hearts.full == 1, "The carried progress is not yet a full heart")
	check(hearts.tick() and hearts.full == 2, "The carried refill completes 300 ticks later")
	check(hearts.refill_ticks == 0, "Heart 3 then starts from empty")

	hearts.hit()
	hearts.hit()
	check(hearts.full == 0 and not hearts.owed, "Two more hits empty the row")
	_tick(hearts, 100)
	hearts.hit()
	check(hearts.owed and hearts.full == 0, "Hit with none: a heart is owed")
	check(hearts.refill_ticks == 100, "Hit with none keeps the refill progress")
	_tick(hearts, 499)
	check(hearts.owed, "Hit with none waits for heart 1")
	check(hearts.tick(), "Heart 1 finishes refilling")
	check(not hearts.owed and hearts.full == 0, "Heart 1 flies out instead of joining the row")


func _check_flight() -> void:
	var flight := FlappyFlight.new(tuning, _course([]))
	var state := flight.new_state()
	check(state.x == 0.0 and state.y == 17.0 and state.flying, "GO starts at the start spot")

	flight.step(state, false)
	check(state.vertical_speed == -75.0 * TICK, "Gravity pulls from the first tick")
	_steps(flight, state, 30)
	check(state.vertical_speed == -25.0, "The fall is capped at the maximum fall speed")

	var events := flight.step(state, true)
	check(events & FlappyFlight.EVENT_FLAP != 0, "A tap is a flap")
	check(state.vertical_speed == 22.5, "A flap replaces the vertical speed")

	var from := state.x
	_steps(flight, state, 60, true)
	check(absf(state.x - from - 10.0) < 1e-9, "The forward speed is a constant 10 m/s")


func _check_ground_hit_and_respawn() -> void:
	var flight := FlappyFlight.new(tuning, _course([_obstacle(60.0, 10.0)]))
	var state := flight.new_state()
	var hit_tick := _run_until(flight, state, FlappyFlight.EVENT_HIT, 200)
	check(hit_tick > 0, "A Cubio that never taps hits the ground")
	check(not state.flying and state.hearts.full == 2, "A ground hit spends a heart")
	check(state.x == 58.0 and state.y == 10.0, "A ground hit waits before the next obstacle")

	var events := 0
	for tick: int in 119:
		events |= flight.step(state, true)
	check(events == 0 and not state.flying, "Taps during the 2 s cooldown do nothing")
	events = flight.step(state, false)
	check(
		events == FlappyFlight.EVENT_READY and state.ready,
		"The heart is ready 2 s after the hit",
	)
	check(not state.flying, "There is no automatic respawn")

	events = flight.step(state, true)
	check(events & FlappyFlight.EVENT_RESPAWN != 0, "A tap on a ready heart respawns")
	check(events & FlappyFlight.EVENT_FLAP != 0, "The respawn tap is the first flap")
	check(state.flying and state.vertical_speed == 22.5, "The Cubio pops out flapping")
	check(state.invulnerable_ticks == 59, "The respawn step is the first invulnerable tick")


func _check_hit_with_no_full_heart() -> void:
	var flight := FlappyFlight.new(tuning, _course([_obstacle(60.0, 10.0)]))
	var state := flight.new_state()
	state.hearts.full = 0
	state.hearts.refill_ticks = 200
	var hit_tick := _run_until(flight, state, FlappyFlight.EVENT_HIT, 200)
	check(state.hearts.owed, "A hit with no full heart owes one")

	var waited := 0
	while not state.ready and waited < 1000:
		waited += 1
		flight.step(state, false)
	check(state.hearts.refill_ticks == 0 and not state.hearts.owed, "Heart 1 flew out")
	check(state.hearts.full == 0, "The owed heart was spent, not added to the row")
	check(waited == 600 - 200 - hit_tick, "Readiness waits for the refill, past the cooldown")


func _check_obstacles_and_open_sky() -> void:
	var obstacle := _obstacle(20.0, 17.0)
	var flight := FlappyFlight.new(tuning, _course([obstacle]))
	var state := flight.new_state()
	state.y = 100.0
	state.x = 10.0
	_steps(flight, state, 30, true)
	check(state.flying and state.y > 100.0, "The sky is open: no ceiling above the view")

	_run_until(flight, state, FlappyFlight.EVENT_HIT, 60, true)
	check(not state.flying, "A hanging obstacle reaches up without end")
	check(state.x == obstacle.respawn_x and state.y == 17.0, "An obstacle hit waits before it")


func _check_hit_box_inset() -> void:
	var obstacle := _obstacle(20.0, 17.0)
	var flight := FlappyFlight.new(tuning, _course([obstacle]))
	var state := flight.new_state()
	# The visible cube's top pokes 0.1 m into the hanging stone; the hit box stays clear.
	state.x = 22.0
	state.y = obstacle.gap_top - 0.9
	state.vertical_speed = 0.0
	var events := flight.step(state, false)
	check(events & FlappyFlight.EVENT_HIT == 0, "Only the inset hit box collides")

	state.y = obstacle.gap_top - 0.5
	state.vertical_speed = 0.0
	check(flight.step(state, false) & FlappyFlight.EVENT_HIT != 0, "The hit box itself collides")


func _check_pickups() -> void:
	var course := _course([_obstacle(80.0, 17.0)])
	course.pickups.append(_pickup(10.0, 17.0))
	course.pickups.append(_pickup(30.0, 17.0))
	var flight := FlappyFlight.new(tuning, course)
	var state := flight.new_state()
	state.x = 7.0
	var first := _run_until(flight, state, FlappyFlight.EVENT_PICKUP, 60)
	check(first > 0 and state.boost_ticks == 180, "A pickup boosts for 3 s")
	var x := state.x
	flight.step(state, false)
	check(absf(state.x - x - 12.5 * TICK) < 1e-9, "A boost adds 25% forward speed")

	state.x = 27.0
	state.y = 17.0
	state.vertical_speed = 0.0
	_run_until(flight, state, FlappyFlight.EVENT_PICKUP, 60)
	check(state.boost_ticks == 180, "Another pickup restarts the boost instead of adding to it")
	check(state.taken[0] == 1 and state.taken[1] == 1, "Each pickup is taken once per player")

	state.y = 0.9
	state.vertical_speed = -10.0
	flight.step(state, false)
	check(not state.flying and state.boost_ticks == 0, "A hit ends the boost")


func _check_invulnerability() -> void:
	var obstacle := _obstacle(20.0, 17.0)
	var low := _obstacle(60.0, 3.0)
	var flight := FlappyFlight.new(tuning, _course([obstacle, low]))
	var state := flight.new_state()
	state.x = 22.0
	state.y = 30.0
	flight.step(state, false)
	check(not state.flying, "The hanging stone hits")

	state.cooldown_ticks = 0
	flight.step(state, false)
	var events := 0
	for tick: int in 60:
		events |= flight.step(state, tick == 0)
	check(events & FlappyFlight.EVENT_HIT == 0, "Invulnerability lasts while passing the obstacle")
	check(state.x - tuning.hit_half() > obstacle.x_end, "The hit box has left the obstacle")

	state.x = 40.0
	state.y = 1.0
	state.vertical_speed = -20.0
	state.invulnerable_ticks = 10
	flight.step(state, false)
	check(
		state.flying and state.y == tuning.hit_half(),
		"Invulnerable, the Cubio rests on the ground",
	)
	check(state.vertical_speed == 0.0, "Resting stops the fall")
	_run_until(flight, state, FlappyFlight.EVENT_HIT, 20)
	check(not state.flying, "The ground costs a heart once invulnerability ends")


func _check_ground_past_the_last_obstacle() -> void:
	var last := _obstacle(20.0, 17.0)
	var flight := FlappyFlight.new(tuning, _course([_obstacle(5.0, 17.0), last]))
	var state := flight.new_state()
	state.x = 30.0
	state.y = 2.0
	_run_until(flight, state, FlappyFlight.EVENT_HIT, 60)
	check(state.x == last.respawn_x, "With no obstacle ahead, the last obstacle sets the spot")


func _course(obstacles: Array[FlappyFlightObstacle]) -> FlappyFlightCourse:
	var course := FlappyFlightCourse.new()
	course.start_y = 17.0
	course.finish_x = 200.0
	course.obstacles = obstacles
	return course


func _obstacle(x_start: float, centre: float) -> FlappyFlightObstacle:
	var obstacle := FlappyFlightObstacle.new()
	obstacle.x_start = x_start
	obstacle.x_end = x_start + 6.0
	obstacle.gap_bottom = centre - 4.2
	obstacle.gap_top = centre + 4.2
	obstacle.respawn_x = x_start - 2.0
	obstacle.respawn_y = centre
	return obstacle


func _pickup(x: float, y: float) -> FlappyFlightPickup:
	var pickup := FlappyFlightPickup.new()
	pickup.x = x
	pickup.y = y
	pickup.half_size = 0.8
	return pickup


func _tick(hearts: HeartRow, ticks: int) -> void:
	for tick: int in ticks:
		hearts.tick()


func _steps(flight: FlappyFlight, state: FlappyFlightState, ticks: int, hover := false) -> void:
	for tick: int in ticks:
		flight.step(state, hover and state.vertical_speed < 0.0)


## Steps until [param event] and returns its tick, or 0. With [param hover], taps keep the
## Cubio near [param height].
func _run_until(
	flight: FlappyFlight,
	state: FlappyFlightState,
	event: int,
	ticks: int,
	hover := false,
	height := 0.0,
) -> int:
	for tick: int in ticks:
		var tap := false
		if hover and height == 0.0:
			tap = state.vertical_speed < 0.0
		elif hover:
			tap = state.y < height and state.vertical_speed <= 0.0
		if flight.step(state, tap) & event != 0:
			return tick + 1
	return 0
