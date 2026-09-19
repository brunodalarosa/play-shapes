extends SceneTree
## Deterministic technical captures; these prove rendering only, not readability,
## audio quality, flash comfort, or final game-feel approval.

const STAGE_SCENE := preload("res://minigames/dancer_simon_says.tscn")


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var capture_size := Vector2i(1920, 1080)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "capture-1280x720":
			capture_size = Vector2i(1280, 720)
	var capture_viewport := SubViewport.new()
	capture_viewport.size = capture_size
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var stage := STAGE_SCENE.instantiate() as DancerSimonSaysStage
	var controller := stage.get_node(^"RoundController") as FlashPoseRoundController
	var presentation := stage.get_node(^"Presentation") as FlashPosePresentation
	var tuning := SimonSaysTuning.new()
	tuning.countdown_seconds = 0.0
	controller.tuning = tuning
	presentation.tuning = tuning
	capture_viewport.add_child(stage)
	await process_frame
	var participants: Array[Dictionary] = []
	for index: int in 10:
		participants.append({
			"player_id": "p%d" % (index + 1),
			"name": ["Ari", "Bea", "Cleo", "Dax", "Emi", "Finn", "Gia", "Hugo", "Ivy", "Jax"][index],
			"seat": index + 1,
			"state": "connected",
		})
	var now := Time.get_ticks_msec()
	controller.inject_sequences([&"disco"], [&"right"], [10_000])
	assert(controller.start_round(participants, now).accepted)
	controller.advance(now)
	await _settle()
	DirAccess.make_dir_recursive_absolute("res://test-results/ps-032")

	presentation._on_round_results_ready({
		"top_group_size": 5,
		"ranking": participants,
	})
	await _settle()
	var viewport_size := capture_viewport.get_visible_rect().size
	var size_label := "%dx%d" % [int(viewport_size.x), int(viewport_size.y)]
	assert(capture_viewport.get_texture().get_image().save_png("res://test-results/ps-032/results-%s.png" % size_label) == OK)
	print("[GODOT-RUNTIME] PS-032 technical results capture saved at %s" % size_label)
	quit(0)


func _settle() -> void:
	for _unused: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
