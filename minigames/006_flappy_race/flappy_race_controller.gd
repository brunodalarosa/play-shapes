class_name FlappyRaceController
extends Node
## Host-owned rules of one Flappy Race: the countdown, every player's flight, finishing,
## ranking, the race timer and disconnects. The protocol and the presentation are callers; no
## phone message changes a flight except through a tap.
##
## Every flight is stepped together at the settled tick, one tap window behind the race clock
## (decision 0048). A tap carries the tick the phone applied it at and waits until the
## simulation reaches it, so everything this controller reports is final.

signal phase_changed(phase: StringName)
## [param kind] is go, flap, hit, heart_refilled, ready, respawn, pickup, finish, dnf,
## last_seconds or results. [param player_id] is empty for the race-wide kinds.
signal race_event(kind: StringName, player_id: String, data: Dictionary)
## After every settled tick, once each flight has been stepped.
signal tick_settled(tick: int)

enum Phase {
	IDLE,
	COUNTDOWN,
	RACING,
	RESULTS,
}

const PHASE_NAMES: Array[StringName] = [&"idle", &"countdown", &"racing", &"results"]
const MAX_PLAYERS := 10
## The shared step's event bits, by the kind each is reported as.
const STEP_EVENTS: Dictionary[int, StringName] = {
	FlappyFlight.EVENT_FLAP: &"flap",
	FlappyFlight.EVENT_HIT: &"hit",
	FlappyFlight.EVENT_HEART_REFILLED: &"heart_refilled",
	FlappyFlight.EVENT_READY: &"ready",
	FlappyFlight.EVENT_RESPAWN: &"respawn",
	FlappyFlight.EVENT_PICKUP: &"pickup",
}

@export var tuning: FlappyRaceTuning = preload(
	"res://minigames/006_flappy_race/tuning/Default.tres"
)

var phase: Phase = Phase.IDLE
var course: FlappyRaceCourse
## Ticks since GO that every flight has been stepped through.
var settled_tick := 0
var _flight: FlappyFlight
var _racers: Dictionary[String, FlappyRaceRacer] = { }
var _order: Array[String] = []
var _go_msec := 0
var _last_msec := 0
var _window_ticks := 0
var _race_ticks := 0
var _last_seconds_tick := 0
var _finishers := 0
var _ranking: Array[FlappyRaceRacer] = []


func _ready() -> void:
	set_process(false)
	var session_host := get_node_or_null("/root/SessionHost")
	if session_host != null:
		var active: ActivePresets = session_host.get("active_presets")
		if active != null and active.flappy_race != null:
			tuning = active.flappy_race


func _process(_delta: float) -> void:
	advance(Time.get_ticks_msec())


## Starts the countdown for [param participants], registry player dictionaries, on the course
## generated from [param seed_value]. The same seed also orders exact ties.
func start_race(participants: Array, seed_value: int, host_msec: int) -> Dictionary:
	if phase != Phase.IDLE:
		return _reject(&"race_already_started")
	if tuning == null or not tuning.validation_errors().is_empty():
		return _reject(&"invalid_tuning")
	if participants.is_empty() or participants.size() > MAX_PLAYERS or host_msec < 0:
		return _reject(&"invalid_participants")

	course = FlappyRaceCourse.generate(seed_value, tuning)
	_flight = FlappyFlight.new(tuning.flight, course.flight)
	var tie_breaks := RandomNumberGenerator.new()
	tie_breaks.seed = seed_value
	var joined: Dictionary[String, FlappyRaceRacer] = { }
	var order: Array[String] = []
	for index: int in participants.size():
		var source: Variant = participants[index]
		if not source is Dictionary or typeof(source.get("player_id")) != TYPE_STRING:
			return _reject(&"invalid_participants")
		var player_id: String = source.player_id
		if player_id.is_empty() or joined.has(player_id):
			return _reject(&"invalid_participants")

		var racer := FlappyRaceRacer.new()
		racer.player_id = player_id
		racer.display_name = String(source.get("name", ""))
		racer.character_color = CharacterSelection.for_player(source).character_color
		racer.seat = int(source.get("seat", index + 1))
		racer.connected = source.get("state", "connected") == "connected"
		racer.state = _flight.new_state()
		racer.reported_taken.resize(racer.state.taken.size())
		racer.tie_break = tie_breaks.randf()
		joined[player_id] = racer
		order.append(player_id)

	_racers = joined
	_order = order
	_window_ticks = FlappyRaceTuning.ticks(tuning.tap_window_seconds)
	_race_ticks = FlappyRaceTuning.ticks(tuning.race_seconds)
	_last_seconds_tick = _race_ticks - FlappyRaceTuning.ticks(tuning.last_seconds)
	_go_msec = host_msec + roundi(tuning.countdown_seconds * 1000.0)
	_last_msec = host_msec
	_transition(Phase.COUNTDOWN)
	set_process(true)
	return { "accepted": true }


