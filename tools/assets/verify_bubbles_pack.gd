extends SceneTree
## Run from an empty project so source-tree resources cannot hide missing pack art.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected: -- <absolute pack.pck> <absolute extraction_manifest.json>")
		quit(1)
		return
	if not ProjectSettings.load_resource_pack(args[0]):
		push_error("Cannot mount exported pack")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var checked := 0
	for entry: Dictionary in manifest["assets"]:
		var path: String = "res://assets/runtime/minigames/bubbles_and_jellyfishes/" + entry["path"]
		var import_config := ConfigFile.new()
		if import_config.load(path + ".import") != OK:
			fail("Missing packed import remap: " + path)
			return
		var imported_path: String = import_config.get_value("remap", "path", "")
		if imported_path.is_empty() or not FileAccess.file_exists(imported_path):
			fail("Missing packed texture bytes: " + path)
			return
		var texture := load(path) as Texture2D
		if texture == null or texture.get_width() != int(entry["size"][0]) or texture.get_height() != int(entry["size"][1]):
			fail("Packed texture could not load at expected dimensions: " + path)
			return
		checked += 1
	print("BUBBLES_PACK_OK: %d textures loaded from isolated export pack" % checked)
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
