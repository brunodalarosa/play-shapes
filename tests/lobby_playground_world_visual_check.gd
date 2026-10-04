extends TestScript
## Captures the isolated empty world at the active host resolution for visual review.

const OUTPUT_DIR := "res://test-results/lobby-playground-world"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.add_child(load("res://scenes/lobby_playground_world.tscn").instantiate())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/empty-%dx%d.png" % [OUTPUT_DIR, image.get_width(), image.get_height()]
	check(image.save_png(path) == OK, "The capture is saved")
	print("[GODOT-RUNTIME] Empty playground capture: %s" % path)
