extends SceneTree
## Real-renderer captures for the human PS-018 placement review.

const STAGE_SCENE: PackedScene = preload("res://minigames/dancer_simon_says.tscn")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var stage := STAGE_SCENE.instantiate() as Control
	root.add_child(stage)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://test-results/ps-018")
	var full_image := root.get_texture().get_image()
	assert(full_image.save_png("res://test-results/ps-018/stage-10-players.png") == OK)
	stage.set("preview_player_count", 2)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var small_image := root.get_texture().get_image()
	assert(small_image.save_png("res://test-results/ps-018/stage-2-players.png") == OK)
	print("PS-018 renderer captures saved for 10-player and 2-player review")
	quit(0)
