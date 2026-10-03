extends SceneTree
## Technical composition captures; generated files remain outside the runtime bundle.

const SCENE: PackedScene = preload("res://scenes/pre_minigame_screen.tscn")
const OUTPUT := "res://test-results/pre-minigame"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for count: int in [2, 10]:
		for dimensions: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
			root.size = dimensions
			root.content_scale_size = Vector2i(1920, 1080)
			var screen := SCENE.instantiate() as PreMinigameScreen
			root.add_child(screen)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var players: Array[Dictionary] = []
			for index: int in count:
				players.append(
					{
						"player_id": "p%d" % index,
						"name": "Player %d" % (index + 1),
						"seat": index + 1,
						"character_color": ["#598DF2", "#EE7C6E", "#96CB6A"][index % 3],
						"ready": index % 2 == 0,
					}
				)
			screen.configure(&"bubbles", { "players": players })
			for frame: int in 6:
				await process_frame
			var image := root.get_viewport().get_texture().get_image()
			if (
				image.is_empty()
				or image.save_png(
					OUTPUT.path_join("%d-%dx%d.png" % [count, dimensions.x, dimensions.y])
				)
				!= OK
			):
				push_error("Could not save ready screen")
				quit(1)
				return
			screen.queue_free()
			await process_frame
	print("Saved pre-minigame tabletop captures")
	quit(0)
