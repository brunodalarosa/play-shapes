extends TestScript
## The Flappy Race protocol: tap validation, the snapshot with the course, each phone's own
## settled state at 20 Hz, events sent to the right phones, results and resuming.

const TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")
const START_MSEC := 1000
const GO_MSEC := 4000

var _controller: FlappyRaceController
var _protocol: FlappyRaceProtocol
## Every message sent, as [player ID, message, coalesce].
var _sent: Array[Array] = []
var _broadcasts := 0


func _run() -> void:
	_controller = FlappyRaceController.new()
	_controller.tuning = TUNING
	var players: Array[Dictionary] = [
		{ "player_id": "p0", "name": "Ana", "seat": 1 },
		{ "player_id": "p1", "name": "Bo", "seat": 2 },
	]
	_controller.start_race(players, 3, START_MSEC)
	_protocol = FlappyRaceProtocol.new(_controller)
	_protocol.send_requested.connect(
		func(player_id: String, message: Dictionary, coalesce: bool) -> void:
			_sent.append([player_id, message, coalesce]),
	)
	_protocol.broadcast_requested.connect(
		func() -> void:
			_broadcasts += 1,
	)

	_check_snapshot()
	_check_tap_validation()
	_check_state_and_events()
	_check_resume_and_results()
	_protocol.detach()
	_controller.free()


func _check_snapshot() -> void:
	var snapshot := _protocol.snapshot_for("p0")
	var size := JSON.stringify(snapshot).length()
	print("Flappy Race snapshot: %d bytes" % size)
	check(
		snapshot.type == "flappy_race_snapshot" and snapshot.phase == "countdown"
		and snapshot.player_count == 2 and snapshot.countdown_remaining_msec == 3000
		and snapshot.window_ticks == 15 and snapshot.race_ticks == 21600
		and snapshot.flight == TUNING.flight.to_dictionary()
		and snapshot.view == TUNING.view.to_dictionary()
		and snapshot.character_color == _controller.racer_for("p0").character_color
		and snapshot.course.flight.obstacles.size() == _controller.course.flight.obstacles.size()
		and snapshot.own.flight.y == _controller.course.flight.start_y,
		"The snapshot carries the timings, the flight and view tuning, "
		+ "the course and the own flight",
	)
	check(size < 24000, "The snapshot with the whole course stays small")
	check(
		_protocol.snapshot_for("stranger").type == "lobby",
		"A player outside the race gets the default snapshot",
	)


func _check_tap_validation() -> void:
	var player := { "player_id": "p0" }
	var cases := [
		[{ }, { "type": "flappy_tap", "seq": 0, "tick": 0 }, &"not_joined"],
		[player, { "type": "flappy_tap", "seq": 0, "tick": 0, "x": 1 }, &"unauthorized_field"],
		[player, { "type": "flappy_tap", "seq": -1, "tick": 0 }, &"invalid_tap"],
		[player, { "type": "flappy_tap", "seq": 1.5, "tick": 0 }, &"invalid_tap"],
		[player, { "type": "flappy_tap", "seq": 0, "tick": "3" }, &"invalid_tap"],
		[player, { "type": "flappy_tap", "seq": 0 }, &"invalid_tap"],
		[
			{ "player_id": "stranger" },
			{ "type": "flappy_tap", "seq": 0, "tick": 0 },
			&"unknown_player",
		],
	]
	for entry: Array in cases:
		var result := _protocol.handle_message(entry[0], entry[1], 2000)
		check(
			not result.accepted and result.code == entry[2],
			"A malformed tap is rejected as %s" % entry[2],
		)

	var countdown_tap := _protocol.handle_message(
		player,
		{ "type": "flappy_tap", "seq": 0, "tick": 0 },
		2000,
	)
	check(
		_protocol.handles("flappy_tap") and countdown_tap.accepted,
		"A well-formed tap during the countdown is accepted and dropped",
	)


