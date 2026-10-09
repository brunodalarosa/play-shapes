extends SceneTree
## Run from an empty project so checkout resources cannot hide missing packed textures.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		_fail("Expected: -- <absolute pack.pck> <absolute import_manifest.json>")
		return

	if not ProjectSettings.load_resource_pack(args[0]):
		_fail("Cannot mount exported pack")
		return

	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var runtime_root: String = "res://" + str(manifest["runtime_root"])
	var checked := 0

	for entry: Dictionary in manifest["assets"]:
		var path: String = runtime_root.path_join(entry["path"])
		var config := ConfigFile.new()
		if config.load(path + ".import") != OK:
			_fail("Missing packed import remap: " + path)
			return

		var imported_path: String = config.get_value("remap", "path", "")
		if imported_path.is_empty() or not FileAccess.file_exists(imported_path):
			_fail("Missing packed texture bytes: " + path)
			return

		var texture := load(path) as Texture2D
		var expected_size := Vector2i(int(entry["size"][0]), int(entry["size"][1]))
		if texture == null or Vector2i(texture.get_size()) != expected_size:
			_fail("Packed texture failed to load at expected dimensions: " + path)
			return

		checked += 1

	for source: String in manifest["sources"]:
		if FileAccess.file_exists("res://art/tilt_shift/sources/" + source):
			_fail("Source-only art leaked into the export")
			return

	print("TILT_SHIFT_PACK_OK: %d textures loaded from isolated export pack" % checked)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
