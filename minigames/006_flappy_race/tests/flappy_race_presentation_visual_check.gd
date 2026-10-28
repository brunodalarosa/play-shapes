extends TestScript
## Renders the Flappy Race shared screen for review: autopilot races with 1, 4 and 10 players,
## the overlap at the start, the closest and the furthest zoom, and bubbles for players behind.
## Players start tapping at different times, so the pack spreads. Run without --headless.

const OUTPUT_DIR := "res://test-results/flappy-race"
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
const NAMES: Array[String] = [
	"Ana",
	"Bruno",
	"Caio",
	"Duda",
	"Elis",
	"Fábio",
	"Gabi",
	"Hugo",
	"Iara",
	"Joca",
]
const START_MSEC := 1000

var _controller: FlappyRaceController
var _presentation: FlappyRacePresentation
var _pilots: Array[FlappyFlightAutopilot] = []


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _open(4, 0)
	await _capture("start-4-players")
	_close()

	await _open(1, 0)
	await _race_to(600)
	await _capture("closest-1-player")
	_close()

	await _open(4, 40)
	await _race_to(900)
	await _capture("race-4-players")
	_close()

	await _open(10, 0)
	await _capture("start-10-players")
	await _race_to(240, 30)
	await _capture("spread-10-players")
	_close()

	await _open(10, 100)
	await _race_to(1500)
	await _capture("furthest-10-players")
	_close()


## Opens a race; player i starts tapping [param delay_step] × i ticks after GO.
func _open(count: int, delay_step: int) -> void:
	_controller = FlappyRaceController.new()
	_controller.tuning = TUNING
	var players: Array[Dictionary] = []
	for index: int in count:
		players.append(
			{
				"player_id": "p%d" % index,
				"name": NAMES[index],
				"seat": index + 1,
				"character_color": COLORS[index],
				"delay": index * delay_step,
			}
		)
	_controller.start_race(players, 2026, START_MSEC)
	_controller.set_meta(
		"delays",
		players.map(
			func(player: Dictionary) -> int:
				return player.delay,
		),
	)
	_pilots.clear()
	for index: int in count:
		var pilot := FlappyFlightAutopilot.new(TUNING.flight, _controller.course.flight)
		_pilots.append(pilot)
	_presentation = SCENE.instantiate() as FlappyRacePresentation
	root.add_child(_presentation)
	await process_frame
	_presentation.bind(_controller)
	_presentation.set_process(false)
	_presentation.draw_frame(0.0)


## Flies every autopilot to [param tick]. Player i starts tapping at its delay plus
## [param extra_delay] × i ticks.
func _race_to(tick: int, extra_delay := 0) -> void:
	var delays: Array = _controller.get_meta("delays")
	while _controller.settled_tick < tick:
		var settled := _controller.settled_tick
		var racers := _controller.racers()
		for index: int in racers.size():
			var racer := racers[index]
			var delay: int = delays[index] + index * extra_delay
			if racer.racing() and settled >= delay and _pilots[index].decide(racer.state):
				_controller.submit_tap(racer.player_id, settled, settled + 1, _now())
		_controller.advance(_msec(settled + 1 + _controller.window_ticks()))
		_presentation.draw_frame(1.0 / 60.0)


func _capture(name: String) -> void:
	for frame: int in 3:
		_presentation.draw_frame(1.0 / 60.0)
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT_DIR, name])
	check(image.save_png(path) == OK, "Saved %s" % path)
	print(
		"%s: visible height %.1f m, bubbles %s"
		% [name, _presentation.camera.visible_height, _presentation.bubbles.shown_ids()]
	)


func _close() -> void:
	_presentation.queue_free()
	_controller.free()


func _now() -> int:
	return _msec(_controller.settled_tick + _controller.window_ticks())


func _msec(tick: int) -> int:
	var go := START_MSEC + roundi(TUNING.countdown_seconds * 1000.0)
	return go + ceili(tick * 1000.0 / FlappyFlightTuning.TICK_RATE)
