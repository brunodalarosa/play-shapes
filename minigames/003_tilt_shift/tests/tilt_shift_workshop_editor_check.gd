@tool
extends EditorPlugin
## Scripted interactions inside the real editor; screenshots do not certify usability.

const WorkshopPanel := preload("res://addons/tilt_shift_workshop/workshop_panel.gd")
const Model := preload("res://addons/tilt_shift_workshop/workshop_model.gd")
const WorkshopPlugin := preload("res://addons/tilt_shift_workshop/workshop_plugin.gd")
const OUTPUT := "res://test-results/tilt-shift/workshop/"
var root: Window
var _panel: WorkshopPanel
var _failures: int = 0
const SAVED := "res://scratch/tilt_shift_workshop/editor-reload.tres"


func _enter_tree() -> void:
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(3).timeout
	root.size = Vector2i(1800, 1200)
	EditorInterface.set_main_screen_editor("Tilt Shift")
	await get_tree().process_frame
	for child: Node in EditorInterface.get_editor_main_screen().get_children():
		if child is WorkshopPanel:
			_panel = child
	if not _require(_panel != null, "Enabled workshop appears in the actual editor"):
		get_tree().quit(1)
		return
	if OS.get_environment("PLAY_SHAPES_WORKSHOP_STAGE") == "reload":
		_require(
			_panel.model.load_profile(SAVED),
			"Saved content loads after closing and reopening the editor",
		)
		_require(
			_panel.model.baskets.size() == 2,
			"Reopened editor retains multiple named basket presets",
		)
		_require(
			is_equal_approx(_panel.model.profile.baskets_by_round[0].openings[0].width, 0.10),
			"Reopened editor retains paired basket widths",
		)
		_require(
			_panel.model.profile.baskets_by_round[1].preset_name == "Second editor preset",
			"Reopened editor retains numbered-round assignment",
		)
		_panel.canvas.mode = "basket"
		_panel._rebuild_settings()
		await get_tree().process_frame
		var scroll: ScrollContainer = _panel._settings.get_parent()
		scroll.ensure_control_visible(_panel._settings.find_child("Round_1", true, false))
		await _capture("reloaded-preset.png")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED))
		print("Workshop editor reopen checks: %d failures" % _failures)
		get_tree().quit(0 if _failures == 0 else 1)
		return
	await get_tree().create_timer(0.5).timeout
	var gravity: SpinBox = _panel.tunables.find_child("gravity", true, false)
	var ready_timeout: SpinBox = _panel.tunables.find_child("readiness_seconds", true, false)
	_require(
		gravity != null and ready_timeout != null and not gravity.tooltip_text.is_empty(),
		"Tunables tab exposes physics, readiness and their runtime field explanations",
	)
	gravity.value = 0.25
	_require(
		is_equal_approx(_panel.model.profile.physics.gravity, 0.25),
		"Tunables edits update the same profile used by preview and save",
	)
	(_panel.tunables.get_parent().get_parent() as TabContainer).current_tab = 1
	await _capture("tunables.png")
	(_panel.tunables.get_parent().get_parent() as TabContainer).current_tab = 0
	_panel.model.undo()
	_panel._rebuild_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas := _panel.canvas
	var original := _panel.model.profile.paddle_layout.paddles[0].position
	var start := canvas.to_screen(original) + canvas.global_position
	var end := canvas.to_screen(Vector2(0.213, 0.147)) + canvas.global_position
	await _drag(start, end)
	_require(
		_panel.model.profile.paddle_layout.paddles[0].position.is_equal_approx(Vector2(0.21, 0.15)),
		"Editor hit testing and dragging apply visible grid snapping",
	)
	_require(not canvas.diagnostics.warnings.is_empty(), "Guide discrepancies remain visible")
	await _capture("paddles-and-guides.png")
	_panel.model.undo()
	_panel.canvas.mode = "basket"
	_panel._rebuild_settings()
	await get_tree().process_frame
	start = canvas.to_screen(
		Vector2(
			_panel.model.basket().openings[0].center,
			_panel.model.profile.paddle_layout.arena_size.y,
		),
	)
	start += canvas.global_position + Vector2(0, 12)
	end = canvas.to_screen(Vector2(0.14, _panel.model.profile.paddle_layout.arena_size.y))
	end += canvas.global_position + Vector2(0, 12)
	await _drag(start, end)
	_require(
		is_equal_approx(_panel.model.basket().openings[0].center, 0.14)
		and is_equal_approx(_panel.model.basket().openings[4].center, 0.86),
		"Editor dragging retains the stable reflected basket pair",
	)
	_panel.model.begin_edit()
	_panel.model.resize_basket(0, 0.10)
	_panel.model.end_edit()
	_require(
		_panel.model.profile.validation_errors().is_empty(),
		"Paired designer edits retain usable validity",
	)
	await _capture("baskets-and-rounds.png")
	var second: TiltShiftBasketPreset = _panel.model.basket().duplicate_deep(
		Resource.DEEP_DUPLICATE_ALL
	)
	second.preset_name = "Second editor preset"
	_panel.model.baskets.append(second)
	_panel.model.assign_round(1, 1)
	_require(
		_panel.model.save_content(SAVED, "profile", true) == OK,
		"Explicit editor draft save succeeds",
	)
	_panel.model.load_profile("res://minigames/003_tilt_shift/tuning/Default.tres")
	_require(_panel.model.load_profile(SAVED), "Editor saved profile reopens")
	_require(
		is_equal_approx(_panel.model.basket().openings[0].width, 0.10),
		"Editor reload restores paired widths",
	)
	_panel.model.profile.round_count += 1
	_panel.model.changed.emit()
	_panel._rebuild_settings()
	var missing: OptionButton = _panel._settings.find_child("Round_1", true, false)
	missing.item_selected.emit(0)
	_require(
		_panel.model.profile.baskets_by_round[0] == null,
		"Choosing Missing explicitly clears a numbered-round mapping",
	)
	_panel._start_preview()
	_require(
		_panel._notice.visible,
		"Missing round mapping blocks launch with an actionable editor message",
	)
	await _capture("invalid-round-mapping.png")
	_panel._notice.hide()
	_panel.model.load_profile("res://minigames/003_tilt_shift/tuning/Default.tres")
	_panel._rebuild_settings()
	await _check_preview_launcher()
	print("Workshop editor scripted checks: %d failures" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_preview_launcher() -> void:
	var plugin: WorkshopPlugin
	for node: Node in root.find_children("*", "EditorPlugin", true, false):
		if node is WorkshopPlugin:
			plugin = node
	if not _require(plugin != null, "Workshop preview launcher is registered in the editor"):
		return
	var saved_hash := FileAccess.get_sha256("res://minigames/003_tilt_shift/tuning/Default.tres")
	_panel._start_preview()
	await get_tree().create_timer(2).timeout
	var session := plugin._session
	_require(
		plugin._pid > 0 and FileAccess.file_exists(session.path_join("profile.tres")),
		"Preview launches an isolated deep-copied temporary profile",
	)
	var log := FileAccess.get_file_as_string(session.path_join("runtime.log"))
	var saved_log := FileAccess.open(OUTPUT.path_join("launched-preview.log"), FileAccess.WRITE)
	saved_log.store_string(log)
	saved_log.close()
	var ready_path := session.path_join("ready.json")
	var ready: Variant = JSON.parse_string(FileAccess.get_file_as_string(ready_path)) \
			if FileAccess.file_exists(ready_path) else null
	_require(
		ready is Dictionary and ready.ready and ready.gameplay_arena and ready.players == 10,
		"Launched preview confirms its actual gameplay arena and ten-player roster",
	)
	_require(not log.contains("ERROR"), "Launched preview diagnostics contain no runtime errors")
	_panel._start_preview()
	for attempt: int in 50:
		if plugin._session != session and plugin._pid > 0:
			break
		await get_tree().create_timer(0.1).timeout
	_require(
		plugin._session != session and not DirAccess.dir_exists_absolute(session),
		"Restart closes the old process and clears its owned temporary files",
	)
	_panel.preview_stop_requested.emit()
	for attempt: int in 50:
		if plugin._pid < 0:
			break
		await get_tree().create_timer(0.1).timeout
	_require(
		plugin._pid < 0 and plugin._session.is_empty(),
		"Editor stop clears the preview process and snapshot",
	)
	_require(
		FileAccess.get_sha256("res://minigames/003_tilt_shift/tuning/Default.tres") == saved_hash,
		"Launching and restarting preview does not write saved content",
	)


func _drag(start: Vector2, end: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	await get_tree().process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.global_position = end
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = end
	release.global_position = end
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release)
	await get_tree().process_frame


func _capture(filename: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var image := root.get_texture().get_image()
	_require(
		image.save_png(OUTPUT.path_join(filename)) == OK,
		"Actual editor capture saved: " + filename,
	)


func _require(condition: bool, description: String) -> bool:
	print("PASS: " if condition else "FAIL: ", description)
	if not condition:
		_failures += 1
	return condition
