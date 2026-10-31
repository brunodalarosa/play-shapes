extends TestScript
## The shared screen of a Flappy Race: the camera keeps the leader in view, players too far
## behind become bubbles and return when caught up, overlapping Cubios dither, names fade,
## places show, a hit tumbles and then waits behind a floating heart, a disconnected Cubio
## greys, pickups burst, the countdowns read right, finishers teleport to the podium and the
## results stand everyone on it with the camera on the podium beside a panel of places, times
## and distances, with the session's best for a single player. Also measures a frame with ten
## players.

const SCENE: PackedScene = preload("res://minigames/006_flappy_race/flappy_race_presentation.tscn")
const TUNING := preload("res://minigames/006_flappy_race/tuning/Default.tres")
const COLORS: Array[String] = [
	"#E53935",
	"#1E88E5",
	"#43A047",
	"#FBC02D",
	"#8E24AA",
	"#F57C00",
	"#00ACC1",
	"#EC407A",
	"#3949AB",
	"#8D6E63",
]
const START_MSEC := 1000
const GO_MSEC := 4000

var _controller: FlappyRaceController
var _presentation: FlappyRacePresentation
var _solo_best := -1
var _first_msec := -1


func _run() -> void:
	var tuning: FlappyRaceTuning = TUNING.duplicate(true)
	tuning.race_seconds = 20.0
	tuning.last_seconds = 10.0
	await _open(4, tuning)

	_check_countdown()
	_check_go_and_spread()
	_check_leader_and_bubbles()
	_check_names_and_places()
	_check_hit_and_heart()
	_check_frozen_and_burst()
	_check_last_seconds()
	_check_podium()
	_check_results_panel()
	_close()

	for race: int in 2:
		await _open(1, tuning)
		_check_solo_best(race)
		_close()

	await _open(10, tuning)
	_measure_frame()
	_close()


func _check_countdown() -> void:
	_presentation.draw_frame(0.0)
	check(_presentation.cue_text() == "3", "The countdown shows 3")
	check(_presentation.timer_text() == "0:20", "The timer shows the whole race")
	var p0 := _presentation.visual_for("p0")
	check(p0.face == "face_scheming", "Cubios scheme through the countdown")
	var dithers := _visuals().map(
		func(visual: FlappyRacePresentation.RacerVisual) -> float:
			return visual.cubio.dither(),
	)
	check(
		dithers == [0.0, 0.5, 0.5, 0.5],
		"At the start every Cubio in front of another dithers; the one at the back does not",
	)


func _check_go_and_spread() -> void:
	_settle(1)
	check(_presentation.cue_text() == "GO!", "GO shows when the race starts")
	for index: int in 4:
		var state := _controller.racer_for("p%d" % index).state
		state.y = 5.0 + 8.0 * index
		state.invulnerable_ticks = 100000
	_settle(3)
	var whole := _visuals().all(
		func(visual: FlappyRacePresentation.RacerVisual) -> bool:
			return visual.cubio.dither() == 0.0,
	)
	check(whole, "Cubios apart draw whole")
	var p3 := _presentation.visual_for("p3")
	check(
		absf(p3.pivot.position.y - _controller.racer_for("p3").state.y) < 0.5
		and p3.pivot.position.z > _presentation.visual_for("p0").pivot.position.z,
		"Each Cubio is drawn at its flight, in its own depth slot",
	)


func _check_leader_and_bubbles() -> void:
	_controller.racer_for("p0").state.x = 400.0
	_settle(5)
	var leader := _presentation.visual_for("p0")
	var camera := _presentation.camera
	check(
		camera.shows(leader.drawn) and is_equal_approx(camera.visible_height, 54.0),
		"The leader stays in view at the furthest zoom",
	)
	var shown := Array(_presentation.bubbles.shown_ids())
	shown.sort()
	check(shown == ["p1", "p2", "p3"], "Everyone too far behind gets a bubble")

	_controller.racer_for("p1").state.x = 395.0
	_settle(7)
	shown = Array(_presentation.bubbles.shown_ids())
	shown.sort()
	check(
		shown == ["p2", "p3"] and camera.shows(_presentation.visual_for("p1").drawn),
		"A player caught up loses the bubble and is in view",
	)


func _check_names_and_places() -> void:
	var p0 := _presentation.visual_for("p0")
	check(p0.name_label.modulate.a == 1.0, "Names show at first")
	check(p0.badge.text == "1st", "The leader's badge says 1st")
	check(_presentation.visual_for("p1").badge.text == "2nd", "The next one's says 2nd")
	_settle(318)
	check(absf(p0.name_label.modulate.a - 0.5) < 0.05, "Names fade after 5 s")
	_settle(360)
	check(p0.name_label.modulate.a == 0.0, "Names are gone 0.6 s later")