## Moves the race to [param host_msec]: GO when the countdown ends, then every flight up to
## the settled tick.
func advance(host_msec: int) -> void:
	if phase == Phase.IDLE or phase == Phase.RESULTS or host_msec < _last_msec:
		return

	_last_msec = host_msec
	if phase == Phase.COUNTDOWN and host_msec >= _go_msec:
		_transition(Phase.RACING)
		race_event.emit(&"go", "", { "tick": 0 })
		# A race nobody can hold open ends at once.
		_end_if_decided()

	var target := mini(clock_tick() - _window_ticks, _race_ticks)
	while phase == Phase.RACING and settled_tick < target:
		_settle_next_tick()


## A tap from [param player_id]'s phone, applied at [param tick] clamped into the tap window.
## Returns the tick it will apply at, or [code]applied: false[/code] for a tap that does
## nothing, which is dropped without an error (decision 0014).
func submit_tap(player_id: String, seq: int, tick: int, host_msec: int) -> Dictionary:
	advance(host_msec)
	var racer: FlappyRaceRacer = _racers.get(player_id)
	if racer == null:
		return _reject(&"unknown_player")
	if phase != Phase.RACING or not racer.racing() or seq <= racer.last_seq:
		return { "accepted": true, "applied": false }

	racer.last_seq = seq
	var earliest := settled_tick + 1
	var applied := clampi(tick, earliest, maxi(clock_tick(), earliest))
	racer.taps[applied] = true
	return { "accepted": true, "applied": true, "tick": applied }


## Pass the full registry roster. A missing player is gone for good; reconnecting ones freeze.
func observe_registry(players: Array, host_msec: int) -> void:
	advance(host_msec)
	if phase != Phase.COUNTDOWN and phase != Phase.RACING:
		return

	var present: Dictionary[String, bool] = { }
	for raw: Variant in players:
		if not raw is Dictionary or not _racers.has(String(raw.get("player_id", ""))):
			continue
		var racer := _racers[String(raw.player_id)]
		present[racer.player_id] = true
		_set_connected(racer, raw.get("state", "reconnecting") == "connected")

	for player_id: String in _order:
		var racer := _racers[player_id]
		if present.has(player_id) or racer.dnf:
			continue
		racer.connected = false
		racer.taps.clear()
		if not racer.finished():
			racer.dnf = true
			race_event.emit(&"dnf", player_id, { "tick": settled_tick })
	_end_if_decided()


func phase_name() -> StringName:
	return PHASE_NAMES[phase]


## Whole ticks since GO by the host's clock; negative during the countdown.
func clock_tick() -> int:
	return floori(float(_last_msec - _go_msec) * FlappyFlightTuning.TICK_RATE / 1000.0)


## Milliseconds from the last advance to GO; zero once the race runs.
func countdown_remaining_msec() -> int:
	return maxi(0, _go_msec - _last_msec)


func race_ticks() -> int:
	return _race_ticks


func last_seconds_tick() -> int:
	return _last_seconds_tick


func window_ticks() -> int:
	return _window_ticks


func racer_for(player_id: String) -> FlappyRaceRacer:
	return _racers.get(player_id)


func racers() -> Array[FlappyRaceRacer]:
	var ordered: Array[FlappyRaceRacer] = []
	for player_id: String in _order:
		ordered.append(_racers[player_id])
	return ordered


