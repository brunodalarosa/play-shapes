extends SceneTree
## Saves an empty and maximum-roster lobby capture at the requested runtime size.

const OUTPUT_DIR := "res://test-results/ps-031"

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var lobby := load("res://scenes/lobby.tscn").instantiate() as Control
	root.add_child(lobby)
	await _wait_for_render()
	var size_label := "%dx%d" % [root.size.x, root.size.y]
	_save_capture("%s/empty-%s.png" % [OUTPUT_DIR, size_label])

	var host := root.get_node("SessionHost")
	for index: int in 20:
		var result: Dictionary = host.player_registry.join_player(
			2000 + index, "Player %02d" % (index + 1), true, 2000 + index)
		assert(result.accepted)
	await _wait_for_render()
	_save_capture("%s/roster-20-%s.png" % [OUTPUT_DIR, size_label])
	print("[GODOT-RUNTIME] Lobby captures saved at %s for empty and 20-player states" % size_label)
	quit(0)

func _wait_for_render() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _save_capture(path: String) -> void:
	var image := root.get_texture().get_image()
	assert(image.save_png(path) == OK)
