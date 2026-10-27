extends TestScript
## The Flappy Race controller: the countdown, the tap window, freezing and resuming, players
## who leave or finish, and a ranking whose exact ties fall to a seeded random order.

const TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")
const SEED := 7
const START_MSEC := 1000
## The countdown is 3 s at the default tuning.
const GO_MSEC := 4000

var _controllers: Array[FlappyRaceController] = []
## Every race event, as [kind, player ID, tick].
var _events: Array[Array] = []


func _run() -> void:
	_check_countdown_and_window()
	_check_taps_in_one_tick()
	_check_freeze_and_resume()
	_check_resume_while_waiting()
	_check_leaving()
	_check_same_tick_finish()
	_check_ranking()
	for controller: FlappyRaceController in _controllers:
		controller.free()


func _check_countdown_and_window() -> void:
	var controller := _race(1)
	var window := controller.window_ticks()
	check(window == 15, "The default tap window is 250 ms, 15 ticks")
	check(
		controller.phase_name() == &"countdown" and controller.countdown_remaining_msec() == 3000,
		"The race opens on a 3 s countdown",
	)
	var early := controller.submit_tap("p0", 0, 0, 2000)
	check(early.accepted and not early.applied, "A tap during the countdown is dropped")

	controller.advance(GO_MSEC - 1)
	check(controller.phase_name() == &"countdown", "The countdown lasts until GO")
	controller.advance(GO_MSEC)
	check(
		controller.phase_name() == &"racing" and _ticks_of(&"go", "") == [0],
		"GO starts the race at tick 0",
	)

	controller.advance(_msec(60))
	check(controller.settled_tick == 60 - window, "Flights settle one window behind the clock")

	var inside := controller.submit_tap("p0", 1, 50, _msec(60))
	var ahead := controller.submit_tap("p0", 2, 70, _msec(60))
	var old := controller.submit_tap("p0", 3, 10, _msec(60))
	var repeated := controller.submit_tap("p0", 3, 55, _msec(60))
	check(inside.tick == 50, "A tap inside the window applies at its own tick")
	check(ahead.tick == 60, "A tap ahead of the host applies at the host's clock")
	check(old.tick == 46, "A tap older than the window applies at the next tick to settle")
	check(not repeated.applied, "A tap with a used sequence number is dropped")

	_settle(controller, 60)
	check(_ticks_of(&"flap", "p0") == [46, 50, 60], "Each tap flaps at the tick it applied at")


func _check_taps_in_one_tick() -> void:
	var controller := _race(1)
	controller.advance(_msec(20))
	controller.submit_tap("p0", 0, 10, _msec(20))
	controller.submit_tap("p0", 1, 10, _msec(20))
	_settle(controller, 12)
	check(_ticks_of(&"flap", "p0") == [10], "Several taps in one tick are one flap")


func _check_freeze_and_resume() -> void:
	var controller := _race(2)
	_settle(controller, 20)
	var frozen := controller.racer_for("p0")
	var x := frozen.state.x
	var y := frozen.state.y
	controller.observe_registry(_roster(["p0"], ["p1"]), _msec(20 + controller.window_ticks()))
	_settle(controller, 80)
	check(
		frozen.state.x == x and frozen.state.y == y and frozen.state.flying,
		"A disconnected flight freezes in place",
	)
	check(controller.racer_for("p1").state.x > x, "The others race on")
	var dropped := controller.submit_tap("p0", 0, 81, _msec(80 + controller.window_ticks()))
	check(not dropped.applied, "A frozen player's taps are dropped")

	controller.observe_registry(_roster([], ["p0", "p1"]), _msec(80 + controller.window_ticks()))
	check(
		not frozen.state.flying and frozen.state.ready and frozen.state.x == x
		and frozen.state.hearts.full == 3 and _ticks_of(&"ready", "p0") == [80],
		"A resumed flight waits at the same spot, ready, with no heart spent",
	)
	controller.submit_tap("p0", 1, 81, _msec(80 + controller.window_ticks()))
	_settle(controller, 81)
	check(
		frozen.state.flying and frozen.state.invulnerable_ticks > 0
		and _ticks_of(&"respawn", "p0") == [81],
		"The respawn tap flies on, invulnerable",
	)


func _check_resume_while_waiting() -> void:
	var controller := _race(1)
	var racer := controller.racer_for("p0")
	while racer.state.flying and controller.settled_tick < 200:
		_settle(controller, controller.settled_tick + 1)
	var hit_tick := controller.settled_tick
	check(_ticks_of(&"hit", "p0") == [hit_tick], "With no taps the Cubio hits the ground")

	_settle(controller, hit_tick + 30)
	var cooldown := racer.state.cooldown_ticks
	var refill := racer.state.hearts.refill_ticks
	var now := _msec(controller.settled_tick + controller.window_ticks())
	controller.observe_registry(_roster(["p0"], []), now)
	_settle(controller, hit_tick + 130)
	controller.observe_registry(
		_roster([], ["p0"]),
		_msec(controller.settled_tick + controller.window_ticks()),
	)
	check(
		not racer.state.flying and not racer.state.ready and racer.state.cooldown_ticks == cooldown
		and racer.state.hearts.full == 2 and racer.state.hearts.refill_ticks == refill,
		"A player resumed while waiting keeps the cooldown and refill that were left",
	)


