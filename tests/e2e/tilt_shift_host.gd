extends SceneTree
## Real boot/catalog/preparation/gameplay with quick in-memory presets and synthetic phone sensors.

var _host: Node
var _booted := false
var _started := false
var _returned := false
var _scene := ""
var _round := 0
var _phase := ""
var _results_at := -1
var _elapsed := 0.0
var _players := 2
var _captures := ""
var _start_at := -1
var _costs: Array[int] = []
var _bubbles_at := -1
var _bubbles_started := false
var _bubbles_seen := false
var _bubbles_returned := false
var _bubbles_results_at := -1


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	if not OS.get_environment("E2E_EXPORTED_PACK").is_empty():
		if FileAccess.file_exists("res://tests/e2e/tilt_shift_host.gd"):
			push_error("Exported flow must load its runtime exclusively from the package")
			quit(2)
			return
		print("E2E exported pack=%s" % OS.get_environment("E2E_EXPORTED_PACK"))
	_host = root.get_node("SessionHost")
	_players = int(OS.get_environment("E2E_PLAYERS"))
	_captures = OS.get_environment("E2E_HOST_CAPTURES")
	_host.settings = _host.settings.duplicate()
	_host.settings.http_port = int(OS.get_environment("E2E_HTTP_PORT"))
	_host.settings.websocket_port = _host.settings.http_port + 1
	_host.active_presets = _host.active_presets.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	_host.active_presets.bubbles.round_duration_seconds = 3.0
	var selected: TiltShiftTuning = _host.active_presets.tilt_shift
	selected.round_count = 2
	selected.layouts_by_round.resize(2)
	selected.flow.start_seconds = 0.2
	selected.flow.readiness_seconds = 30.0
	selected.round_duration_seconds = 8
	selected.flow.intermission_seconds = 0.25
	selected.physics.ball_count = 12
	selected.baskets_by_round = [
		selected.baskets_by_round[0],
		preload("res://minigames/003_tilt_shift/tuning/baskets/ThreeOpenings.tres"),
	]
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > 150:
		push_error("Tilt Shift browser flow timed out")
		quit(2)
		return false
	if not _booted and _host.running:
		_booted = true
		print("E2E ready http=%d" % _host.settings.http_port)
	if current_scene == null:
		return false
	if current_scene.scene_file_path != _scene:
		_scene = current_scene.scene_file_path
		print("E2E scene %s" % _scene.get_file().get_basename())
		_capture.call_deferred(_scene.get_file().get_basename())
	if _scene == "res://scenes/lobby.tscn" and not _started and _host.players().size() == _players:
		if _start_at < 0:
			_start_at = Time.get_ticks_msec() + 1000
		if Time.get_ticks_msec() < _start_at:
			return false
		_started = true
		var selector: OptionButton = current_scene.minigame_selector
		selector.select(1)
		selector.item_selected.emit(1)
		current_scene.start_button.pressed.emit()
		print("E2E start players=%d" % _players)
	if current_scene is TiltShiftGameplay:
		_costs.append(int(_host.tilt_shift.last_process_usec))
		var game := current_scene as TiltShiftGameplay
		var state := game.presentation.arena.controller.snapshot()
		if state.round_number != _round:
			_round = state.round_number
			print("E2E tilt round=%d" % _round)
			_capture.call_deferred("round_%d" % _round)
		var current_phase := "%s:%d" % [state.phase, state.round_number]
		if current_phase != _phase:
			_phase = current_phase
			print("E2E tilt phase=%s round=%d" % [state.phase, state.round_number])
			_capture.call_deferred("%s_%d" % [state.phase, state.round_number])
		if state.phase == &"finished" and _results_at < 0:
			_results_at = Time.get_ticks_msec()
			print("E2E tilt results")
			_capture.call_deferred("results")
		if _results_at >= 0 and Time.get_ticks_msec() - _results_at > 1000 and not _returned:
			_report_cost()
			_returned = true
			game.return_button.pressed.emit()
			print("E2E return")
			_bubbles_at = Time.get_ticks_msec() + 2000
	if _returned and _players == 2:
		_watch_next_game()
	return false


func _watch_next_game() -> void:
	if current_scene == null:
		return
	if (
		_scene == "res://scenes/lobby.tscn" and not _bubbles_started
		and Time.get_ticks_msec() >= _bubbles_at
	):
		_bubbles_started = true
		if not _host.websocket.motion_channels.is_empty():
			push_error("Tilt Shift capture survived lobby return")
		current_scene.minigame_selector.select(0)
		current_scene.minigame_selector.item_selected.emit(0)
		current_scene.start_button.pressed.emit()
		print("E2E bubbles prepare")
		return
	var controller: BubblesRoundController = current_scene.get("controller")
	if controller == null:
		return
	if not _bubbles_seen:
		_bubbles_seen = true
		print("E2E bubbles started")
	if controller.phase_name() == &"results":
		if _bubbles_results_at < 0:
			_bubbles_results_at = Time.get_ticks_msec()
		if Time.get_ticks_msec() - _bubbles_results_at > 1000 and not _bubbles_returned:
			_bubbles_returned = true
			current_scene.get_node("Hud/Results/ReturnToLobby").pressed.emit()
			print("E2E bubbles return")


func _report_cost() -> void:
	_costs.sort()
	var folder := "res://test-results/tilt-shift"
	if not OS.get_environment("E2E_REPORT_FOLDER").is_empty():
		folder = OS.get_environment("E2E_REPORT_FOLDER")
	DirAccess.make_dir_recursive_absolute(folder)
	var report := {
		"scope": (
			"Session coordination/publishing only; "
			+ "excludes sensors, native physics and rendering"
		),
		"players": _players,
		"samples": _costs.size(),
		"p95_usec": _costs[int(_costs.size() * 0.95)],
		"maximum_usec": _costs[-1],
	}
	var file := FileAccess.open(folder.path_join("flow-cost-%d.json" % _players), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))


func _capture(name: String) -> void:
	if _captures.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_captures)
	root.get_texture().get_image().save_png(_captures.path_join(name + ".png"))
