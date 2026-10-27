extends TestScript
## The GDScript flight against tests/fixtures/flappy_flight_runs.json, which the TypeScript
## flight must reproduce too (web/tests/flappy_flight/parity.test.mjs, decision 0047).
##
## Each run is a course, the ticks it lasts and the ticks it taps on. Its events and a SHA-256
## digest of every tick's exact state are what both sides must match. After a deliberate rule
## change, rewrite the fixture with
##   godot --headless --path . --script tests/flappy_flight_parity_test.gd -- --write-fixture
## On a mismatch, the trace is written under test-results/flappy_flight/ for a diff.

const FIXTURE := "res://tests/fixtures/flappy_flight_runs.json"
const TRACES := "res://test-results/flappy_flight"
const RACE_TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")

var tuning: FlappyFlightTuning = RACE_TUNING.flight


func _run() -> void:
	var courses := _courses()
	var runs := _runs(courses)
	if OS.get_cmdline_user_args().has("--write-fixture"):
		_write(courses, runs)
		return

	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check(expected != null, "The parity fixture loads"):
		return

	var same_tuning := _normal(expected.tuning) == _normal(tuning.to_dictionary())
	check(same_tuning, "The fixture holds the default flight tuning")
	for name: String in courses:
		var same_course := _normal(expected.courses[name]) == _normal(courses[name].to_dictionary())
		check(same_course, "The fixture holds course %s" % name)
	check(expected.runs.size() == runs.size(), "The fixture holds every run")
	for index: int in mini(runs.size(), expected.runs.size()):
		var run: Dictionary = runs[index]
		var fixture: Dictionary = expected.runs[index]
		var same: bool = (
			run.name == fixture.name and _normal(run.taps) == _normal(fixture.taps)
			and _normal(run.events) == _normal(fixture.events) and run.digest == fixture.digest
		)
		if not check(same, "Run %s matches the fixture" % run.name):
			DirAccess.make_dir_recursive_absolute(TRACES)
			var file := FileAccess.open("%s/%s.gd.txt" % [TRACES, run.name], FileAccess.WRITE)
			file.store_string(run.trace)


## Small courses aimed at each rule, and one generated course.
func _courses() -> Dictionary:
	var gaps := _course([[30.0, 17.0], [45.0, 15.0], [60.0, 19.0]])

	var coins := _course([[60.0, 10.0]])
	coins.pickups.append(_pickup(15.0, 18.5, 2.0))
	coins.pickups.append(_pickup(35.0, 18.5, 2.0))
	coins.pickups.append(_pickup(63.0, 10.0, 0.75))

	var low := _course([[20.0, 5.25]])

	var generated := FlappyRaceCourse.generate(1, RACE_TUNING).flight
	return { "gaps": gaps, "coins": coins, "low": low, "generated": generated }


func _runs(courses: Dictionary) -> Array[Dictionary]:
	var runs: Array[Dictionary] = []
	runs.append(_play("never_taps", courses, "gaps", 800, _never))
	runs.append(_play("respawns_and_falls", courses, "gaps", 1500, _respawn_only))
	runs.append(_play("spams_into_the_stone", courses, "gaps", 900, _spam))
	runs.append(_play("flies_the_gaps_then_drops", courses, "gaps", 900, _hover_gaps))
	runs.append(_play("hovers_through_coins", courses, "coins", 900, _hover.bind(17.0)))
	runs.append(_play("rests_while_invulnerable", courses, "low", 600, _respawn_only))

	var pilot := FlappyFlightAutopilot.new(tuning, courses.generated)
	var autopilot := func(state: FlappyFlightState, _tick: int) -> bool:
		return pilot.decide(state)
	runs.append(_play("autopilot_generated", courses, "generated", 7000, autopilot))
	return runs


