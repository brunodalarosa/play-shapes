extends SceneTree
## Captures creature size, warning, and breathing states for owner review.

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const PlayerArena = preload("res://minigames/bubbles_player_arena.gd")
const CreatureArena = preload("res://minigames/bubbles_creature_arena.gd")
const OUTPUT := "res://test-results/ps-052"


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
	controller.tuning.pufferfish_warning_seconds = 0.8
	controller.tuning.pufferfish_speed = 350.0
	controller.set_random_seed(49)
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

	controller.tuning.jellyfish_collider_radius = 8.0
	var small_jelly_id: int = creatures._create_jellyfish(Vector2(620, 270), Vector2.ZERO, now, false, 0)
	controller.tuning.jellyfish_collider_radius = 36.0
	var large_jelly_id: int = creatures._create_jellyfish(Vector2(740, 430), Vector2.ZERO, now, false, 0)
	var puffer_id: int = creatures.schedule_puffer_path(Vector2(-60, 520), Vector2(1340, 520), now)
	if small_jelly_id < 0 or large_jelly_id < 0 or puffer_id < 0:
		push_error("Could not create PS-052 visual fixtures")
		quit(1)
		return
	await _frames(36)
	var debug_puffer := creatures.get_pufferfish(puffer_id)
	if not _save("offscreen-bubble-burst-before-reveal"):
		return

	creatures.simulate_step(0.0, now + 800)
	debug_puffer.simulate_step(0.0, now + 800)
	debug_puffer.simulate_step(0.05, now + 850)
	debug_puffer.simulate_step(0.05, now + 900)
	await _frames(6)
	if not _save("pufferfish-revealed-at-burst-origin"):
		return
	debug_puffer.simulate_step(0.05, now + 950)
	await _frames(4)
	if not _save("jellyfish-breath-expanded"):
		return

	for tick: int in 7:
		var step_time := now + 950 + tick * 50
		debug_puffer.simulate_step(0.05, step_time)
	await _frames(4)
	if not _save("pufferfish-jiggle-upstroke"):
		return
	for tick: int in 3:
		debug_puffer.simulate_step(0.05, now + 1300 + tick * 50)
	await _frames(4)
	if not _save("pufferfish-jiggle-downstroke"):
		return
	for tick: int in 14:
		debug_puffer.simulate_step(0.05, now + 1450 + tick * 50)
	creatures.get_jellyfish(small_jelly_id).simulate_step(0.0, now + 2100)
	creatures.get_jellyfish(large_jelly_id).simulate_step(0.0, now + 2100)
	await _frames(5)
	if not _save("pufferfish-burst-faded-jellyfish-breath-contracted"):
		return
	creatures.get_pufferfish(puffer_id).visible = false
	creatures.get_pufferfish(puffer_id)._collider.disabled = true

	controller.tuning.pufferfish_warning_enabled = false
	var no_warning_id := creatures.schedule_puffer_path(Vector2(640, -60), Vector2(640, 780), now + 2150)
	var no_warning_puffer := creatures.get_pufferfish(no_warning_id)
	if no_warning_puffer == null or no_warning_puffer._warning_particles.emitting:
		push_error("Disabled warning unexpectedly created particles")
		quit(1)
		return
	for tick: int in 10:
		creatures.get_pufferfish(no_warning_id).simulate_step(0.05, now + 2200 + tick * 50)
	await _frames(5)
	if not _save("pufferfish-warning-off"):
		return
	print("Saved PS-052 creature telegraph review captures")
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
