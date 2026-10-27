extends TestScript
## A scripted ten-player Flappy Race on a short course reaches its stop condition both ways:
## everyone finishes, and the race timer runs out. Autopilots fly through the controller with
## every tap arriving a whole tap window late, and each flies exactly the run it flies alone.
## They start tapping at different times, so some hit the ground and respawn first.

const TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")
const SEED := 42
const START_MSEC := 500
const PLAYERS := 10
## Ticks each player waits before its first tap; past about 50 the Cubio hits the ground.
const DELAY_STEP := 20


func _run() -> void:
	var tuning: FlappyRaceTuning = TUNING.duplicate(true)
	tuning.course.perfect_run_seconds = 20.0
	tuning.race_seconds = 60.0
	if not check(tuning.validation_errors().is_empty(), "The short race tuning is valid"):
		return
	_check_everyone_finishes(tuning)

	tuning.race_seconds = 8.0
	tuning.last_seconds = 2.0
	_check_timer_runs_out(tuning)


func _check_everyone_finishes(tuning: FlappyRaceTuning) -> void:
	var controller := _open_race(tuning)
	var hit: Dictionary[String, bool] = { }
	controller.race_event.connect(
		func(kind: StringName, player_id: String, _data: Dictionary) -> void:
			if kind == &"respawn":
				hit[player_id] = true,
	)
	var pilots := _pilots(controller)
	var last_tick := 0
	while controller.phase_name() == &"racing" and controller.settled_tick < 3600:
		_tick(controller, pilots)

	var expected := _solo_finish_ticks(controller)
	var all_match := true
	for index: int in PLAYERS:
		var racer := controller.racers()[index]
		all_match = all_match and racer.finish_tick == expected[index]
		last_tick = maxi(last_tick, racer.finish_tick)
	check(
		controller.phase_name() == &"results" and controller.settled_tick == last_tick,
		"The race ends in the tick the last of ten players finishes",
	)
	check(all_match, "Every late tap flies exactly the run of an on-time tap")
	check(hit.size() >= 3, "Some players hit the ground, respawned and still finished")

	var ranking := controller.ranking()
	var in_order := true
	for index: int in ranking.size():
		in_order = in_order and ranking[index].place == index + 1
		if index > 0:
			in_order = in_order and ranking[index].finish_tick >= ranking[index - 1].finish_tick
	check(in_order, "The ranking follows finish time, every place distinct")
	controller.free()


func _check_timer_runs_out(tuning: FlappyRaceTuning) -> void:
	var controller := _open_race(tuning)
	var last_seconds: Array[int] = []
	controller.race_event.connect(
		func(kind: StringName, _player_id: String, data: Dictionary) -> void:
			if kind == &"last_seconds":
				last_seconds.append(int(data.tick)),
	)
	var pilots := _pilots(controller)
	while controller.phase_name() == &"racing" and controller.settled_tick < 3600:
		if controller.settled_tick == 100:
			controller.observe_registry(_roster("p3", ""), _now(controller))
		if controller.settled_tick == 200:
			controller.observe_registry(_roster("p3", "p5"), _now(controller))
		_tick(controller, pilots)

	check(
		controller.phase_name() == &"results" and controller.settled_tick == 480,
		"The race ends when the 8 s timer runs out",
	)
	check(last_seconds == [360], "The last 2 seconds are announced once, 2 s before the end")

	var ranking := controller.ranking()
	var finished := ranking.filter(
		func(racer: FlappyRaceRacer) -> bool:
			return racer.finished(),
	)
	var by_distance := true
	for index: int in range(1, ranking.size() - 1):
		by_distance = by_distance and ranking[index].distance() <= ranking[index - 1].distance()
	check(finished.is_empty(), "Nobody finishes the 20 s course in 8 s")
	check(
		ranking[-1].player_id == "p3" and ranking[-1].dnf,
		"The player whose grace expired ranks last as DNF",
	)
	check(
		by_distance and not controller.racer_for("p5").connected,
		"Everyone else, the frozen player too, ranks by distance",
	)
	controller.free()


func _open_race(tuning: FlappyRaceTuning) -> FlappyRaceController:
	var controller := FlappyRaceController.new()
	controller.tuning = tuning
	var players: Array[Dictionary] = []
	for index: int in PLAYERS:
		players.append({ "player_id": "p%d" % index, "seat": index + 1 })
	controller.start_race(players, SEED, START_MSEC)
	controller.advance(_msec(controller, 0))
	return controller


func _pilots(controller: FlappyRaceController) -> Array[FlappyFlightAutopilot]:
	var pilots: Array[FlappyFlightAutopilot] = []
	for index: int in PLAYERS:
		pilots.append(FlappyFlightAutopilot.new(controller.tuning.flight, controller.course.flight))
	return pilots


## Each racer decides on its settled state and taps for the next tick, which reaches the host
## when its clock is already a whole window ahead. Then the next tick settles.
func _tick(controller: FlappyRaceController, pilots: Array[FlappyFlightAutopilot]) -> void:
	var tick := controller.settled_tick
	for index: int in PLAYERS:
		var racer := controller.racers()[index]
		if racer.racing() and tick >= index * DELAY_STEP and pilots[index].decide(racer.state):
			controller.submit_tap(racer.player_id, tick, tick + 1, _now(controller))
	controller.advance(_msec(controller, tick + 1 + controller.window_ticks()))


## The tick each racer finishes in flying alone with on-time taps.
func _solo_finish_ticks(controller: FlappyRaceController) -> Array[int]:
	var finish_ticks: Array[int] = []
	var flight := FlappyFlight.new(controller.tuning.flight, controller.course.flight)
	for index: int in PLAYERS:
		var pilot := FlappyFlightAutopilot.new(controller.tuning.flight, controller.course.flight)
		var state := flight.new_state()
		var tick := 0
		while state.x < controller.course.flight.finish_x and tick < 3600:
			var tap := tick >= index * DELAY_STEP and pilot.decide(state)
			flight.step(state, tap)
			tick += 1
		finish_ticks.append(tick)
	return finish_ticks


func _now(controller: FlappyRaceController) -> int:
	return _msec(controller, controller.settled_tick + controller.window_ticks())


func _msec(controller: FlappyRaceController, tick: int) -> int:
	var go := START_MSEC + roundi(controller.tuning.countdown_seconds * 1000.0)
	return go + ceili(tick * 1000.0 / FlappyFlightTuning.TICK_RATE)


## Everyone connected, without [param gone] and with [param frozen] reconnecting.
func _roster(gone: String, frozen: String) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for index: int in PLAYERS:
		var player_id := "p%d" % index
		if player_id != gone:
			var state := "reconnecting" if player_id == frozen else "connected"
			roster.append({ "player_id": player_id, "state": state })
	return roster
