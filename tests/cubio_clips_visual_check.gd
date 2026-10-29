extends TestScript
## Deterministic lab captures of every clip, for source/export comparisons and motion review.

const LAB: PackedScene = preload("res://debug/shape_characters_lab/shape_characters_lab.tscn")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var folder := "res://test-results/cubio/clips"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			folder = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(folder)
	var lab := LAB.instantiate() as ShapeCharactersLab
	root.add_child(lab)
	await process_frame
	await process_frame
	lab.set_blinking(false)
	(lab.get_node("%Tabs") as TabContainer).current_tab = 1
	var player: AnimationPlayer = lab.cubio.animation_player()
	for clip: String in Cubio3D.CLIP_FRAMES:
		lab.choose_face("face_dizzy" if clip == "hit" else Cubio3D.DEFAULT_FACE)
		for sample: int in 4:
			lab.play_clip(clip)
			player.pause()
			player.seek(player.current_animation_length * sample / 4.0, true)
			await process_frame
			await RenderingServer.frame_post_draw
			var path := "%s/%s-%d.png" % [folder, clip, sample]
			check(root.get_texture().get_image().save_png(path) == OK, "Lab capture saved")
	lab.queue_free()
	await process_frame
