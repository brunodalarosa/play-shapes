extends SceneTree

const Plugin := preload("res://addons/standalone_build/standalone_build_plugin.gd")
const Policy := preload("res://addons/standalone_build/standalone_build_policy.gd")
const TIMEOUT_SECONDS := 45.0
const FORBIDDEN_PACK_PATHS := [
	"opencode.json",
	"web/package.json",
	"web/package-lock.json",
	"web/tsconfig.json",
	"assets/runtime/shape_characters/manifest.json",
]

var _plugin: EditorPlugin
var _elapsed := 0.0

func _initialize() -> void:
	_plugin = Plugin.new()
	root.add_child(_plugin)
	_plugin._reveal_on_success = false
	_plugin._create_dialog()
	_plugin.call_deferred("_on_build_requested")

func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS:
		push_error("Standalone builder integration test timed out.")
		quit(1)
		return true
	if _plugin._build_active:
		return false
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var staging := root_path.path_join(Policy.STAGING_RELATIVE)
	var archive := root_path.path_join(Policy.ZIP_RELATIVE)
	var executable := staging.path_join(Policy.EXECUTABLE_NAME)
	var pack := staging.path_join(Policy.PACK_NAME)
	var metadata_path := staging.path_join(Policy.METADATA_NAME)
	if not _require(FileAccess.file_exists(executable), "release executable exists"):
		return true
	if not _require(FileAccess.file_exists(pack), "external PCK exists"):
		return true
	if not _require(FileAccess.file_exists(metadata_path), "build metadata exists"):
		return true
	if not _require(FileAccess.file_exists(archive), "portable ZIP exists"):
		return true
	if not _require(Policy.pack_contains_required_runtime_paths(pack).is_empty(), "PCK contains browser routes, host scenes, and runtime QR code"):
		return true
	var forbidden := Policy.pack_contains_any_path(pack, FORBIDDEN_PACK_PATHS)
	if not _require(forbidden.is_empty(), "PCK excludes development-only path: %s" % forbidden):
		return true
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not _require(metadata is Dictionary and metadata.preset == Policy.PRESET_NAME and metadata.architecture == Policy.ARCHITECTURE, "metadata identifies the preset and architecture"):
		return true
	var reader := ZIPReader.new()
	if not _require(reader.open(archive) == OK, "portable ZIP opens"):
		return true
	var entries := Array(reader.get_files())
	entries.sort()
	var expected: Array = Policy.EXPECTED_ZIP_ENTRIES.duplicate()
	expected.sort()
	if not _require(entries == expected, "ZIP contains exactly the executable, PCK, and metadata"):
		reader.close()
		return true
	reader.close()
	print("Standalone builder editor integration checks passed")
	quit(0)
	return true

func _require(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: %s" % description)
		return true
	push_error("FAIL: %s" % description)
	quit(1)
	return false
