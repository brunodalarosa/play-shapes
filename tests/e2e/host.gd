extends SceneTree
## End-to-end host for web/e2e: the game's main scene, real SessionHost and real
## scenes, driven by real phone clients. It clicks the host's own buttons with
## injected mouse events, as a person would, and prints one "E2E ..." line per
## event for the test runner to wait on.
##
## Environment:
##   E2E_PLAYERS        players expected before Start is pressed (default 2)
##   E2E_ROUND          "quick" shortens the Bubbles round in memory; "full" keeps every default
##   E2E_HTTP_PORT      HTTP port; WebSocket uses the next one (default 18200)
##   E2E_HOST_CAPTURES  folder for host screenshots; only useful when not headless

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const QUICK_ROUND_SECONDS := 10.0
# A character counts as moved by its phone once it travels this far sideways.
const MOVED_DISTANCE := 40.0
# Like a person, Start waits until everyone has stopped, and results stay up before Return.
const AT_REST_SECONDS := 1.0
const RESULTS_SECONDS := 3.0
const TIMEOUT_SECONDS := 600.0

var _host: Node
var _players := 2
var _captures := ""
var _elapsed := 0.0
var _scene_path := ""
var _phase := &""
var _start_x := { }
var _moved := { }
var _at_rest_for := 0.0
var _results_for := 0.0
var _booted := false
var _started := false
var _returned := false


func _initialize() -> void:
	_players = int(OS.get_environment("E2E_PLAYERS")) if OS.has_environment("E2E_PLAYERS") else 2
	_captures = OS.get_environment("E2E_HOST_CAPTURES")
	_start.call_deferred()


func _start() -> void:
	_host = root.get_node("SessionHost")
	_use_round(OS.get_environment("E2E_ROUND"))

	# The networking Resource is preloaded by the host; a copy keeps the change in this process.
	var http_port := int(OS.get_environment("E2E_HTTP_PORT")) if OS.has_environment("E2E_HTTP_PORT") else 18200
	_host.settings = _host.settings.duplicate()
	_host.settings.http_port = http_port
	_host.settings.websocket_port = http_port + 1

	# The game's own boot starts the host and opens the lobby, so whatever boot grows is part of the run.
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))


## Reports the host as ready once boot has started it, or stops when boot could not.
func _watch_boot() -> void:
	if _host.running:
		_booted = true
		_event("ready http=%d" % _host.settings.http_port)
	elif not _host.startup_error.is_empty():
		push_error("E2E host could not start: %s" % _host.startup_error)
		quit(1)


func _use_round(mode: String) -> void:
	if mode == "full":
		_event("round full")
		return

	# Duplicates, never saves: the committed presets stay untouched.
	var presets: ActivePresets = _host.active_presets.duplicate()
	presets.bubbles = presets.bubbles.duplicate()
	presets.bubbles.round_duration_seconds = QUICK_ROUND_SECONDS
	_host.active_presets = presets
	_event("round quick %d s" % QUICK_ROUND_SECONDS)


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS:
		push_error("E2E host timed out after %d s" % TIMEOUT_SECONDS)
		quit(2)
		return false

	var scene := current_scene
	if scene == null:
		return false

	if not _booted:
		_watch_boot()

	if scene.scene_file_path != _scene_path:
		_scene_path = scene.scene_file_path
		_event("scene %s" % _scene_path.get_file().get_basename())
		_capture_later(_scene_path.get_file().get_basename())

	if _scene_path == LOBBY_SCENE:
		_watch_lobby(scene, delta)
	elif scene.get("controller") is BubblesRoundController:
		_watch_bubbles(scene, delta)

	return false


func _watch_lobby(lobby: Node, delta: float) -> void:
	var world: LobbyPlaygroundWorld = lobby.world
	var all_at_rest := true
	for player: Dictionary in _host.players():
		var player_id := String(player.player_id)
		var character := world.character_for(player_id)
		if character == null:
			continue

		if character.velocity.length() > 1.0:
			all_at_rest = false
		if _moved.has(player_id):
			continue

		if not _start_x.has(player_id):
			_start_x[player_id] = character.position.x
		elif absf(character.position.x - float(_start_x[player_id])) >= MOVED_DISTANCE:
			_moved[player_id] = true
			_event("moved %s" % player_id)

	_at_rest_for = _at_rest_for + delta if all_at_rest else 0.0

	# Start only after every phone has moved its character, so the lobby step is part of the run.
	var start: Button = lobby.start_button
	if (
		not _started and _moved.size() >= _players
		and _at_rest_for >= AT_REST_SECONDS and not start.disabled
	):
		_started = true
		_click(start, "start players=%d" % _host.player_registry.player_count())


func _watch_bubbles(bubbles: Node, delta: float) -> void:
	var controller: BubblesRoundController = bubbles.controller
	if controller.phase_name() != _phase:
		_phase = controller.phase_name()
		_event("phase %s" % _phase)
		if _phase == &"results":
			_capture_later("results")

	if _phase == &"results":
		_results_for += delta

	var return_button: Button = bubbles.get_node("Hud/Results/ReturnToLobby")
	if _results_for >= RESULTS_SECONDS and not _returned and not return_button.disabled:
		_returned = true
		_click(return_button, "return")


## Clicks a button with mouse events at its place on screen, so Godot's own hit
## testing decides whether the click lands: a button that is covered, off screen,
## disabled or ignoring the mouse is not pressed, and the run stops saying so.
func _click(button: BaseButton, event_text: String) -> void:
	var clicked := { "landed": false }
	button.pressed.connect(
		func() -> void:
			clicked.landed = true,
		CONNECT_ONE_SHOT,
	)

	var at := button.get_global_transform_with_canvas() * (button.size / 2.0)
	var hover := InputEventMouseMotion.new()
	hover.position = at
	hover.global_position = at
	root.push_input(hover, true)
	await process_frame

	for pressed: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		press.pressed = pressed
		press.position = at
		press.global_position = at
		root.push_input(press, true)
		await process_frame

	if clicked.landed:
		_event(event_text)
		return

	var under := root.gui_get_hovered_control()
	push_error(
		"E2E could not click %s at %s; under the mouse: %s"
		% [button.get_path(), at, under.get_path() if under != null else "nothing"]
	)
	quit(1)


func _event(text: String) -> void:
	print("E2E %s" % text)


func _capture_later(label: String) -> void:
	if _captures.is_empty() or DisplayServer.get_name() == "headless":
		return

	# Gives the new scene time to draw before capturing it.
	await create_timer(1.0).timeout
	var image := root.get_texture().get_image()
	if image != null:
		DirAccess.make_dir_recursive_absolute(_captures)
		image.save_png("%s/host-%05.1f-%s.png" % [_captures, _elapsed, label])
