extends TestScript
## Bubbles and jellyfishes 3D has no spin move: no file of it, of the shared components it builds
## on or of its phone modules mentions spin.

const SELF := "res://minigames/004_3d_bubbles/tests/bubbles_3d_no_spin_test.gd"
const FOLDERS: Array[String] = [
	"res://minigames/004_3d_bubbles",
	"res://components/plane_3d",
	"res://components/bubble_shell",
	"res://components/underwater_environment",
	"res://web/src/004_3d_bubbles",
	"res://web/src/three_view",
	"res://web/tests/004_3d_bubbles",
]
const FILES: Array[String] = [
	"res://components/screen_follow_label.gd",
	"res://host/minigame_protocol.gd",
]
const TEXT_EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "gdshader", "ts", "mjs", "md"]


func _run() -> void:
	var files := FILES.duplicate()
	for folder: String in FOLDERS:
		files.append_array(_text_files(folder))
	check(files.size() > 30, "The scan covers the minigame, its components and its phone code")
	var spin := RegEx.create_from_string("(?i)\\bspin")
	for path: String in files:
		if path == SELF or path.contains("/tests/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		check(spin.search(text) == null, "%s does not mention spin" % path)


func _text_files(folder: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return found
	for file: String in directory.get_files():
		if file.get_extension() in TEXT_EXTENSIONS:
			found.append(folder.path_join(file))
	for child: String in directory.get_directories():
		found.append_array(_text_files(folder.path_join(child)))
	return found
