extends SceneTree
## Captures the launcher over the real lobby renderer for visual review.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	change_scene_to_file("res://scenes/lobby.tscn")
	await scene_changed
	var launcher := root.get_node("DebugLauncher")
	launcher.toggle()
	for unused: int in range(3):
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://test-results/ps-014")
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png("res://test-results/ps-014/debug-launcher.png")
	if error != OK:
		push_error("Could not save debug launcher capture: %s" % error_string(error))
		quit(1)
		return
	print("Saved debug launcher visual check")
	quit(0)
