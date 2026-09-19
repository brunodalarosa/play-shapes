@tool
class_name StandaloneBuildPolicy
extends RefCounted

const PRESET_NAME := "Play Shapes Windows Release"
const PLATFORM := "Windows Desktop"
const ARCHITECTURE := "x86_64"
const STAGING_RELATIVE := "builds/standalone/windows-x86_64"
const EXECUTABLE_NAME := "Play Shapes.exe"
const PACK_NAME := "Play Shapes.pck"
const METADATA_NAME := "build-info.json"
const ZIP_RELATIVE := "builds/standalone/Play-Shapes-windows-x86_64.zip"
const INCLUDE_FILTER := "web/public/*.html,web/public/*.css,web/public/*.js"
const EXCLUDE_FILTER := "addons/godot_mcp/**,addons/standalone_build/**,assets/Kenney_Shape_Characters/**,assets/runtime/shape_characters/manifest.json,art/**,builds/**,opencode.json,tools/**,tests/**,test-results/**,web/*.json,web/node_modules/**,web/src/**,web/tests/**"
const REQUIRED_BROWSER_PATHS := [
	"web/public/index.html",
	"web/public/app.js",
	"web/public/controller_geometry.js",
	"web/public/style.css",
]
const REQUIRED_RUNTIME_PATHS := [
	"web/public/index.html",
	"web/public/app.js",
	"web/public/controller_geometry.js",
	"web/public/style.css",
	"addons/kenyoni/qr_code/qr_code_rect.gd",
	"scenes/boot.tscn",
	"scenes/lobby.tscn",
]
const EXPECTED_ZIP_ENTRIES := [
	"Play-Shapes-windows-x86_64/",
	"Play-Shapes-windows-x86_64/Play Shapes.exe",
	"Play-Shapes-windows-x86_64/Play Shapes.pck",
	"Play-Shapes-windows-x86_64/build-info.json",
]

static func validate_preset(config_path: String) -> String:
	var config := ConfigFile.new()
	var load_error := config.load(config_path)
	if load_error != OK:
		return "Cannot read export_presets.cfg (error %d)." % load_error
	var preset_section := _find_preset_section(config, PRESET_NAME)
	if preset_section.is_empty():
		return "Export preset '%s' is missing. Restore it in export_presets.cfg." % PRESET_NAME
	if config.get_value(preset_section, "platform", "") != PLATFORM:
		return "Preset '%s' must use the %s platform." % [PRESET_NAME, PLATFORM]
	if config.get_value(preset_section, "include_filter", "") != INCLUDE_FILTER:
		return "Preset '%s' has an unexpected browser include filter." % PRESET_NAME
	if config.get_value(preset_section, "exclude_filter", "") != EXCLUDE_FILTER:
		return "Preset '%s' has an unexpected development-file exclude filter." % PRESET_NAME
	if config.get_value(preset_section, "export_path", "") != STAGING_RELATIVE.path_join(EXECUTABLE_NAME):
		return "Preset '%s' must export only inside %s." % [PRESET_NAME, STAGING_RELATIVE]
	var options_section := "%s.options" % preset_section
	if config.get_value(options_section, "binary_format/architecture", "") != ARCHITECTURE:
		return "Preset '%s' must target %s." % [PRESET_NAME, ARCHITECTURE]
	if config.get_value(options_section, "binary_format/embed_pck", true):
		return "Preset '%s' must keep the PCK external." % PRESET_NAME
	if config.get_value(options_section, "debug/export_console_wrapper", 1) != 0:
		return "Preset '%s' must disable the console wrapper." % PRESET_NAME
	return ""

static func standard_release_template_path() -> String:
	return _standard_template_root().path_join("windows_release_x86_64.exe")

static func standard_debug_template_path() -> String:
	return _standard_template_root().path_join("windows_debug_x86_64.exe")

