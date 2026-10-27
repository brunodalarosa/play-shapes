extends TestScript
## Every course at the default tuning can be flown with no hit, and a perfect run lasts about
## 2 minutes. The autopilot flies the perfect run with every pickup already taken, and a second
## run with pickups, whose boosts leave less time between gaps.
## flappy_race_flyable_sweep_test.gd flies many more seeds under --full.

const TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")
## Twice the perfect run is more than any clean run needs.
const MOST_TICKS := 2 * 120 * FlappyFlightTuning.TICK_RATE

var perfect_seeds := range(1, 5)
var pickup_seeds := range(101, 103)


func _run() -> void:
	for seed_value: int in perfect_seeds:
		var ticks := _fly(seed_value, false)
		if not check(
			ticks > 0,
			"Seed %d: a perfect run reaches the finish with no hit" % seed_value,
		):
			return
		# The finish is crossed in the tick the Cubio reaches 1200 m at 10 m/s.
		check(absi(ticks - 7200) <= 1, "Seed %d: a perfect run lasts 2 minutes" % seed_value)

	for seed_value: int in pickup_seeds:
		var ticks := _fly(seed_value, true)
		if not check(ticks > 0, "Seed %d: a run with pickups has no hit" % seed_value):
			return
		check(ticks < 7200, "Seed %d: pickups shorten the run" % seed_value)


## Flies course [param seed_value] and returns the tick it crossed the finish, or 0 on a hit.
func _fly(seed_value: int, with_pickups: bool) -> int:
	var course := FlappyRaceCourse.generate(seed_value, TUNING)
	var flight := FlappyFlight.new(TUNING.flight, course.flight)
	var state := flight.new_state()
	if not with_pickups:
		state.taken.fill(1)
	var pilot := FlappyFlightAutopilot.new(TUNING.flight, course.flight)
	for tick: int in MOST_TICKS:
		if flight.step(state, pilot.decide(state)) & FlappyFlight.EVENT_HIT != 0:
			push_error("Seed %d: hit at %.2f m, %.2f m up" % [seed_value, state.x, state.y])
			return 0
		if state.x >= course.flight.finish_x:
			return tick + 1
	return 0
