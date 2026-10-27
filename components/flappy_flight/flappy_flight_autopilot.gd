class_name FlappyFlightAutopilot
extends RefCounted
## Flies a flappy flight without hitting anything, for tests and simulated players. It respawns
## as soon as its heart is ready.
##
## It flies as low as it safely can, which leaves the most room to fall into a lower gap. A
## floor follows the bottom of each gap and rises ahead of it at the steepest climb that
## flapping every tick gives, at boosted speed, so the Cubio is never too low to climb in. It
## flaps when the next tick would put it under the floor, unless that flap's arc would reach
## the hanging stone ahead.
##
## That rule cannot time a flap for a lower gap, so the autopilot also keeps a plan for the next
## [member lookahead] ticks, played out with the shared step. When the plan runs into a hit, it
## searches every way through and follows one that stays clear.

## Distance kept above the floor and below the stone, metres.
var margin := 0.1
## Ticks of the flap's arc checked against the stone ahead.
var arc_ticks := 60
## Ticks the plan looks ahead.
var lookahead := 90
## Ticks a repair searches; at least [member lookahead].
var search_ticks := 90
## States closer than this at the same vertical speed count as one in a repair, metres.
var merge_height := 0.5

var _flight: FlappyFlight
var _course: FlappyFlightCourse
var _tuning: FlappyFlightTuning
var _half := 0.0
var _climb_per_metre := 0.0
## The taps planned for the coming ticks, and the state after the last of them.
var _taps: Array[bool] = []
var _plan_end: FlappyFlightState


func _init(tuning: FlappyFlightTuning, course: FlappyFlightCourse) -> void:
	_tuning = tuning
	_course = course
	_flight = FlappyFlight.new(tuning, course)
	_half = tuning.hit_half()
	_climb_per_metre = tuning.flap_velocity / tuning.boosted_speed()


## Whether to tap during the next step of [param state].
func decide(state: FlappyFlightState) -> bool:
	if not state.flying:
		_taps.clear()
		return state.ready

	if _taps.is_empty():
		_replan(state, [])
	else:
		var tap := _rule(_plan_end)
		_taps.append(tap)
		if _flight.step(_plan_end, tap) & FlappyFlight.EVENT_HIT != 0:
			_repair(state)
	return _taps.pop_front()


## Plans from [param state]: [param forced] first, then the rule. Returns whether it stays clear.
func _replan(state: FlappyFlightState, forced: Array[bool]) -> bool:
	_taps = []
	_plan_end = state.copy()
	var clear := true
	while _taps.size() < maxi(lookahead, forced.size()):
		var tap := forced[_taps.size()] if _taps.size() < forced.size() else _rule(_plan_end)
		_taps.append(tap)
		if _flight.step(_plan_end, tap) & FlappyFlight.EVENT_HIT != 0:
			clear = false
			break
	return clear


## Searches every tap sequence from [param state] for [member search_ticks] ticks, merging
## states that differ by less than [member merge_height] in place, at the same vertical speed
## and within half a second of boost, and plans
## the path that ends nearest the next gap's centre.
func _repair(state: FlappyFlightState) -> void:
	var layers: Array[Array] = [[[state.copy(), -1, false]]]
	for tick: int in search_ticks:
		var frontier: Array = layers.back()
		var seen := { }
		var next: Array = []
		for parent: int in frontier.size():
			for tap: bool in [false, true]:
				var child: FlappyFlightState = frontier[parent][0].copy()
				if _flight.step(child, tap) & FlappyFlight.EVENT_HIT != 0:
					continue
				# A boost changes how far along the course the same moment is.
				var height := roundi(child.y / merge_height)
				var along := roundi(child.x / merge_height)
				var boost := child.boost_ticks * 2 / FlappyFlightTuning.TICK_RATE
				var key := Vector4i(height, roundi(child.vertical_speed), along, boost)
				if seen.has(key):
					continue
				seen[key] = true
				next.append([child, parent, tap])
		if next.is_empty():
			break
		layers.append(next)

	var last: Array = layers.back()
	var best := 0
	var aim := _gap_centre(last[0][0])
	for index: int in last.size():
		if absf(last[index][0].y - aim) < absf(last[best][0].y - aim):
			best = index
	var taps: Array[bool] = []
	for layer: int in range(layers.size() - 1, 0, -1):
		taps.push_front(layers[layer][best][2])
		best = layers[layer][best][1]
	_replan(state, taps)


## The centre of the gap the hit box is in or meets next, or the start height past the last.
func _gap_centre(state: FlappyFlightState) -> float:
	for index: int in range(state.obstacle_index, _course.obstacles.size()):
		var obstacle := _course.obstacles[index]
		if obstacle.x_end + _half > state.x:
			return obstacle.gap_centre()
	return _course.start_y


## The rule alone: whether to tap now.
func _rule(state: FlappyFlightState) -> bool:
	if not state.flying:
		return state.ready

	var tick := FlappyFlightTuning.TICK
	var speed := _tuning.boosted_speed() if state.boost_ticks > 0 else _tuning.forward_speed
	var falling := maxf(state.vertical_speed - _tuning.gravity * tick, -_tuning.max_fall_speed)
	var next_x := state.x + speed * tick
	var next_y := state.y + falling * tick
	if next_y >= _floor(state, next_x) + margin:
		return false

	return not _arc_meets_stone(state, speed)


## The lowest the body centre may be at [param x] and still reach every gap ahead.
func _floor(state: FlappyFlightState, x: float) -> float:
	var lowest := _half
	var obstacles := _course.obstacles
	for index: int in range(state.obstacle_index, obstacles.size()):
		var obstacle := obstacles[index]
		if obstacle.x_end + _half <= x:
			continue

		var distance := maxf(obstacle.x_start - _half - x, 0.0)
		var bottom := obstacle.gap_bottom + _half
		if bottom - distance * _climb_per_metre <= _half:
			# Further obstacles only lie further away.
			if distance > 0.0 and distance * _climb_per_metre > state.y + 100.0:
				break
			continue
		lowest = maxf(lowest, bottom - distance * _climb_per_metre)
	return lowest


func _arc_meets_stone(state: FlappyFlightState, speed: float) -> bool:
	var tick := FlappyFlightTuning.TICK
	var x := state.x
	var y := state.y
	var vertical := _tuning.flap_velocity
	for step: int in arc_ticks:
		if step > 0:
			vertical = maxf(vertical - _tuning.gravity * tick, -_tuning.max_fall_speed)
		x += speed * tick
		y += vertical * tick
		for index: int in range(state.obstacle_index, _course.obstacles.size()):
			var obstacle := _course.obstacles[index]
			if obstacle.x_start - _half >= x:
				break
			if obstacle.x_end + _half > x and y > obstacle.gap_top - _half - margin:
				return true
	return false
