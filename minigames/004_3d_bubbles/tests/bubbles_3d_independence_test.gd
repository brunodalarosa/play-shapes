extends TestScript
## Bubbles and jellyfishes 3D stands alone: no file of it, of the shared components it builds on
## or of its phone modules names a script, scene, resource, asset, message or route of the 2D
## Bubbles minigame, so retiring that minigame cannot break this one. Nothing mentions spin.

const SELF := "res://minigames/004_3d_bubbles/tests/bubbles_3d_independence_test.gd"
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
## 2D names that tests may use only to prove they are refused or ignored.
const REFUSED_MESSAGES: Array[String] = [
	"bubbles_trace",
	"bubbles_charge",
	"bubbles_snapshot",
	"bubbles-jellyfish.png",
	"bubbles-phone-background.png",
]
## Names of the 2D minigame's folders, classes, messages and phone routes.
const FORBIDDEN: Array[String] = [
	"002_bubbles_and_jellyfishes",
	"minigames/bubbles_and_jellyfishes",
	"BubblesRoundController",
	"BubblesTuning",
	"BubblesProtocol",
	"BubblesPresentation",
	"BubblesPlayerArena",
	"BubblesPlayerBubble",
	"BubblesPlayerVisual",
	"BubblesCreatureArena",
	"BubblesJellyfish",
	"BubblesPufferfish",
	"BubblesGestureClassifier",
	"bubbles_trace",
	"bubbles_charge",
	"bubbles_snapshot",
	"bubbles_feedback",
	"bubbles_visual",
	"bubbles-jellyfish.png",
	"bubbles-phone-background.png",
	"bubbles_gesture",
]


func _run() -> void:
	var files := FILES.duplicate()
	for folder: String in FOLDERS:
		files.append_array(_text_files(folder))
	check(files.size() > 30, "The scan covers the minigame, its components and its phone code")
	var spin := RegEx.create_from_string("(?i)\\bspin")
	for path: String in files:
		if path == SELF:
			continue
		var text := FileAccess.get_file_as_string(path)
		# A test may name a refused message or spin only to check that it is absent.
		var is_test := path.contains("/tests/")
		for name: String in FORBIDDEN:
			if is_test and name in REFUSED_MESSAGES:
				continue
			check(not text.contains(name), "%s does not name %s" % [path, name])
		if not is_test:
			check(spin.search(text) == null, "%s does not mention spin" % path)

	var definition := load("res://minigames/004_3d_bubbles/bubbles_3d_minigame.tres")
	for dependency: String in ResourceLoader.get_dependencies(definition.resource_path):
		check(not dependency.contains("002_"), "The catalog entry depends on no 002 file")
	for dependency: String in ResourceLoader.get_dependencies(definition.scene_path):
		check(not dependency.contains("002_"), "The scene depends on no 002 file")


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