func _check_hit_and_heart() -> void:
	var racer := _controller.racer_for("p2")
	racer.state.invulnerable_ticks = 0
	racer.state.y = 0.9
	racer.state.vertical_speed = -20.0
	var start := _controller.settled_tick
	_settle(start + 1)
	var visual := _presentation.visual_for("p2")
	check(not racer.state.flying, "The Cubio hits the ground")
	check(
		visual.pivot.visible and visual.face == "face_dizzy" and not visual.heart.visible,
		"A hit Cubio tumbles dizzy before the heart shows",
	)
	check(
		visual.cubio.action == "hit" and visual.pivot.rotation.z == 0.0,
		"The rig plays Hit without a second tumble on the presentation pivot",
	)
	_settle(start + 40)
	check(
		not visual.pivot.visible and visual.heart.visible,
		"After the tumble the Cubio leaves play and the heart floats at the respawn spot",
	)
	check(
		visual.heart.position.x == racer.state.x and visual.heart.modulate.a < 1.0,
		"The heart waits at the respawn spot, not yet tappable",
	)
	_settle(start + 125)
	check(
		racer.state.ready and visual.pivot.visible
		and visual.face == "face_worried" and visual.heart.modulate.a == 1.0,
		"Once ready the Cubio waits worried behind the full heart",
	)
	check(visual.cubio.action == "idle", "The waiting Cubio leaves its hit pose")
	racer.taps[_controller.settled_tick + 1] = true
	_settle(_controller.settled_tick + 1)
	check(visual.cubio.action == "respawn", "The respawn tap plays the pop before its flap")
	visual.cubio.animation_player().advance(0.6)
	racer.taps[_controller.settled_tick + 1] = true
	_settle(_controller.settled_tick + 1)
	check(visual.cubio.action == "flap", "A settled tap plays the wing beat")


func _check_frozen_and_burst() -> void:
	var now := _msec(_controller.settled_tick + _controller.window_ticks())
	var roster: Array[Dictionary] = []
	for index: int in 4:
		var state := "reconnecting" if index == 3 else "connected"
		roster.append({ "player_id": "p%d" % index, "state": state })
	_controller.observe_registry(roster, now)
	_presentation.draw_frame(0.0)
	var frozen := _presentation.visual_for("p3")
	check(
		frozen.cubio.player_color != frozen.color and frozen.pivot.visible,
		"A disconnected Cubio stays, greyed",
	)

	_controller.race_event.emit(&"pickup", "p1", { "tick": _controller.settled_tick, "pickup": 0 })
	check(_presentation.bursts() > 0, "A pickup bursts in the taker's colour")
	check(
		_presentation.visual_for("p1").pickup_at == _presentation.race_seconds(),
		"The taker beams",
	)


func _check_last_seconds() -> void:
	_settle(_controller.last_seconds_tick() + 1)
	check(_presentation.cue_text() == "10", "The last 10 seconds count down large")
	check(_presentation.timer_text() == "0:10", "The timer agrees")


func _check_podium() -> void:
	var winner := _controller.racer_for("p0")
	winner.state.invulnerable_ticks = 100000
	winner.state.x = _controller.course.flight.finish_x - 0.1
	winner.state.y = 12.0
	var puffs := _presentation.bursts()
	_settle(_controller.settled_tick + 2)
	var visual := _presentation.visual_for("p0")
	check(winner.finished() and visual.on_podium, "A finisher teleports to the podium")
	check(
		_on_spot(visual, 1) and visual.pivot.rotation.z == 0.0,
		"The first to finish stands upright on the tallest block",
	)
	check(_presentation.bursts() == puffs + 2, "A puff where it leaves and one where it lands")
	check(not _presentation.visual_for("p1").on_podium, "Players still racing keep flying")

	_settle(_controller.race_ticks())
	check(_controller.phase == FlappyRaceController.Phase.RESULTS, "The timer ends the race")
	var order := _controller.ranking()
	for index: int in order.size():
		var standing := _presentation.visual_for(order[index].player_id)
		check(_on_spot(standing, index + 1), "Place %d stands on its spot" % (index + 1))
	var fourth := _presentation.visual_for(order[3].player_id)
	check(fourth.face == "face_disappointed", "Off the raised blocks the face is disappointed")
	check(visual.face == "face_mischievous", "The top three look mischievous")
	check(visual.name_label.modulate.a == 1.0, "Names show again over the podium")
	check(_presentation.bubbles.shown_ids().is_empty(), "Nobody on the podium has a bubble")
	for frame: int in 120:
		_presentation.draw_frame(1.0 / 60.0)
	var area := FlappyRacePodium.outline()
	area.position += Vector2(_presentation.podium.position.x, 0.0)
	var shown := _presentation.camera.visible_rect()
	check(
		shown.encloses(area) and shown.end.x > area.end.x + shown.size.x * 0.3,
		"The camera frames the podium and leaves the right of the screen for the results",
	)


