extends SceneTree
## Renderer captures of isolated player-bubble components; not game-feel approval.

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const Arena = preload("res://minigames/bubbles_player_arena.gd")
const OUTPUT := "res://test-results/ps-042"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("164661")
	root.add_child(backdrop)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var first := _stage(3)
	var controller: BubblesRoundController = first.controller
	var arena: BubblesPlayerArena = first.arena
	var now := Time.get_ticks_msec()
	for index: int in 12:
		controller.record_jellyfish_capture("p1", now)
	for index: int in 40:
		controller.record_jellyfish_capture("p2", now)
	controller.submit_trace("p2", 1, _circle(), now)
	arena.simulate_step(0.0, now)
	await _frames(5)
	if not _save("small-growth-spin"):
		return
	var pop_time := now + 100
	controller.pop_player("p2", pop_time)
	var blink_on_time := ceili(float(pop_time + 100) / 200.0) * 200
	arena.simulate_step(0.0, blink_on_time)
	await _frames(5)
	if not _save("pop-reform"):
		return
	controller.queue_free()
	arena.queue_free()
	await process_frame
	var ten := _stage(10)
	var ten_controller: BubblesRoundController = ten.controller
	var ten_arena: BubblesPlayerArena = ten.arena
	var ten_now := Time.get_ticks_msec()
	for index: int in 10:
		for catch_index: int in index * 2:
			ten_controller.record_jellyfish_capture("p%d" % index, ten_now)
	ten_arena.simulate_step(0.0, ten_now)
	await _frames(5)
	if not _save("ten-players"):
		return
	print("Saved PS-042 player-bubble renderer captures")
	quit(0)


func _stage(count: int) -> Dictionary:
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	var players: Array = []
	for index: int in count:
		players.append({"player_id": "p%d" % index, "name": "Player %d" % (index + 1), "seat": index + 1})
	var now := Time.get_ticks_msec()
	controller.start_round(players, now)
	var arena := Arena.new()
	root.add_child(arena)
	arena.setup(controller, Rect2(25, 65, 1230, 625))
	for index: int in count:
		var position := Vector2(240 + index * 400, 390) if count == 3 else Vector2(145 + (index % 5) * 245, 245 + (index / 5) * 290)
		arena.add_bubble("p%d" % index, position)
	controller.complete_entrance(now)
	arena.simulate_step(0.0, now)
	return {"controller": controller, "arena": arena}


func _circle() -> Array:
	var points: Array = []
	for index: int in 65:
		var angle := float(index) / 32.0 * TAU
		points.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return points


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame


func _save(label: String) -> bool:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty():
		push_error("Renderer returned an empty image")
		quit(1)
		return false
	var code := image.save_png(OUTPUT.path_join("%s.png" % label))
	if code != OK:
		push_error("Could not save %s: %s" % [label, error_string(code)])
		quit(1)
		return false
	return true
