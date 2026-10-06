@tool
extends EditorPlugin

const WorkshopPanel := preload("res://addons/tilt_shift_workshop/workshop_panel.gd")
const TEMP_ROOT := "res://scratch/tilt_shift_workshop/previews/"

var panel: WorkshopPanel
var _pid: int = -1
var _session: String = ""
var _poll: float = 0.0
var _stop_time: int = 0
var _pending_profile: TiltShiftTuning
var _pending_roster: int = 10


func _enter_tree() -> void:
	panel = WorkshopPanel.new()
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.preview_requested.connect(_request_preview)
	panel.preview_stop_requested.connect(_request_stop)
	panel.hide()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Tilt Shift"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("RigidBody2D", "EditorIcons")


func _make_visible(value: bool) -> void:
	if is_instance_valid(panel):
		panel.visible = value


func _request_preview(profile: TiltShiftTuning, roster: int) -> void:
	_pending_profile = profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	_pending_roster = roster
	if _pid > 0:
		_stop_child()
	elif _session.is_empty():
		_launch_pending()


func _request_stop() -> void:
	_pending_profile = null
	_stop_child()


func _stop_child() -> void:
	if _pid <= 0:
		return
	var file := FileAccess.open(_session.path_join("stop"), FileAccess.WRITE)
	if file != null:
		file.close()
	_stop_time = Time.get_ticks_msec()


func _launch_pending() -> void:
	if _pending_profile == null or not _session.is_empty():
		return
	_session = TEMP_ROOT.path_join("%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var absolute := ProjectSettings.globalize_path(_session)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	var path := _session.path_join("profile.tres")
	if error == OK:
		error = ResourceSaver.save(_pending_profile, path)
	if error != OK:
		panel.preview_status.text = "Preview snapshot could not be saved: " + error_string(error)
		_pending_profile = null
		_cleanup()
		return
	var args := PackedStringArray(
		[
			"--path",
			ProjectSettings.globalize_path("res://"),
			"--script",
			"res://addons/tilt_shift_workshop/workshop_preview_runner.gd",
			"--log-file",
			ProjectSettings.globalize_path(_session.path_join("runtime.log")),
			"--",
			ProjectSettings.globalize_path(path),
			str(_pending_roster),
		]
	)
	_pid = OS.create_process(OS.get_executable_path(), args)
	_pending_profile = null
	_stop_time = 0
	panel.preview_status.text = "Gameplay physics preview running in its own window."
	if _pid < 0:
		panel.preview_status.text = "Godot could not start the preview process."
		_cleanup()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.25 or (_pid <= 0 and _session.is_empty()):
		return
	_poll = 0
	if _pid > 0 and _stop_time > 0 and Time.get_ticks_msec() - _stop_time > 2000 \
			and OS.is_process_running(_pid):
		OS.kill(_pid)
	if _pid <= 0 or not OS.is_process_running(_pid):
		_pid = -1
		if _cleanup():
			panel.preview_status.text = "Preview closed; temporary content removed."
			_launch_pending()
		else:
			panel.preview_status.text = "Preview closed; waiting for temporary file locks to clear."


func _cleanup() -> bool:
	if _session.is_empty() or not _session.begins_with(TEMP_ROOT):
		return true
	for filename: String in [
		"profile.tres",
		"profile.tres.uid",
		"runtime.log",
		"ready.json",
		"stop",
	]:
		var path := ProjectSettings.globalize_path(_session.path_join(filename))
		if FileAccess.file_exists(path):
			# Windows can report a process exit before its log-file handle is released.
			if DirAccess.remove_absolute(path) != OK and FileAccess.file_exists(path):
				return false
	var directory := ProjectSettings.globalize_path(_session)
	if DirAccess.dir_exists_absolute(directory) and DirAccess.remove_absolute(directory) != OK:
		return false
	_session = ""
	return true


func _exit_tree() -> void:
	_pending_profile = null
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	for attempt: int in 10:
		if _cleanup():
			break
		OS.delay_msec(50)
	if is_instance_valid(panel):
		panel.queue_free()