func _check_results_panel() -> void:
	var lines := _presentation.result_lines()
	var order := _controller.ranking()
	check(_presentation.results_shown() and lines.size() == 4, "The results list every player")
	var winner := order[0]
	check(
		lines[0]
		== "1st %s %s"
		% [winner.display_name, FlappyRacePresentation.race_time(winner.finish_msec())],
		"A finisher's row shows the place, name and finish time",
	)
	var last := order[3]
	var reached := "%d m" % floori(last.distance())
	check(
		lines[3] == "4th %s %s" % [last.display_name, reached],
		"A player still racing shows the distance reached",
	)
	check(_presentation.best_text() == "", "Several players see no session best")


## A single player finishes [param race] twice in a row; the second sees the better of the two.
func _check_solo_best(race: int) -> void:
	var racer := _controller.racer_for("p0")
	# The second race finishes half a second later, so its best is the first race's time.
	_settle(1 + race * 30)
	racer.state.invulnerable_ticks = 100000
	racer.state.x = _controller.course.flight.finish_x - 0.1
	racer.state.y = 12.0
	# As FlappyRace does: the best is kept when the results come, before they are drawn.
	_controller.race_event.connect(
		func(kind: StringName, _player_id: String, _data: Dictionary) -> void:
			if kind == &"results":
				_solo_best = FlappyRace.record(_solo_best, racer.finish_msec())
				_presentation.session_best_msec = _solo_best,
	)
	_settle(_controller.settled_tick + 2)
	check(_controller.phase == FlappyRaceController.Phase.RESULTS, "A lone finisher ends the race")
	var time := FlappyRacePresentation.race_time(racer.finish_msec())
	check(
		_presentation.result_lines()[0] == "1st Player 1 %s" % time,
		"A single player sees their finish time",
	)
	var best := FlappyRacePresentation.race_time(
		mini(_first_time(racer, race), racer.finish_msec())
	)
	check(
		_presentation.best_text() == "Best this session %s" % best,
		"Race %d shows the best time of the session" % (race + 1),
	)


func _first_time(racer: FlappyRaceRacer, race: int) -> int:
	if race == 0:
		_first_msec = racer.finish_msec()
	return _first_msec


func _on_spot(visual: FlappyRacePresentation.RacerVisual, place: int) -> bool:
	var spot := _presentation.podium.position + FlappyRacePodium.spot_for(place)
	spot.y += FlappyRacePresentation.BODY_CENTRE
	return visual.pivot.visible and visual.pivot.position.is_equal_approx(spot)


func _measure_frame() -> void:
	var started := Time.get_ticks_usec()
	for frame: int in 60:
		_presentation.draw_frame(1.0 / 60.0)
	var average := (Time.get_ticks_usec() - started) / 60.0 / 1000.0
	print("Flappy Race shared-screen frame with 10 players: %.3f ms" % average)
	check(average < 4.0, "Drawing ten racers costs under 4 ms a frame")


func _open(count: int, tuning: FlappyRaceTuning) -> void:
	_controller = FlappyRaceController.new()
	_controller.tuning = tuning
	var players: Array[Dictionary] = []
	for index: int in count:
		players.append(
			{
				"player_id": "p%d" % index,
				"name": "Player %d" % (index + 1),
				"seat": index + 1,
				"character_color": COLORS[index],
			}
		)
	_controller.start_race(players, 11, START_MSEC)
	_presentation = SCENE.instantiate() as FlappyRacePresentation
	root.add_child(_presentation)
	await process_frame
	_presentation.bind(_controller)
	_presentation.set_process(false)


func _close() -> void:
	_presentation.queue_free()
	_controller.free()


func _visuals() -> Array[FlappyRacePresentation.RacerVisual]:
	var visuals: Array[FlappyRacePresentation.RacerVisual] = []
	for index: int in _controller.racers().size():
		visuals.append(_presentation.visual_for("p%d" % index))
	return visuals


## Settles every flight through [param tick] and draws the frame.
func _settle(tick: int) -> void:
	_controller.advance(_msec(tick + _controller.window_ticks()))
	_presentation.draw_frame(0.0)


func _msec(tick: int) -> int:
	return GO_MSEC + ceili(tick * 1000.0 / FlappyFlightTuning.TICK_RATE)
