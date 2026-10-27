class_name FlappyRaceProtocol
extends MinigameProtocol
## The phones' side of a Flappy Race. A phone sends its taps with the simulation tick it applied
## them at (decision 0048). It receives the course in its snapshot, its own settled flight a few
## times a second, the events of its own flight and the race's, and the results.
##
## Client message:
## - flappy_tap: seq, a whole number increasing per player, and tick, the whole simulation tick
##   since GO the phone applied the tap at.

const SNAPSHOT_TYPE := "flappy_race_snapshot"
const STATE_TYPE := "flappy_race_state"
const EVENT_TYPE := "flappy_race_event"
const TAP_TYPE := "flappy_tap"
const MAX_WHOLE := 9_007_199_254_740_991
## Events of one player's flight, sent to that player only. Flaps are the phone's own.
const OWN_EVENTS: Array[StringName] = [
	&"hit",
	&"heart_refilled",
	&"ready",
	&"respawn",
	&"pickup",
	&"finish",
]
## Events every phone hears. The results reach every phone in a fresh snapshot.
const RACE_EVENTS: Array[StringName] = [&"go", &"last_seconds"]

var controller: FlappyRaceController
var _state_every := 1


func _init(race: FlappyRaceController) -> void:
	controller = race
	_state_every = maxi(1, FlappyFlightTuning.TICK_RATE / race.tuning.state_hz)
	controller.race_event.connect(_on_race_event)
	controller.tick_settled.connect(_on_tick_settled)


func handles(message_type: String) -> bool:
	return message_type == TAP_TYPE


func handle_message(player: Dictionary, message: Dictionary, host_msec: int) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return _reject(&"game_unavailable")
	if player.is_empty() or not player.has("player_id"):
		return _reject(&"not_joined")
	for key: Variant in message.keys():
		if key not in ["type", "seq", "tick"]:
			return _reject(&"unauthorized_field")

	var seq := _whole(message.get("seq"))
	var tick := _whole(message.get("tick"))
	if seq < 0 or tick < 0:
		return _reject(&"invalid_tap")
	var result := controller.submit_tap(String(player.player_id), seq, tick, host_msec)
	if not result.accepted:
		return _reject(StringName(result.code))
	return { "accepted": true }


func snapshot_for(player_id: String) -> Dictionary:
	if controller == null or not is_instance_valid(controller):
		return super(player_id)
	var racer := controller.racer_for(player_id)
	if racer == null:
		return super(player_id)

	var snapshot := {
		"type": SNAPSHOT_TYPE,
		"character_color": racer.character_color,
		"phase": str(controller.phase_name()),
		"player_count": controller.racers().size(),
		"tick_rate": FlappyFlightTuning.TICK_RATE,
		"tick": controller.settled_tick,
		"clock_tick": controller.clock_tick(),
		"countdown_remaining_msec": controller.countdown_remaining_msec(),
		"window_ticks": controller.window_ticks(),
		"race_ticks": controller.race_ticks(),
		"last_seconds_tick": controller.last_seconds_tick(),
		"flight": controller.tuning.flight.to_dictionary(),
		"view": controller.tuning.view.to_dictionary(),
		"course": controller.course.to_dictionary(),
		"own": _own(racer),
	}
	if controller.phase == FlappyRaceController.Phase.RESULTS:
		snapshot.results = _results()
		for entry: Dictionary in snapshot.results:
			if entry.player_id == player_id:
				snapshot.own_result = entry
	return snapshot


func detach() -> void:
	if controller == null or not is_instance_valid(controller):
		return
	if controller.race_event.is_connected(_on_race_event):
		controller.race_event.disconnect(_on_race_event)
	if controller.tick_settled.is_connected(_on_tick_settled):
		controller.tick_settled.disconnect(_on_tick_settled)


func _on_tick_settled(tick: int) -> void:
	if tick % _state_every != 0:
		return
	for racer: FlappyRaceRacer in controller.racers():
		if racer.racing():
			send_requested.emit(racer.player_id, _state(racer), true)


func _on_race_event(kind: StringName, player_id: String, data: Dictionary) -> void:
	if kind == &"results":
		broadcast_requested.emit()
		return

	if kind in RACE_EVENTS:
		for racer: FlappyRaceRacer in controller.racers():
			send_requested.emit(racer.player_id, _event(kind, data, null), false)
	elif kind in OWN_EVENTS:
		var racer := controller.racer_for(player_id)
		send_requested.emit(player_id, _event(kind, data, racer), false)


## [param racer] adds that player's settled flight, so the phone can correct itself at once.
func _event(kind: StringName, data: Dictionary, racer: FlappyRaceRacer) -> Dictionary:
	var message := data.duplicate()
	message.type = EVENT_TYPE
	message.event = str(kind)
	if racer != null:
		message.own = _own(racer)
	return message


func _state(racer: FlappyRaceRacer) -> Dictionary:
	return {
		"type": STATE_TYPE,
		"tick": controller.settled_tick,
		"clock_tick": controller.clock_tick(),
		"own": _own(racer),
	}


func _own(racer: FlappyRaceRacer) -> Dictionary:
	return {
		"flight": racer.state.to_dictionary(),
		"last_seq": racer.last_seq,
		"connected": racer.connected,
		"place": racer.place,
		"finish_tick": racer.finish_tick,
		"dnf": racer.dnf,
	}


func _results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for index: int in controller.ranking().size():
		var racer := controller.ranking()[index]
		var finish_msec := -1
		if racer.finished():
			finish_msec = roundi(racer.finish_tick * 1000.0 / FlappyFlightTuning.TICK_RATE)
		results.append(
			{
				"player_id": racer.player_id,
				"name": racer.display_name,
				"character_color": racer.character_color,
				"place": index + 1,
				"finished": racer.finished(),
				"finish_msec": finish_msec,
				"distance": racer.distance(),
				"dnf": racer.dnf,
			}
		)
	return results


## A whole, non-negative number, or -1.
static func _whole(raw: Variant) -> int:
	if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
		return -1
	var number := float(raw)
	if not is_finite(number) or number < 0.0 or number > MAX_WHOLE or floorf(number) != number:
		return -1
	return int(number)


func _reject(code: StringName) -> Dictionary:
	return { "accepted": false, "code": code, "message": "Flappy Race tap rejected: %s" % code }
