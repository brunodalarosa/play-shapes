extends SceneTree
## Render player bubbles against viewport edges at FHD and HD sizes.

const SCENE: PackedScene = preload("res://minigames/bubbles_and_jellyfishes.tscn")
const OUTPUT := "res://test-results/ps-047"

var _failures := 0


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	await _capture_size(Vector2i(1920, 1080))
	await _capture_size(Vector2i(1280, 720))
	print("Bubbles viewport captures: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _capture_size(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	root.content_scale_size = viewport_size
	var view := SCENE.instantiate() as BubblesPresentation
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)
	var tuning := BubblesTuning.new()
	tuning.instructions_seconds = 0.0
	tuning.countdown_seconds = 0.0
	tuning.round_duration_seconds = 30.0
	tuning.starting_jellyfish = 0
	tuning.jellyfish_low_spawn_rate = 0.0
	tuning.jellyfish_high_spawn_rate = 0.0
	tuning.pufferfish_start_spawn_rate = 0.0
	tuning.pufferfish_max_spawn_rate = 0.0
	view.controller.tuning = tuning
	var start_time := Time.get_ticks_msec()
	_check(view.start_round([
		{"player_id": "left", "name": "Left", "seat": 1},
		{"player_id": "right", "name": "Right", "seat": 2},
	], start_time).accepted, "%s scene starts" % viewport_size)
	view.controller.complete_entrance(start_time)
	view.controller.advance(start_time)
	if view._entrance_tween != null:
		view._entrance_tween.kill()
	view._cue.visible = false
	view.set_process(false)
	view.set_physics_process(false)
	var bounds := view.player_arena.wall_bounds
	var left_bubble := view.player_arena.get_bubble("left")
	var right_bubble := view.player_arena.get_bubble("right")
	var left_radius := left_bubble.collision_radius() * left_bubble.global_transform.x.length()
	var right_radius := right_bubble.collision_radius() * right_bubble.global_transform.x.length()
	left_bubble.global_position = Vector2(bounds.position.x + left_radius, bounds.get_center().y)
	left_bubble.velocity = Vector2.LEFT * 100.0
	right_bubble.global_position = Vector2(bounds.end.x - right_radius, bounds.get_center().y)
	right_bubble.velocity = Vector2.RIGHT * 100.0
	var host_time := maxi(Time.get_ticks_msec(), view.controller.last_host_time_msec())
	_check(view.player_arena.simulate_step(0.05, host_time), "%s edge step is accepted" % viewport_size)
	_check(left_bubble.velocity.x > 0.0 and right_bubble.velocity.x < 0.0, "%s edge bubbles rebound inward" % viewport_size)
	_check(left_bubble.global_position.x >= bounds.position.x + left_radius - 0.001, "%s left bubble remains fully visible" % viewport_size)
	_check(right_bubble.global_position.x <= bounds.end.x - right_radius + 0.001, "%s right bubble remains fully visible" % viewport_size)
	await _frames(3)
	_save("viewport-edges-%dx%d.png" % [viewport_size.x, viewport_size.y])
	view.queue_free()
	await _frames(3)


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame


func _save(file_name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(OUTPUT.path_join(file_name)) != OK:
		push_error("Could not save %s" % file_name)
		_failures += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
