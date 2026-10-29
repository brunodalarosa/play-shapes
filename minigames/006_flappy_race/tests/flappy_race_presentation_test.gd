extends TestScript
## The shared screen of a Flappy Race: the camera keeps the leader in view, players too far
## behind become bubbles and return when caught up, overlapping Cubios dither, names fade,
## places show, a hit tumbles and then waits behind a floating heart, a disconnected Cubio
## greys, pickups burst, and the countdowns read right. Also measures a frame with ten players.

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
