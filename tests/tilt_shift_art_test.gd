extends SceneTree
## Load the committed art and check its shared pivots, alpha and contact references.

const MANIFEST_PATH := "res://art/tilt_shift/import_manifest.json"

var _failures: PackedStringArray = []


func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var runtime_root: String = "res://" + str(manifest["runtime_root"])
	var paddle_size := Vector2i.ZERO
	var basket_width := 0
	var checked := 0

	_check(manifest["assets"].size() == 22, "The art manifest must describe every supplied part")

	for entry: Dictionary in manifest["assets"]:
		var path: String = runtime_root.path_join(entry["path"])
		var texture := load(path) as Texture2D

		_check(texture != null, "Texture failed to load: " + path)
		if texture == null:
			continue

		var expected_size := Vector2i(int(entry["size"][0]), int(entry["size"][1]))
		_check(Vector2i(texture.get_size()) == expected_size, "Wrong texture dimensions: " + path)

		var config := ConfigFile.new()
		_check(config.load(path + ".import") == OK, "Missing texture import policy: " + path)
		for key: String in manifest["import_policy"]:
			_check(
				config.get_value("params", key) == manifest["import_policy"][key],
				"Wrong texture import policy: " + path + ": " + key,
			)

		var image := texture.get_image()
		_check(image != null and image.has_mipmaps(), "Missing texture mipmaps: " + path)

		if entry.has("anchors_px") and image != null:
			for anchor: String in entry["anchors_px"]:
				var point: Array = entry["anchors_px"][anchor]
				var pixel := Vector2i(int(point[0]), int(point[1]))
				var inside := Rect2i(Vector2i.ZERO, expected_size).has_point(pixel)
				_check(inside, "Contact point outside sprite: " + path + ": " + anchor)
				if inside:
					var alpha := image.get_pixelv(pixel).a
					_check(
						alpha > 0.5,
						"Contact point outside visible art: " + path + ": " + anchor,
					)

		var group: String = entry.get("canvas_group", "")
		if group == "paddle":
			if paddle_size == Vector2i.ZERO:
				paddle_size = expected_size
			_check(expected_size == paddle_size, "Paddle variants have different canvas sizes")
			_check(entry["pivot_normalized"] == [0.5, 0.5], "Paddle variant has a different pivot")
		elif group == "basket":
			if basket_width == 0:
				basket_width = expected_size.x
			_check(expected_size.x == basket_width, "Basket layers have different canvas widths")
			var margins: Array = entry["horizontal_cap_margins_px"]
			_check(
				float(margins[0]) == 64.0 and float(margins[1]) == 64.0,
				"Basket cap geometry differs",
			)

		checked += 1

	for failure: String in _failures:
		push_error(failure)

	if _failures.is_empty():
		print("TILT_SHIFT_ART_LOAD_OK: %d imported textures and contact references" % checked)

	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
