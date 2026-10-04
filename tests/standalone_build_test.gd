extends TestScript

const Policy := preload("res://addons/standalone_build/standalone_build_policy.gd")


func _run() -> void:
	check(
		Policy.validate_preset("res://export_presets.cfg").is_empty(),
		"release preset name, platform, architecture, paths, and filters are valid",
	)
	var missing_preset_config := ConfigFile.new()
	missing_preset_config.set_value("preset.0", "name", "Some Other Preset")
	var missing_preset_path := "res://test-results/standalone-build-missing-preset.cfg"
	check(
		missing_preset_config.save(missing_preset_path) == OK,
		"missing-preset fixture can be written",
	)
	check(
		Policy.validate_preset(missing_preset_path).contains("is missing"),
		"missing named preset fails before export",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(missing_preset_path))
	check(
		Policy.validate_owned_paths(ProjectSettings.globalize_path("res://")).is_empty(),
		"owned build paths stay below builds/standalone",
	)
	check(Policy.STAGING_RELATIVE == "builds/standalone/windows-x86_64", "staging path is stable")
	check(
		Policy.ZIP_RELATIVE == "builds/standalone/Play-Shapes-windows-x86_64.zip",
		"ZIP path is stable",
	)
	check(
		Policy.REQUIRED_BROWSER_PATHS.has("web/public/manifest.webmanifest")
		and Policy.REQUIRED_BROWSER_PATHS.has("web/public/app-icon-512.png")
		and Policy.REQUIRED_BROWSER_PATHS.has("web/public/app.js"),
		"the bundled phone client and its page assets are required in the PCK",
	)
	check(
		Policy
		.REQUIRED_RUNTIME_PATHS
		.has("minigames/002_bubbles_and_jellyfishes/bubbles_and_jellyfishes.tscn") \
				and Policy.REQUIRED_RUNTIME_PATHS.has("assets/runtime/bgm/Beach_music.ogg") \
				and Policy.REQUIRED_RUNTIME_PATHS.has("assets/runtime/sfxs/woosh4.ogg"),
		"Bubbles scene, music, and sound effects remain in the standalone PCK",
	)
	check(
		Policy.REQUIRED_RUNTIME_PATHS.has("host/pre_minigame_readiness.gd") \
				and Policy.REQUIRED_RUNTIME_PATHS.has("scenes/pre_minigame_screen.tscn") \
				and Policy
		.REQUIRED_RUNTIME_PATHS
		.has("minigames/002_bubbles_and_jellyfishes/bubbles_pre_minigame_content.tres") \
				and Policy
		.REQUIRED_RUNTIME_PATHS
		.has("assets/runtime/pre_minigame/bubbles_preview.png"),
		"Ready screen, content, and gameplay preview remain in the standalone PCK",
	)
	check(
		Policy.REQUIRED_RUNTIME_PATHS.has("characters/character_selection.gd") \
				and Policy.REQUIRED_RUNTIME_PATHS.has("characters/squircle_v1_playback.tscn") \
				and Policy
		.REQUIRED_RUNTIME_PATHS
		.has("assets/runtime/animated_characters/squircle/v1/idle-front-colorable.png"),
		"Squircle playback and approved sheets remain in the standalone PCK",
	)
	check(
		Policy.REQUIRED_RUNTIME_PATHS.has("addons/kenyoni/qr_code/qr_code_rect.gd"),
		"runtime QR addon remains inside the export boundary",
	)
	check(
		Policy
		.validate_templates("res://tests/missing-release.exe", "res://tests/missing-debug.exe")
		.contains("Manage Export Templates"),
		"missing-template error is actionable",
	)
	check(
		Policy
		.validate_export_result(7, "missing.exe", "missing.pck", "synthetic export failure")
		.contains("exit code 7"),
		"export errors retain the exit code",
	)
	check(
		Policy
		.validate_export_result(0, "missing.exe", "missing.pck", "")
		.contains("did not create"),
		"false export success is rejected",
	)
	var metadata := Policy.create_build_info("abc123")
	for key in [
		"preset",
		"architecture",
		"godot_version",
		"renderer",
		"build_time_utc",
		"source_revision",
	]:
		check(metadata.has(key), "metadata contains %s" % key)
	check(metadata.source_revision == "abc123", "metadata keeps the source revision")
	check(
		Policy.EXPECTED_ZIP_ENTRIES
		== [
			"Play-Shapes-windows-x86_64/",
			"Play-Shapes-windows-x86_64/Play Shapes.exe",
			"Play-Shapes-windows-x86_64/Play Shapes.pck",
			"Play-Shapes-windows-x86_64/build-info.json",
		],
		"ZIP layout contains only the portable executable, external PCK, and metadata",
	)
	var synthetic_pack_text := "prefix"
	for path in Policy.REQUIRED_BROWSER_PATHS:
		synthetic_pack_text += " %s" % path
	var synthetic_pack := (synthetic_pack_text + " suffix").to_utf8_buffer()
	for path in Policy.REQUIRED_BROWSER_PATHS:
		check(
			Policy._bytes_contain(synthetic_pack, path.to_utf8_buffer()),
			"pack verifier finds %s" % path,
		)
	var plugin_source := FileAccess.get_file_as_string(
		"res://addons/standalone_build/standalone_build_plugin.gd"
	)
	check(
		plugin_source.contains("OS.execute_with_pipe"),
		"export uses a non-blocking child process",
	)
	check(
		plugin_source.contains("OS.shell_show_in_file_manager"),
		"successful builds reveal the staging folder",
	)
	check(plugin_source.contains("ZIPPacker"), "portable artifact uses Godot ZIP support")
	check(
		plugin_source.contains("_dialog.size = DIALOG_SIZE"),
		"build dialog resets its opening size instead of passing only a minimum",
	)
	check(
		plugin_source.contains("const DIALOG_SIZE := Vector2i(960, 540)"),
		"build dialog uses a bounded 16:9 landscape size",
	)
	check(
		plugin_source.contains("Vector2(860, 190)"),
		"details field favors width over excessive height",
	)
	check(
		plugin_source.contains("_target_label.clip_text = true"),
		"long target paths cannot create a tall wrapped minimum size",
	)
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	check(
		project_source.contains("res://addons/standalone_build/plugin.cfg"),
		"standalone builder plugin is enabled",
	)
	var ignore_source := FileAccess.get_file_as_string("res://.gitignore")
	check(ignore_source.contains("builds/"), "build output is Git-ignored")
