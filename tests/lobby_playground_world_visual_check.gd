extends SceneTree
## Captures the isolated empty world at the active host resolution for visual review.

const OUTPUT_DIR := "res://test-results/lobby-playground-world"

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.add_child(load("res://scenes/lobby_playground_world.tscn").instantiate())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/empty-%dx%d.png" % [OUTPUT_DIR, image.get_width(), image.get_height()]
	assert(image.save_png(path) == OK)
	print("[GODOT-RUNTIME] Empty playground capture: %s" % path)
	quit(0)
