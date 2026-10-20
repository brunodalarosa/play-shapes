extends TestScript
## Tilt Shift 3D stands alone: no file of it, of the shared components it builds on, of its
## workshop, review, phone modules or tests names a script, scene, resource, asset, message,
## route or phone module of the 2D Tilt Shift, and no resource it loads depends on one, so
## retiring that minigame cannot break this one.

const SELF := "res://minigames/005_3d_tilt_shift/tests/tilt_shift_3d_independence_test.gd"
const FOLDERS: Array[String] = [
	"res://minigames/005_3d_tilt_shift",
	"res://components/rounded_bar",
	"res://components/shape_face",
	"res://components/plane_3d",
	"res://addons/tilt_shift_3d_workshop",
	"res://web/src/005_3d_tilt_shift",
	"res://web/src/shape_paddle",
	"res://web/tests/005_3d_tilt_shift",
]
const FILES: Array[String] = [
	"res://components/screen_follow_label.gd",
	"res://host/minigame_protocol.gd",
	"res://debug/tilt_shift_3d_review.gd",
	"res://debug/tilt_shift_3d_review.tscn",
	"res://tests/e2e/tilt_shift_3d_host.gd",
	"res://tests/tilt_shift_3d_review_test.gd",
	"res://tests/tilt_shift_3d_props_test.gd",
	"res://web/e2e/tilt_shift_3d_phones.spec.ts",
	"res://web/src/three_view/shape_paddle.ts",
	"res://web/src/three_view/viewport.ts",
]
const TEXT_EXTENSIONS: Array[String] = [
	"gd",
	"tscn",
	"tres",
	"gdshader",
	"ts",
	"mjs",
	"md",
	"cfg",
	"json",
]
## 2D names that tests may use only to prove they are refused, or to stub what the shared phone
## page loads anyway.
const REFUSED: Array[String] = ["/tilt-shift/", "tilt_shift_ready", "tilt_shift_snapshot"]
const FORBIDDEN: Array[String] = [
	"003_tilt_shift",
	"minigames/003",
	"addons/tilt_shift_workshop",
	"tilt_shift_snapshot",
	"tilt_shift_ready",
	"tilt_shift_phone",
	"/tilt-shift/",
	"tilt_shift_review",
	"tilt-paddle",
	"tilt-actions",
]


func _run() -> void:
	var files := FILES.duplicate()
	for folder: String in FOLDERS:
		files.append_array(_text_files(folder))
	check(files.size() > 60, "The scan covers the minigame, its components and its phone code")
	# A 2D class is TiltShift followed by a capital letter; 3D classes continue with 3D.
	var classes := RegEx.create_from_string("\\bTiltShift(?!3D)[A-Z]\\w*")
	for path: String in files:
		if path == SELF:
			continue
		var text := FileAccess.get_file_as_string(path)
		var is_test := path.contains("/tests/")
		for name: String in FORBIDDEN:
			if is_test and name in REFUSED:
				continue
			check(not text.contains(name), "%s does not name %s" % [path, name])
		var found := classes.search(text)
		check(
			found == null,
			"%s names no 2D Tilt Shift class (%s)" % [path, found.get_string() if found else ""],
		)

	var definition := "res://minigames/005_3d_tilt_shift/tilt_shift_3d_minigame.tres"
	for root_path: String in [
		definition,
		"res://minigames/005_3d_tilt_shift/3d_tilt_shift.tscn",
		"res://minigames/005_3d_tilt_shift/tuning/Default.tres",
		"res://debug/tilt_shift_3d_review.tscn",
	]:
		for dependency: String in _dependencies(root_path):
			check(
				not dependency.contains("003"),
				"%s depends on no 2D Tilt Shift file (%s)" % [root_path, dependency],
			)


func _dependencies(path: String) -> PackedStringArray:
	var seen := PackedStringArray()
	var queue := [path]
	while not queue.is_empty():
		var current: String = queue.pop_back()
		for entry: String in ResourceLoader.get_dependencies(current):
			var dependency := entry.get_slice("::", entry.get_slice_count("::") - 1)
			if dependency.begins_with("uid://"):
				dependency = ResourceUID.get_id_path(ResourceUID.text_to_id(dependency))
			if dependency.is_empty() or seen.has(dependency):
				continue
			seen.append(dependency)
			if dependency.get_extension() in ["tscn", "tres"]:
				queue.append(dependency)
	return seen


func _text_files(folder: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(folder)
	if directory == null:
		check(false, "%s exists" % folder)
		return result
	for name: String in directory.get_files():
		if name.get_extension() in TEXT_EXTENSIONS:
			result.append(folder.path_join(name))
	for name: String in directory.get_directories():
		result.append_array(_text_files(folder.path_join(name)))
	return result
