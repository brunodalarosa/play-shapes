extends SceneTree

const Policy := preload("res://addons/standalone_build/standalone_build_policy.gd")
var _failures := 0

func _init() -> void:
	_check(Policy.validate_preset("res://export_presets.cfg").is_empty(), "release preset name, platform, architecture, paths, and filters are valid")
	var missing_preset_config := ConfigFile.new()
	missing_preset_config.set_value("preset.0", "name", "Some Other Preset")
	var missing_preset_path := "res://test-results/standalone-build-missing-preset.cfg"
	_check(missing_preset_config.save(missing_preset_path) == OK, "missing-preset fixture can be written")
	_check(Policy.validate_preset(missing_preset_path).contains("is missing"), "missing named preset fails before export")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_preset_path))
	_check(Policy.validate_owned_paths(ProjectSettings.globalize_path("res://")).is_empty(), "owned build paths stay below builds/standalone")
	_check(Policy.STAGING_RELATIVE == "builds/standalone/windows-x86_64", "staging path is stable")
	_check(Policy.ZIP_RELATIVE == "builds/standalone/Play-Shapes-windows-x86_64.zip", "ZIP path is stable")
	_check(Policy.REQUIRED_BROWSER_PATHS.size() == 6 and Policy.REQUIRED_BROWSER_PATHS.has("web/public/bubbles_gesture.js") \
		and Policy.REQUIRED_BROWSER_PATHS.has("web/public/character_selection.js"), "every browser module is required in the PCK")
	_check(Policy.REQUIRED_RUNTIME_PATHS.has("minigames/bubbles_and_jellyfishes.tscn") \
		and Policy.REQUIRED_RUNTIME_PATHS.has("assets/runtime/bgm/Beach_music.ogg") \
		and Policy.REQUIRED_RUNTIME_PATHS.has("assets/runtime/sfxs/woosh4.ogg"),
		"Bubbles scene, music, and sound effects remain in the standalone PCK")
	_check(Policy.REQUIRED_RUNTIME_PATHS.has("characters/character_selection.gd") \
		and Policy.REQUIRED_RUNTIME_PATHS.has("assets/runtime/shape_characters/bodies/rhombus.png"),
		"Character selection logic and selectable body assets remain in the standalone PCK")
	_check(Policy.REQUIRED_RUNTIME_PATHS.has("addons/kenyoni/qr_code/qr_code_rect.gd"), "runtime QR addon remains inside the export boundary")
	_check(Policy.validate_templates("res://tests/missing-release.exe", "res://tests/missing-debug.exe").contains("Manage Export Templates"), "missing-template error is actionable")
	_check(Policy.validate_export_result(7, "missing.exe", "missing.pck", "synthetic export failure").contains("exit code 7"), "export errors retain the exit code")
	_check(Policy.validate_export_result(0, "missing.exe", "missing.pck", "").contains("did not create"), "false export success is rejected")
	var metadata := Policy.create_build_info("abc123")
	for key in ["preset", "architecture", "godot_version", "renderer", "build_time_utc", "source_revision"]:
		_check(metadata.has(key), "metadata contains %s" % key)
	_check(metadata.source_revision == "abc123", "metadata keeps the source revision")
	_check(Policy.EXPECTED_ZIP_ENTRIES == [
		"Play-Shapes-windows-x86_64/",
		"Play-Shapes-windows-x86_64/Play Shapes.exe",
		"Play-Shapes-windows-x86_64/Play Shapes.pck",
		"Play-Shapes-windows-x86_64/build-info.json",
	], "ZIP layout contains only the portable executable, external PCK, and metadata")
	var synthetic_pack_text := "prefix"
	for path in Policy.REQUIRED_BROWSER_PATHS:
		synthetic_pack_text += " %s" % path
	var synthetic_pack := (synthetic_pack_text + " suffix").to_utf8_buffer()
	for path in Policy.REQUIRED_BROWSER_PATHS:
		_check(Policy._bytes_contain(synthetic_pack, path.to_utf8_buffer()), "pack verifier finds %s" % path)
	var plugin_source := FileAccess.get_file_as_string("res://addons/standalone_build/standalone_build_plugin.gd")
	_check(plugin_source.contains("OS.execute_with_pipe"), "export uses a non-blocking child process")
	_check(plugin_source.contains("OS.shell_show_in_file_manager"), "successful builds reveal the staging folder")
	_check(plugin_source.contains("ZIPPacker"), "portable artifact uses Godot ZIP support")
	_check(plugin_source.contains("_dialog.size = DIALOG_SIZE"), "build dialog resets its opening size instead of passing only a minimum")
	_check(plugin_source.contains("const DIALOG_SIZE := Vector2i(960, 540)"), "build dialog uses a bounded 16:9 landscape size")
	_check(plugin_source.contains("Vector2(860, 190)"), "details field favors width over excessive height")
	_check(plugin_source.contains("_target_label.clip_text = true"), "long target paths cannot create a tall wrapped minimum size")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_check(project_source.contains("res://addons/standalone_build/plugin.cfg"), "standalone builder plugin is enabled")
	var ignore_source := FileAccess.get_file_as_string("res://.gitignore")
	_check(ignore_source.contains("builds/"), "build output is Git-ignored")
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		_failures += 1
		push_error("FAIL: %s" % description)
