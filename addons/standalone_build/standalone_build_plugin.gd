@tool
extends EditorPlugin

const Policy := preload("res://addons/standalone_build/standalone_build_policy.gd")
const MENU_NAME := "Build Standalone Host"
const DIALOG_SIZE := Vector2i(960, 540)

var _dialog: AcceptDialog
var _title_label: Label
var _target_label: Label
var _stage_label: Label
var _progress: ProgressBar
var _details: TextEdit
var _cancel_button: Button
var _build_active := false
var _cancel_requested := false
var _process_info: Dictionary = {}
var _process_output := ""
var _zipper: ZIPPacker
var _zip_files := PackedStringArray()
var _zip_index := 0
var _project_root := ""
var _staging_path := ""
var _zip_path := ""
var _reveal_on_success := true

func _enter_tree() -> void:
	_create_dialog()
	add_tool_menu_item(MENU_NAME, _on_build_requested)
	set_process(true)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _build_active and not _process_info.is_empty():
		OS.kill(int(_process_info.pid))
	if is_instance_valid(_dialog):
		_dialog.queue_free()

func _process(_delta: float) -> void:
	if not _build_active:
		return
	if not _process_info.is_empty():
		_drain_process_output()
		var pid := int(_process_info.pid)
		if not OS.is_process_running(pid):
			_drain_process_output()
			var exit_code := OS.get_process_exit_code(pid)
			_process_info.clear()
			if _cancel_requested:
				_finish_cancelled()
			else:
				_on_export_finished(exit_code)
	elif _zipper != null:
		_zip_next_file()

func _on_build_requested() -> void:
	if _build_active:
		return
	_build_active = true
	_cancel_requested = false
	_process_output = ""
	_project_root = ProjectSettings.globalize_path("res://").trim_suffix("/")
	_staging_path = _project_root.path_join(Policy.STAGING_RELATIVE)
	_zip_path = _project_root.path_join(Policy.ZIP_RELATIVE)
	_dialog.title = "Build Standalone Host"
	_title_label.text = "Preparing Windows x86_64 standalone host"
	_target_label.text = "Target: %s" % _zip_path
	_target_label.tooltip_text = _zip_path
	_set_stage("Preflight checks...", 5, false)
	_details.text = ""
	_cancel_button.disabled = false
	_dialog.get_ok_button().disabled = true
	# popup_centered(size) treats its argument as a minimum and can preserve a
	# previously stretched native-window size. Assigning size first guarantees
	# that every build starts from the same landscape dimensions.
	_dialog.size = DIALOG_SIZE
	_dialog.popup_centered()
	call_deferred("_run_preflight")

func _run_preflight() -> void:
	if OS.get_name() != "Windows":
		_fail("This command currently supports only a Windows editor host.")
		return
	var error := Policy.validate_preset(_project_root.path_join("export_presets.cfg"))
	if error.is_empty():
		error = Policy.validate_owned_paths(_project_root)
	if error.is_empty():
		error = Policy.validate_templates(Policy.standard_release_template_path(), Policy.standard_debug_template_path())
	if not error.is_empty():
		_fail(error)
		return
	_set_stage("Preparing the tool-owned staging directory...", 20, false)
	error = _prepare_output()
	if not error.is_empty():
		_fail(error)
		return
	if _cancel_requested:
		_finish_cancelled()
		return
	_start_export()

func _start_export() -> void:
	_set_stage("Exporting...", 35, true)
	var executable_path := _staging_path.path_join(Policy.EXECUTABLE_NAME)
	_process_info = OS.execute_with_pipe(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", _project_root, "--export-release", Policy.PRESET_NAME, executable_path,
	]), false)
	if _process_info.is_empty():
		_fail("Godot could not start the headless export process. Check the editor executable and permissions.")