static func _standard_template_root() -> String:
	var version := Engine.get_version_info()
	var folder := "%d.%d.%d.%s" % [version.major, version.minor, version.patch, version.status]
	return OS.get_environment("APPDATA").path_join("Godot/export_templates").path_join(folder)

static func validate_templates(release_path: String, debug_path: String) -> String:
	var missing := PackedStringArray()
	if not FileAccess.file_exists(release_path):
		missing.append(release_path)
	# Godot validates both standard template files before allowing this preset to export,
	# even though the one-click command itself always requests a release artifact.
	if not FileAccess.file_exists(debug_path):
		missing.append(debug_path)
	if not missing.is_empty():
		return "The matching Godot Windows x86_64 export templates are missing. Install them from Editor > Manage Export Templates, then retry. Expected:\n- %s" % "\n- ".join(missing)
	return ""

static func validate_owned_paths(project_root: String) -> String:
	var root := project_root.simplify_path().trim_suffix("/")
	var staging := root.path_join(STAGING_RELATIVE).simplify_path()
	var archive := root.path_join(ZIP_RELATIVE).simplify_path()
	if not staging.begins_with(root + "/builds/standalone/"):
		return "Refusing to clean an unowned staging path: %s" % staging
	if not archive.begins_with(root + "/builds/standalone/"):
		return "Refusing to replace an unowned ZIP path: %s" % archive
	return ""

static func validate_export_result(exit_code: int, executable_path: String, pack_path: String, output: String) -> String:
	if exit_code != 0:
		return "Godot export failed with exit code %d.\n\n%s" % [exit_code, _tail(output)]
	if not FileAccess.file_exists(executable_path):
		return "Export reported success but did not create %s." % executable_path
	if not FileAccess.file_exists(pack_path):
		return "Export reported success but did not create the external PCK: %s." % pack_path
	return ""

static func pack_contains_required_browser_paths(pack_path: String) -> PackedStringArray:
	return pack_missing_paths(pack_path, REQUIRED_BROWSER_PATHS)

static func pack_contains_required_runtime_paths(pack_path: String) -> PackedStringArray:
	return pack_missing_paths(pack_path, REQUIRED_RUNTIME_PATHS)

static func pack_missing_paths(pack_path: String, required_paths: Array) -> PackedStringArray:
	var missing := PackedStringArray()
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		missing.append("<unreadable PCK>")
		return missing
	var bytes := file.get_buffer(file.get_length())
	for path in required_paths:
		if not _bytes_contain(bytes, path.to_utf8_buffer()):
			missing.append(path)
	return missing

static func pack_contains_any_path(pack_path: String, paths: Array) -> String:
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		return "<unreadable PCK>"
	var bytes := file.get_buffer(file.get_length())
	for path in paths:
		if _bytes_contain(bytes, path.to_utf8_buffer()):
			return path
	return ""

static func _bytes_contain(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty() or needle.size() > haystack.size():
		return false
	var last_start := haystack.size() - needle.size()
	var start := haystack.find(needle[0])
	while start >= 0 and start <= last_start:
		var matches := true
		for offset in range(needle.size()):
			if haystack[start + offset] != needle[offset]:
				matches = false
				break
		if matches:
			return true
		start = haystack.find(needle[0], start + 1)
	return false

static func create_build_info(source_revision: String) -> Dictionary:
	return {
		"preset": PRESET_NAME,
		"architecture": ARCHITECTURE,
		"godot_version": Engine.get_version_info().string,
		"renderer": "gl_compatibility",
		"build_time_utc": Time.get_datetime_string_from_system(true, true),
		"source_revision": source_revision,
	}

static func _find_preset_section(config: ConfigFile, preset_name: String) -> String:
	for section in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			if config.get_value(section, "name", "") == preset_name:
				return section
	return ""

static func _tail(output: String, limit := 6000) -> String:
	if output.length() <= limit:
		return output
	return "...\n" + output.right(limit)
