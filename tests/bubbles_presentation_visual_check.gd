extends SceneTree
## Local renderer captures for PS-045; saved under ignored test-results.

const SCENE: PackedScene = preload("res://minigames/bubbles_and_jellyfishes.tscn")
const OUTPUT := "res://test-results/ps-045"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	var empty := SCENE.instantiate() as BubblesPresentation
	root.add_child(empty)
	empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(5)
	_save("empty-fhd")
	empty.queue_free()
	await _frames(2)

	var stage := SCENE.instantiate() as BubblesPresentation
	root.add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)
	var tuning := BubblesTuning.new()
	tuning.instructions_seconds = 0.0
	tuning.countdown_seconds = 0.0
	tuning.round_duration_seconds = 60.0
	tuning.starting_jellyfish = 0
	tuning.jellyfish_low_spawn_rate = 0.0
	tuning.jellyfish_high_spawn_rate = 0.0
	tuning.pufferfish_start_spawn_rate = 0.0
	tuning.pufferfish_max_spawn_rate = 0.0
	stage.controller.tuning = tuning
	var roster: Array = []
	for index: int in 10:
		roster.append({"player_id": "p%d" % index, "name": "Player %d" % (index + 1), "seat": index + 1})
	var now := Time.get_ticks_msec()
	stage.start_round(roster, now)
	await _frames(4)
	_save("instructions-fhd")
	var entrance_time := maxi(now, stage.controller.last_host_time_msec())
	stage.controller.complete_entrance(entrance_time)
	stage.controller.advance(entrance_time)
	var active_time := stage.controller.active_start_msec()
	for index: int in 10:
		var bubble := stage.player_arena.get_bubble("p%d" % index)
		bubble.position = BubblesPresentation.NPC_ARENA_BOUNDS.get_center() + Vector2.from_angle(TAU * float(index) / 10.0) * Vector2(550, 270)
		for score_index: int in 8 + index:
			stage.controller.record_jellyfish_capture("p%d" % index, active_time)
	stage._entrance_tween.kill()
	stage.creature_arena._create_jellyfish(Vector2(850, 360), Vector2.ZERO, active_time, false, 0)
	stage.creature_arena._create_jellyfish(Vector2(1100, 620), Vector2.ZERO, active_time, false, 0)
	await _frames(5)
	_save("ten-players-fhd")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	await _frames(5)
	_save("ten-players-hd")
	tuning.pufferfish_warning_enabled = true
	tuning.pufferfish_warning_seconds = 2.0
	var warning_time := maxi(Time.get_ticks_msec(), stage.controller.last_host_time_msec())
	stage.creature_arena.schedule_puffer_path(Vector2(-90, 500), Vector2(2010, 500), warning_time)
	await _frames(4)
	_save("warning-on-hd")
	tuning.pufferfish_warning_enabled = false
	for puffer_id: int in stage.creature_arena._puffers.keys():
		var puffer := stage.creature_arena.get_pufferfish(puffer_id)
		puffer.visible = false
	stage.creature_arena.schedule_puffer_path(Vector2(-90, 520), Vector2(2010, 520), warning_time)
	await _frames(3)
	_save("warning-off-hd")
	stage.controller.advance(active_time + 57000)
	stage._update_timer(active_time + 57000)
	await _frames(2)
	_save("final-timer-hd")
	# Force a shared rank at the top without changing presentation-owned state.
	for extra: int in 9:
		stage.controller.record_jellyfish_capture("p0", active_time + 57000)
	stage.controller.advance(active_time + 60000)
	await _frames(4)
	_save("tied-results-hd")
	stage.queue_free()
	await _frames(2)
	var pair := SCENE.instantiate() as BubblesPresentation
	root.add_child(pair)
	pair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(3)
	var pair_tuning := BubblesTuning.new()
	pair_tuning.instructions_seconds = 0.0
	pair_tuning.countdown_seconds = 0.0
	pair_tuning.starting_jellyfish = 0
	pair_tuning.max_radius = 240.0
	pair_tuning.radius_per_jellyfish = 10.0
	pair_tuning.jellyfish_low_spawn_rate = 0.0
	pair_tuning.jellyfish_high_spawn_rate = 0.0
	pair_tuning.pufferfish_start_spawn_rate = 0.0
	pair_tuning.pufferfish_max_spawn_rate = 0.0
	pair.controller.tuning = pair_tuning
	var pair_now := Time.get_ticks_msec()
	pair.start_round([
		{"player_id": "a", "name": "Player One", "seat": 1},
		{"player_id": "b", "name": "Player Two", "seat": 2},
	], pair_now)
	var pair_start := maxi(pair_now, pair.controller.last_host_time_msec())
	pair.controller.complete_entrance(pair_start)
	pair.controller.advance(pair_start)
	pair._entrance_tween.kill()
	pair.player_arena.get_bubble("a").position = Vector2(550, 550)
	pair.player_arena.get_bubble("b").position = Vector2(1380, 550)
	for jelly: int in 40:
		pair.controller.record_jellyfish_capture("a", pair_start)
	pair._cue.visible = false
	await _frames(5)
	_save("two-players-max-bubble-hd")
	pair.queue_free()
	await _frames(2)
	print("Saved PS-045 presentation captures")
	quit(0)


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame


func _save(label: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(OUTPUT.path_join("%s.png" % label)) != OK:
		push_error("Could not save %s" % label)
		quit(1)