func _check_leaving() -> void:
	var controller := _race(3)
	_settle(controller, 1)
	var winner := controller.racer_for("p0")
	winner.state.x = controller.course.flight.finish_x - 0.05
	_settle(controller, 2)
	check(winner.place == 1 and winner.finish_tick == 2, "Crossing the finish line places first")

	var now := _msec(2 + controller.window_ticks())
	controller.observe_registry(_roster(["p1"], ["p2"]), now)
	check(
		not winner.dnf and controller.phase_name() == &"racing",
		"A finisher who leaves keeps the finish; a player in grace holds the race open",
	)
	controller.observe_registry(_roster([], ["p1"]), now)
	check(controller.phase_name() == &"racing", "A player still racing holds the race open")
	controller.observe_registry(_roster([], []), now)
	var order := controller.ranking().map(
		func(racer: FlappyRaceRacer) -> String:
			return racer.player_id,
	)
	check(
		controller.phase_name() == &"results" and controller.racer_for("p1").dnf
		and order[0] == "p0" and _ticks_of(&"results", "") == [2],
		"Once nobody can hold it open, the race ends with the finisher first",
	)


func _check_same_tick_finish() -> void:
	var controller := _race(4)
	_settle(controller, 1)
	for racer: FlappyRaceRacer in controller.racers():
		racer.state.x = controller.course.flight.finish_x - 0.05
	_settle(controller, 2)
	var by_place := controller.racers()
	by_place.sort_custom(
		func(a: FlappyRaceRacer, b: FlappyRaceRacer) -> bool:
			return a.place < b.place,
	)
	var places := by_place.map(
		func(racer: FlappyRaceRacer) -> int:
			return racer.place,
	)
	var ordered := true
	for index: int in by_place.size() - 1:
		ordered = ordered and by_place[index].tie_break < by_place[index + 1].tie_break
	check(
		places == [1, 2, 3, 4] and ordered and controller.phase_name() == &"results",
		"Players crossing in one tick get distinct places in their random order",
	)

	var again := _race(4)
	var same := true
	for index: int in 4:
		same = same and again.racers()[index].tie_break == controller.racers()[index].tie_break
	check(same, "The same seed orders ties the same way")


func _check_ranking() -> void:
	var second := _ranked("second", 0.5)
	second.finish_tick = 900
	second.place = 2
	var first := _ranked("first", 0.9)
	first.finish_tick = 900
	first.place = 1
	var far := _ranked("far", 0.5, 300.0)
	var level_a := _ranked("level_a", 0.2, 100.0)
	var level_b := _ranked("level_b", 0.1, 100.0)
	var gone_far := _ranked("gone_far", 0.8, 900.0)
	gone_far.dnf = true
	var gone := _ranked("gone", 0.3)
	gone.dnf = true
	var frozen := _ranked("frozen", 0.4, 200.0)
	frozen.connected = false

	var racers: Array[FlappyRaceRacer] = [
		gone_far,
		level_a,
		second,
		frozen,
		gone,
		far,
		first,
		level_b,
	]
	var order := FlappyRaceController.rank(racers).map(
		func(racer: FlappyRaceRacer) -> String:
			return racer.player_id,
	)
	check(
		order == ["first", "second", "far", "frozen", "level_b", "level_a", "gone", "gone_far"],
		"Ranking: finish order, then distance, then gone; ties by the random tie break",
	)


func _race(count: int) -> FlappyRaceController:
	var controller := FlappyRaceController.new()
	controller.tuning = TUNING
	controller.race_event.connect(_record)
	var players: Array[Dictionary] = []
	for index: int in count:
		players.append({ "player_id": "p%d" % index, "name": "P%d" % index, "seat": index + 1 })
	controller.start_race(players, SEED, START_MSEC)
	_controllers.append(controller)
	_events.clear()
	return controller


func _ranked(player_id: String, tie_break: float, distance := 0.0) -> FlappyRaceRacer:
	var racer := FlappyRaceRacer.new()
	racer.player_id = player_id
	racer.tie_break = tie_break
	racer.state = FlappyFlightState.new()
	racer.state.x = distance
	return racer


## Advances the clock so every flight has settled [param tick].
func _settle(controller: FlappyRaceController, tick: int) -> void:
	controller.advance(_msec(tick + controller.window_ticks()))


## The first host time at which the race clock reads [param tick].
func _msec(tick: int) -> int:
	return GO_MSEC + ceili(tick * 1000.0 / FlappyFlightTuning.TICK_RATE)


func _roster(reconnecting: Array[String], connected: Array[String]) -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for player_id: String in reconnecting:
		roster.append({ "player_id": player_id, "state": "reconnecting" })
	for player_id: String in connected:
		roster.append({ "player_id": player_id, "state": "connected" })
	return roster


func _record(kind: StringName, player_id: String, data: Dictionary) -> void:
	_events.append([kind, player_id, int(data.tick)])


func _ticks_of(kind: StringName, player_id: String) -> Array[int]:
	var ticks: Array[int] = []
	for event: Array in _events:
		if event[0] == kind and event[1] == player_id:
			ticks.append(event[2])
	return ticks