func _check_state_and_events() -> void:
	_controller.advance(GO_MSEC)
	var go := _messages("p1", "flappy_race_event")
	check(
		go.size() == 1 and go[0].event == "go" and _messages("p0", "flappy_race_event").size() == 1,
		"GO reaches every phone",
	)

	_sent.clear()
	_settle(30)
	var tap := _protocol.handle_message(
		{ "player_id": "p0" },
		{ "type": "flappy_tap", "seq": 1, "tick": 40 },
		_msec(45),
	)
	_settle(60)
	var states := _messages("p0", "flappy_race_state")
	var coalesced := _sent.all(
		func(entry: Array) -> bool:
			return entry[1].type != "flappy_race_state" or entry[2],
	)
	print("Flappy Race state: %d bytes" % JSON.stringify(states[0]).length())
	check(
		states.size() == 20 and _messages("p1", "flappy_race_state").size() == 20 and coalesced,
		"Each phone gets its own settled flight 20 times a second, coalesced",
	)
	check(
		states[-1].tick == 60 and states[-1].clock_tick == 75
		and states[-1].own.flight.x == _controller.racer_for("p0").state.x,
		"The state carries its settled tick, the host's clock and the exact flight",
	)
	check(JSON.stringify(states[0]).length() < 400, "A state message stays small")

	var p0_events := _events("p0")
	var p1_hits := _messages("p1", "flappy_race_event").filter(
		func(message: Dictionary) -> bool:
			return message.event == "hit",
	)
	check(tap.accepted and "hit" not in p0_events, "A tap keeps p0 flying")
	check(
		p1_hits.size() == 1 and not p1_hits[0].own.flight.flying,
		"A hit reaches only its own phone, with the settled flight",
	)


func _check_resume_and_results() -> void:
	var now := _msec(60 + _controller.window_ticks())
	_controller.observe_registry(
		[
			{ "player_id": "p0", "state": "reconnecting" },
			{ "player_id": "p1", "state": "connected" },
		],
		now,
	)
	_sent.clear()
	_settle(200)
	check(_messages("p0", "flappy_race_state").is_empty(), "A disconnected phone gets no state")

	now = _msec(200 + _controller.window_ticks())
	_controller.observe_registry(
		[{ "player_id": "p0", "state": "connected" }, { "player_id": "p1", "state": "connected" }],
		now,
	)
	var resumed := _protocol.snapshot_for("p0")
	check(
		resumed.phase == "racing" and resumed.tick == 200 and resumed.own.flight.ready
		and not resumed.own.flight.flying and resumed.own.flight.hearts.full == 3,
		"A resumed phone's snapshot waits ready at the frozen spot, with every heart",
	)

	var winner := _controller.racer_for("p0")
	winner.state.flying = true
	winner.state.x = _controller.course.flight.finish_x - 0.05
	_sent.clear()
	_settle(201)
	var finish := _messages("p0", "flappy_race_event")
	check(
		finish.size() == 1 and finish[0].event == "finish" and finish[0].place == 1,
		"The finisher's phone hears its place",
	)

	_controller.observe_registry([{ "player_id": "p0", "state": "connected" }], now)
	var results: Array = _protocol.snapshot_for("p0").get("results", [])
	check(
		_broadcasts == 1 and results.size() == 2 and results[0].player_id == "p0"
		and results[0].finish_msec == roundi(201 * 1000.0 / 60.0)
		and results[1].dnf and results[1].place == 2,
		"The results reach every phone in a fresh snapshot",
	)


func _settle(tick: int) -> void:
	_controller.advance(_msec(tick + _controller.window_ticks()))


func _msec(tick: int) -> int:
	return GO_MSEC + ceili(tick * 1000.0 / FlappyFlightTuning.TICK_RATE)


func _events(player_id: String) -> Array:
	return _messages(player_id, "flappy_race_event").map(
		func(message: Dictionary) -> String:
			return message.event,
	)


func _messages(player_id: String, type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Array in _sent:
		if entry[0] == player_id and entry[1].type == type:
			found.append(entry[1])
	return found
