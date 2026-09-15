extends SceneTree
## Real-renderer captures for human review; screenshots are not creative approval.

func _initialize() -> void: _capture.call_deferred()

func _capture() -> void:
	change_scene_to_file("res://debug/character_animation_system.tscn")
	await scene_changed
	DirAccess.make_dir_recursive_absolute("res://test-results/ps-012")
	for index: int in HybridCharacterAnimator.DANCE_STYLES.size():
		current_scene.get_node("%StylePicker").select(index)
		current_scene._select_style(index)
		await _wait_frames(10)
		if not _save("dance-%s" % HybridCharacterAnimator.DANCE_STYLES[index]): return
	current_scene._held = true
	current_scene._charge = 1.0
	for index: int in HybridCharacterAnimator.DIRECTIONS.size():
		current_scene._direction_index = index
		await _wait_frames(4)
		if not _save("command-%s" % HybridCharacterAnimator.DIRECTIONS[index]): return
	current_scene._reaction(&"survived")
	await _wait_frames(8)
	if not _save("survived"): return
	current_scene._toggle_elimination()
	await _wait_frames(4)
	if not _save("eliminated"): return
	print("Saved PS-012 visual review captures")
	quit(0)

func _wait_frames(count: int) -> void:
	for unused: int in count: await process_frame

func _save(label: String) -> bool:
	var error := root.get_viewport().get_texture().get_image().save_png("res://test-results/ps-012/%s.png" % label)
	if error != OK:
		push_error("Could not save %s: %s" % [label, error_string(error)])
		quit(1)
		return false
	return true