func _on_export_finished(exit_code: int) -> void:
	_progress.indeterminate = false
	var executable_path := _staging_path.path_join(Policy.EXECUTABLE_NAME)
	var pack_path := _staging_path.path_join(Policy.PACK_NAME)
	var error := Policy.validate_export_result(exit_code, executable_path, pack_path, _process_output)
	if not error.is_empty():
		_fail(error)
		return
	_set_stage("Verifying exported files and bundled browser routes...", 70, false)
	var missing := Policy.pack_contains_required_runtime_paths(pack_path)
	if not missing.is_empty():
		_fail("The exported PCK is missing required runtime assets:\n- %s" % "\n- ".join(missing))
		return
	var metadata_error := _write_build_info()
	if not metadata_error.is_empty():
		_fail(metadata_error)
		return
	_start_zip()

func _start_zip() -> void:
	_set_stage("Creating portable ZIP...", 78, false)
	_zipper = ZIPPacker.new()
	var error := _zipper.open(_zip_path)
	if error != OK:
		_zipper = null
		_fail("Could not create %s (error %d)." % [_zip_path, error])
		return
	_zip_files = PackedStringArray([Policy.EXECUTABLE_NAME, Policy.PACK_NAME, Policy.METADATA_NAME])
	_zip_index = 0

func _zip_next_file() -> void:
	if _cancel_requested:
		# A ZIP cannot be left half-written. Closing it keeps cancellation scoped to builds/.
		_zipper.close()
		_zipper = null
		DirAccess.remove_absolute(_zip_path)
		_finish_cancelled()
		return
	if _zip_index >= _zip_files.size():
		var close_error := _zipper.close()
		_zipper = null
		if close_error != OK:
			_fail("Could not finalize the ZIP (error %d)." % close_error)
			return
		_succeed()
		return
	var filename := _zip_files[_zip_index]
	var source_path := _staging_path.path_join(filename)
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		_fail("Could not read %s while creating the ZIP." % source_path)
		return
	var archive_path := "Play-Shapes-windows-x86_64/%s" % filename
	var error := _zipper.start_file(archive_path)
	if error == OK:
		error = _zipper.write_file(source.get_buffer(source.get_length()))
	if error == OK:
		error = _zipper.close_file()
	if error != OK:
		_fail("Could not add %s to the ZIP (error %d)." % [filename, error])
		return
	_zip_index += 1
	_progress.value = 78 + (float(_zip_index) / float(_zip_files.size())) * 20.0

func _write_build_info() -> String:
	var revision := ""
	var head_path := _project_root.path_join(".git/HEAD")
	var head := FileAccess.open(head_path, FileAccess.READ)
	if head != null:
		var head_value := head.get_as_text().strip_edges()
		if head_value.begins_with("ref: "):
			var ref_path := _project_root.path_join(".git").path_join(head_value.trim_prefix("ref: "))
			var ref_file := FileAccess.open(ref_path, FileAccess.READ)
			if ref_file != null:
				revision = ref_file.get_as_text().strip_edges()
		else:
			revision = head_value
	var metadata_path := _staging_path.path_join(Policy.METADATA_NAME)
	var metadata := FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata == null:
		return "Could not write build metadata: %s" % metadata_path
	metadata.store_string(JSON.stringify(Policy.create_build_info(revision), "  ") + "\n")
	return ""

func _prepare_output() -> String:
	if DirAccess.dir_exists_absolute(_staging_path):
		var clean_error := _remove_directory_contents(_staging_path)
		if clean_error != OK:
			return "Could not clean the owned staging directory (error %d): %s" % [clean_error, _staging_path]
	else:
		var make_error := DirAccess.make_dir_recursive_absolute(_staging_path)
		if make_error != OK:
			return "Could not create the staging directory (error %d): %s" % [make_error, _staging_path]
	if FileAccess.file_exists(_zip_path):
		var remove_error := DirAccess.remove_absolute(_zip_path)
		if remove_error != OK:
			return "Could not replace the previous ZIP (error %d): %s" % [remove_error, _zip_path]
	return ""