## Plays [param ticks] ticks on [param course], asking [param policy] whether to tap, and
## records the run.
func _play(
	name: String,
	courses: Dictionary,
	course: String,
	ticks: int,
	policy: Callable,
) -> Dictionary:
	var flight := FlappyFlight.new(tuning, courses[course])
	var state := flight.new_state()
	var taps: Array[int] = []
	var events: Array = []
	var trace := PackedStringArray()
	for tick: int in ticks:
		var tap: bool = policy.call(state, tick)
		if tap:
			taps.append(tick)
		var happened := flight.step(state, tap)
		if happened & ~FlappyFlight.EVENT_FLAP != 0:
			events.append([tick, happened])
		trace.append(_trace_line(state, happened))

	var text := "\n".join(trace) + "\n"
	return {
		"name": name,
		"course": course,
		"ticks": ticks,
		"taps": taps,
		"events": events,
		"digest": text.sha256_text(),
		"trace": text,
	}


## Every field of the state, the floats as the hex of their 64-bit little-endian bytes.
static func _trace_line(state: FlappyFlightState, events: int) -> String:
	var floats := PackedFloat64Array([state.x, state.y, state.vertical_speed])
	var bits := floats.to_byte_array().hex_encode()
	var counters := [
		int(state.flying),
		int(state.ready),
		state.cooldown_ticks,
		state.invulnerable_ticks,
		state.boost_ticks,
		state.obstacle_index,
		state.hearts.full,
		state.hearts.refill_ticks,
		int(state.hearts.owed),
		events,
	]
	var numbers := counters.map(
		func(value: int) -> String:
			return str(value),
	)
	return "%s %s %s" % [bits, " ".join(numbers), state.taken.hex_encode()]


## Compares JSON values as the fixture stores them, where every number reads back as a float.
static func _normal(value: Variant) -> String:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value, "", true, true))
	return JSON.stringify(parsed, "", true, true)


## One line per course and per run, with full-precision floats.
func _write(courses: Dictionary, runs: Array[Dictionary]) -> void:
	var lines := PackedStringArray(["{", '"tuning": %s,' % _json(tuning.to_dictionary())])
	lines.append('"courses": {')
	var names := courses.keys()
	for index: int in names.size():
		var course: Dictionary = courses[names[index]].to_dictionary()
		var comma := "," if index < names.size() - 1 else ""
		lines.append('"%s": %s%s' % [names[index], _json(course), comma])
	lines.append("},")
	lines.append('"runs": [')
	for index: int in runs.size():
		var kept: Dictionary = runs[index].duplicate()
		kept.erase("trace")
		lines.append(_json(kept) + ("," if index < runs.size() - 1 else ""))
	lines.append("]")
	lines.append("}")
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("Wrote %s" % FIXTURE)


static func _json(value: Variant) -> String:
	return JSON.stringify(value, "", false, true)


func _never(_state: FlappyFlightState, _tick: int) -> bool:
	return false


func _respawn_only(state: FlappyFlightState, _tick: int) -> bool:
	return state.ready


func _spam(state: FlappyFlightState, tick: int) -> bool:
	return state.ready or tick % 6 == 0


func _hover(state: FlappyFlightState, _tick: int, height: float) -> bool:
	return state.ready or (state.y < height and state.vertical_speed <= 0.0)


## Hovers at the centre of the next gap until past the last obstacle, then stops flapping.
func _hover_gaps(state: FlappyFlightState, _tick: int) -> bool:
	if state.ready:
		return true
	var centres := [[36.8, 17.0], [51.8, 15.0], [66.8, 19.0]]
	for entry: Array in centres:
		if state.x < entry[0]:
			return state.y < entry[1] and state.vertical_speed <= 0.0
	return false


func _course(pairs: Array) -> FlappyFlightCourse:
	var course := FlappyFlightCourse.new()
	course.start_y = 17.0
	course.finish_x = 200.0
	for pair: Array in pairs:
		var obstacle := FlappyFlightObstacle.new()
		obstacle.x_start = pair[0]
		obstacle.x_end = pair[0] + 6.0
		obstacle.gap_bottom = pair[1] - 4.25
		obstacle.gap_top = pair[1] + 4.25
		obstacle.respawn_x = pair[0] - 2.0
		obstacle.respawn_y = pair[1]
		course.obstacles.append(obstacle)
	return course


func _pickup(x: float, y: float, half_size: float) -> FlappyFlightPickup:
	var pickup := FlappyFlightPickup.new()
	pickup.x = x
	pickup.y = y
	pickup.half_size = half_size
	return pickup
