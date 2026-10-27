class_name FlappyFlight
extends RefCounted
## The flappy shape gameplay: one fixed 60 Hz step of a player's flight over a course.
##
## web/src/flappy_flight/flight.ts is the same step in TypeScript, line for line, so the phone
## predicts exactly what the host computes (decision 0047). Change both together and regenerate
## tests/fixtures/flappy_flight_runs.json. Only addition, subtraction, multiplication, division,
## min and max are used, in the same order on both sides.

## Bits of what [method step] reports.
const EVENT_FLAP := 1
const EVENT_HIT := 2
const EVENT_PICKUP := 4
const EVENT_HEART_REFILLED := 8
const EVENT_READY := 16
const EVENT_RESPAWN := 32

var course: FlappyFlightCourse
var _forward_speed := 0.0
var _boosted_speed := 0.0
var _flap_velocity := 0.0
var _gravity := 0.0
var _max_fall_speed := 0.0
var _hit_half := 0.0
var _heart_count := 0
var _heart_recovery_ticks := 0
var _cooldown_ticks := 0
var _invulnerable_ticks := 0
var _boost_ticks := 0


func _init(tuning: FlappyFlightTuning, flight_course: FlappyFlightCourse) -> void:
	course = flight_course
	_forward_speed = tuning.forward_speed
	_boosted_speed = tuning.boosted_speed()
	_flap_velocity = tuning.flap_velocity
	_gravity = tuning.gravity
	_max_fall_speed = tuning.max_fall_speed
	_hit_half = tuning.hit_half()
	_heart_count = tuning.heart_count
	_heart_recovery_ticks = FlappyFlightTuning.ticks(tuning.heart_recovery_seconds)
	_cooldown_ticks = FlappyFlightTuning.ticks(tuning.respawn_cooldown_seconds)
	_invulnerable_ticks = FlappyFlightTuning.ticks(tuning.invulnerable_seconds)
	_boost_ticks = FlappyFlightTuning.ticks(tuning.boost_seconds)


## A player at the start line at GO, flying with every heart full.
func new_state() -> FlappyFlightState:
	var state := FlappyFlightState.new()
	state.x = course.start_x
	state.y = course.start_y
	state.hearts = HeartRow.new(_heart_count, _heart_recovery_ticks)
	state.taken.resize(course.pickups.size())
	return state


## Advances [param state] by one tick. [param tap] is a touch-down during this tick: a flap
## while flying, the respawn while waiting and ready, and nothing otherwise. Returns the
## EVENT_ bits of what happened.
func step(state: FlappyFlightState, tap: bool) -> int:
	var events := 0
	if state.hearts.tick():
		events |= EVENT_HEART_REFILLED

	if not state.flying:
		if state.cooldown_ticks > 0:
			state.cooldown_ticks -= 1
		if not state.ready and state.cooldown_ticks == 0 and not state.hearts.owed:
			state.ready = true
			events |= EVENT_READY
		if not state.ready or not tap:
			return events

		# The respawn tap is also the first flap.
		state.flying = true
		state.ready = false
		state.invulnerable_ticks = _invulnerable_ticks
		state.obstacle_index = 0
		events |= EVENT_RESPAWN

	if tap:
		state.vertical_speed = _flap_velocity
		events |= EVENT_FLAP
	else:
		state.vertical_speed = maxf(
			state.vertical_speed - _gravity * FlappyFlightTuning.TICK,
			-_max_fall_speed,
		)

	var speed := _boosted_speed if state.boost_ticks > 0 else _forward_speed
	state.x += speed * FlappyFlightTuning.TICK
	state.y += state.vertical_speed * FlappyFlightTuning.TICK
	if state.boost_ticks > 0:
		state.boost_ticks -= 1

	events |= _take_pickups(state)
	events |= _collide(state)
	if state.invulnerable_ticks > 0:
		state.invulnerable_ticks -= 1
	return events


func _take_pickups(state: FlappyFlightState) -> int:
	var events := 0
	for index: int in course.pickups.size():
		if state.taken[index] != 0:
			continue

		var pickup := course.pickups[index]
		var reach := _hit_half + pickup.half_size
		if absf(state.x - pickup.x) < reach and absf(state.y - pickup.y) < reach:
			state.taken[index] = 1
			state.boost_ticks = _boost_ticks
			events |= EVENT_PICKUP
	return events


func _collide(state: FlappyFlightState) -> int:
	var obstacles := course.obstacles
	var back := state.x - _hit_half
	var front := state.x + _hit_half
	while state.obstacle_index < obstacles.size() and obstacles[state.obstacle_index].x_end <= back:
		state.obstacle_index += 1

	if state.invulnerable_ticks > 0:
		# Invulnerable: through obstacles, and resting on the ground at no cost.
		if state.y - _hit_half < 0.0:
			state.y = _hit_half
			if state.vertical_speed < 0.0:
				state.vertical_speed = 0.0
		return 0

	if state.obstacle_index < obstacles.size():
		var obstacle := obstacles[state.obstacle_index]
		var inside := front > obstacle.x_start and back < obstacle.x_end
		var outside_gap := (
			state.y - _hit_half < obstacle.gap_bottom or state.y + _hit_half > obstacle.gap_top
		)
		if inside and outside_gap:
			return _hit(state, obstacle.respawn_x, obstacle.respawn_y)

	if state.y - _hit_half <= 0.0:
		# Out in the open, the next obstacle ahead sets the spot; past the last one, the last.
		if obstacles.is_empty():
			return _hit(state, state.x, course.start_y)
		var index := mini(state.obstacle_index, obstacles.size() - 1)
		return _hit(state, obstacles[index].respawn_x, obstacles[index].respawn_y)

	return 0


func _hit(state: FlappyFlightState, respawn_x: float, respawn_y: float) -> int:
	state.flying = false
	state.ready = false
	state.x = respawn_x
	state.y = respawn_y
	state.vertical_speed = 0.0
	state.boost_ticks = 0
	state.invulnerable_ticks = 0
	state.cooldown_ticks = _cooldown_ticks
	state.hearts.hit()
	return EVENT_HIT