func _remove_directory_contents(path: String) -> Error:
	var directory := DirAccess.open(path)
	if directory == null:
		return DirAccess.get_open_error()
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if directory.current_is_dir():
				var child_error := _remove_directory_contents(child)
				if child_error != OK:
					return child_error
				child_error = DirAccess.remove_absolute(child)
				if child_error != OK:
					return child_error
			else:
				var file_error := DirAccess.remove_absolute(child)
				if file_error != OK:
					return file_error
		entry = directory.get_next()
	return OK

func _drain_process_output() -> void:
	for key in ["stdio", "stderr"]:
		var pipe := _process_info.get(key) as FileAccess
		if pipe == null:
			continue
		for unused in range(100):
			var line := pipe.get_line()
			if pipe.get_error() != OK:
				break
			_process_output += line + "\n"
	_details.text = Policy._tail(_process_output)
	_details.scroll_vertical = _details.get_line_count()

func _on_cancel_pressed() -> void:
	if not _build_active:
		return
	_cancel_requested = true
	_cancel_button.disabled = true
	_stage_label.text = "Cancelling safely..."
	if not _process_info.is_empty():
		OS.kill(int(_process_info.pid))
	elif _zipper == null:
		_finish_cancelled()

func _succeed() -> void:
	_build_active = false
	_progress.indeterminate = false
	_progress.value = 100
	_title_label.text = "Standalone host build complete"
	_stage_label.text = "Verified and archived successfully."
	_details.text = "Portable folder:\n%s\n\nZIP:\n%s" % [_staging_path, _zip_path]
	_cancel_button.disabled = true
	_dialog.get_ok_button().disabled = false
	if _reveal_on_success:
		OS.shell_show_in_file_manager(_staging_path, true)

func _fail(message: String) -> void:
	if _zipper != null:
		_zipper.close()
		_zipper = null
	_build_active = false
	_progress.indeterminate = false
	_title_label.text = "Standalone host build failed"
	_stage_label.text = "No success folder was opened."
	_details.text = message
	_cancel_button.disabled = true
	_dialog.get_ok_button().disabled = false

func _finish_cancelled() -> void:
	_build_active = false
	_process_info.clear()
	_progress.indeterminate = false
	_title_label.text = "Standalone host build cancelled"
	_stage_label.text = "Partial files may remain only in the owned build folder and will be replaced on the next run."
	_cancel_button.disabled = true
	_dialog.get_ok_button().disabled = false

func _set_stage(text: String, value: float, busy: bool) -> void:
	_stage_label.text = text
	_progress.indeterminate = busy
	_progress.value = value

func _create_dialog() -> void:
	_dialog = AcceptDialog.new()
	_dialog.exclusive = true
	_dialog.unresizable = false
	_dialog.min_size = Vector2i(800, 450)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	layout.add_child(_title_label)
	_target_label = Label.new()
	# Wrapping a long absolute path before the native window has a width can make
	# Label report a multi-thousand-pixel minimum height. Keep it to one line;
	# the complete value remains available in the tooltip and details states.
	_target_label.clip_text = true
	_target_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(_target_label)
	_stage_label = Label.new()
	layout.add_child(_stage_label)
	_progress = ProgressBar.new()
	_progress.min_value = 0
	_progress.max_value = 100
	_progress.show_percentage = true
	layout.add_child(_progress)
	_details = TextEdit.new()
	_details.custom_minimum_size = Vector2(860, 190)
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.editable = false
	_details.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	layout.add_child(_details)
	_dialog.add_child(layout)
	_cancel_button = _dialog.add_button("Cancel", true, "cancel_build")
	_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"cancel_build":
			_on_cancel_pressed()
	)
	_dialog.close_requested.connect(func() -> void:
		if _build_active:
			_on_cancel_pressed()
	)
	add_child(_dialog)