## The final order, first place first; empty until the results.
func ranking() -> Array[FlappyRaceRacer]:
	return _ranking.duplicate()


## Finishers by finish order, then everyone else by distance, then players who are gone. Exact
## ties fall to each racer's random tie break (decision 0050), so every place is distinct.
static func rank(racers_to_rank: Array[FlappyRaceRacer]) -> Array[FlappyRaceRacer]:
	var ordered := racers_to_rank.duplicate()
	ordered.sort_custom(
		func(a: FlappyRaceRacer, b: FlappyRaceRacer) -> bool:
			var a_group := _rank_group(a)
			var b_group := _rank_group(b)
			if a_group != b_group:
				return a_group < b_group
			if a.finished() and a.place != b.place:
				return a.place < b.place
			if not a.finished() and not a.dnf and a.distance() != b.distance():
				return a.distance() > b.distance()
			return a.tie_break < b.tie_break,
	)
	return ordered


## Finishers first, then players still racing or frozen, then players who are gone.
static func _rank_group(racer_to_group: FlappyRaceRacer) -> int:
	if racer_to_group.finished():
		return 0
	return 2 if racer_to_group.dnf else 1


func _settle_next_tick() -> void:
	settled_tick += 1
	var crossed: Array[FlappyRaceRacer] = []
	for player_id: String in _order:
		var racer := _racers[player_id]
		if not racer.racing():
			continue

		var events := _flight.step(racer.state, racer.taps.erase(settled_tick))
		if events != 0:
			_report_step(racer, events)
		if racer.state.x >= course.flight.finish_x:
			crossed.append(racer)

	# Players crossing in the same tick are ordered at random (decision 0050).
	crossed.sort_custom(
		func(a: FlappyRaceRacer, b: FlappyRaceRacer) -> bool:
			return a.tie_break < b.tie_break,
	)
	for racer: FlappyRaceRacer in crossed:
		_finishers += 1
		racer.finish_tick = settled_tick
		racer.place = _finishers
		racer.taps.clear()
		race_event.emit(&"finish", racer.player_id, { "tick": settled_tick, "place": racer.place })

	if settled_tick == _last_seconds_tick:
		race_event.emit(&"last_seconds", "", { "tick": settled_tick })
	tick_settled.emit(settled_tick)
	_end_if_decided()


func _report_step(racer: FlappyRaceRacer, events: int) -> void:
	for bit: int in STEP_EVENTS:
		if events & bit == 0:
			continue
		var data := { "tick": settled_tick }
		if bit == FlappyFlight.EVENT_PICKUP:
			data.pickup = racer.newly_taken()
		race_event.emit(STEP_EVENTS[bit], racer.player_id, data)


## Freezes a disconnected flight; a resumed one waits, ready, where it froze.
func _set_connected(racer: FlappyRaceRacer, connected: bool) -> void:
	if racer.dnf or racer.connected == connected:
		return

	racer.connected = connected
	racer.taps.clear()
	if not connected or phase != Phase.RACING or racer.finished() or not racer.state.flying:
		return

	# Returning costs no heart: the player taps to respawn at the frozen spot.
	var state := racer.state
	state.flying = false
	state.ready = true
	state.vertical_speed = 0.0
	state.cooldown_ticks = 0
	state.boost_ticks = 0
	state.invulnerable_ticks = 0
	race_event.emit(&"ready", racer.player_id, { "tick": settled_tick })


## Ends the race when the timer runs out or nobody can still hold it open.
func _end_if_decided() -> void:
	if phase != Phase.RACING:
		return

	var open := false
	for player_id: String in _order:
		var racer := _racers[player_id]
		if not racer.finished() and not racer.dnf:
			open = true
			break
	if open and settled_tick < _race_ticks:
		return

	_ranking = rank(racers())
	_transition(Phase.RESULTS)
	set_process(false)
	race_event.emit(&"results", "", { "tick": settled_tick })


func _transition(next: Phase) -> void:
	phase = next
	phase_changed.emit(phase_name())


func _reject(code: StringName) -> Dictionary:
	return { "accepted": false, "code": code, "message": "Flappy Race: %s" % code }
