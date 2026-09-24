extends SceneTree
## Isolated creature and bubble renderer captures for art/feedback review.

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const PlayerArena = preload("res://minigames/bubbles_player_arena.gd")
const CreatureArena = preload("res://minigames/bubbles_creature_arena.gd")
const OUTPUT := "res://test-results/ps-043"


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
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	controller.tuning.round_duration_seconds = 60.0
	controller.tuning.starting_jellyfish = 0
	controller.tuning.jellyfish_low_spawn_rate = 0.0
	controller.tuning.jellyfish_high_spawn_rate = 0.0
	controller.tuning.pufferfish_start_spawn_rate = 0.0
	controller.tuning.pufferfish_max_spawn_rate = 0.0
	controller.tuning.pufferfish_warning_seconds = 0.5
	controller.tuning.pufferfish_speed = 700.0
	controller.set_random_seed(43)
	var now := Time.get_ticks_msec()
	controller.start_round([
		{"player_id": "p0", "name": "Player One", "seat": 1},
		{"player_id": "p1", "name": "Player Two", "seat": 2},
	], now)
	var players := PlayerArena.new()
	root.add_child(players)
	players.setup(controller, Rect2(30, 65, 1220, 620))
	players.add_bubble("p0", Vector2(370, 360))
	players.add_bubble("p1", Vector2(930, 360))
	var creatures := CreatureArena.new()
	root.add_child(creatures)
	creatures.setup(controller, players)
	controller.complete_entrance(now)
	players.simulate_step(0.0, now)
	creatures.simulate_step(0.0, now)
	for index: int in 8:
		controller.record_jellyfish_capture("p0", now)
	creatures._create_jellyfish(Vector2(620, 270), Vector2.ZERO, now, false, 0)
	creatures._create_jellyfish(Vector2(740, 430), Vector2.ZERO, now, false, 0)
	creatures.schedule_puffer_path(Vector2(-60, 520), Vector2(1340, 520), now)
	await _frames(5)
	if not _save("entrance-and-warning"):
		return
	var unlocked := now + roundi(controller.tuning.jellyfish_entrance_seconds * 1000.0)
	players.simulate_step(0.0, unlocked)
	creatures.simulate_step(0.0, unlocked)
	for tick: int in 20:
		var step_time := unlocked + (tick + 1) * 50
		players.simulate_step(0.05, step_time)
		creatures.simulate_step(0.05, step_time)
	await _frames(5)
	if not _save("active-creatures"):
		return
	var pop_time := unlocked + 1001
	controller.pop_player("p0", pop_time)
	var blink_time := pop_time + 120
	players.simulate_step(0.0, blink_time)
	creatures.simulate_step(0.0, blink_time)
	await _frames(5)
	if not _save("released-blink"):
		return
	print("Saved PS-043 creature renderer captures")
	quit(0)


func _frames(count: int) -> void:
	for index: int in count:
		await process_frame


func _save(label: String) -> bool:
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(OUTPUT.path_join("%s.png" % label)) != OK:
		push_error("Could not save %s" % label)
		quit(1)
		return false
	return true
