extends SceneTree
## Real-renderer evidence for the dance extremes and four committed silhouettes.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	change_scene_to_file("res://debug/character_animation_lab.tscn")
	await scene_changed
	var lab := current_scene
	lab.get_node("%AutoPreview").button_pressed = false
	DirAccess.make_dir_recursive_absolute("res://test-results/ps-011")
	await _wait_frames(3)
	if not _save("dance-a"):
		return
	await create_timer(0.22).timeout
	if not _save("dance-b"):
		return
	for direction: StringName in [&"up", &"left", &"right", &"down"]:
		lab.charge_state.reset()
		lab.charge_state.advance(0.0, direction)
		lab.charge_state.advance(lab.charge_fill_seconds, direction)
		lab._button_direction = direction
		await _wait_frames(4)
		if not _save(direction):
			return
		lab._button_direction = &""
	print("Saved animation lab visual checks")
	quit(0)

func _wait_frames(count: int) -> void:
	for unused: int in count:
		await process_frame

func _save(label: StringName) -> bool:
	var path := "res://test-results/ps-011/%s.png" % label
	var error := root.get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return false
	return true
