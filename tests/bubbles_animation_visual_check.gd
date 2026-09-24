extends SceneTree
## Representative isolated renders for PS-050 visual review.

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const Arena = preload("res://minigames/bubbles_player_arena.gd")
const Protocol = preload("res://host/bubbles_protocol.gd")
const OUTPUT := "res://test-results/ps-050"


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
	var controller := Controller.new() as BubblesRoundController
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = 0.0
	var now := Time.get_ticks_msec()
	controller.start_round([{"player_id": "sample", "name": "Player", "seat": 1}], now, true)
	controller.set_process(false)
	var arena := Arena.new() as BubblesPlayerArena
	root.add_child(arena)
	arena.setup(controller, Rect2(20, 50, 1240, 650))
	var bubble := arena.add_bubble("sample", Vector2(640, 355))
	controller.complete_entrance(now)
	arena.simulate_step(0.0, now)
	await _save("small-idle")
	for index: int in 40:
		controller.record_jellyfish_capture("sample", now + index + 1)
	arena.simulate_step(0.0, now + 40)
	await _save("maximum-idle")
	var protocol := Protocol.new(controller)
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 1, "stage": "start", "step": 0}, now + 41)
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 1, "stage": "motion", "drag": [-4, 0]}, now + 110)
	arena.simulate_step(0.05, now + 150)
	await _save("held-left-before-release")
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_trace", "input_seq": 1, "trace": [[0.9, 0.5], [0.1, 0.5]]}, now + 200)
	arena.simulate_step(0.05, now + 280)
	await _save("accepted-swipe")
	bubble.velocity = Vector2.ZERO
	bubble.global_position = Vector2(640, 355)
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 2, "stage": "start", "step": 0}, now + 350)
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 2, "stage": "motion", "drag": [-4, 0]}, now + 420)
	arena.simulate_step(0.05, now + 500)
	await _save("slow-held-drag")
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_trace", "input_seq": 2, "trace": [[0.9, 0.5], [0.1, 0.5]]}, now + 1100)
	arena.simulate_step(0.05, now + 1150)
	await _save("slow-release-no-impulse")
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 3, "stage": "start", "step": 0}, now + 1250)
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 3, "stage": "progress", "step": 3}, now + 1300)
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_charge", "input_seq": 3, "stage": "motion", "drag": [2, 2]}, now + 1370)
	arena.simulate_step(0.05, now + 1420)
	await _save("charge-glow-wobble")
	protocol.handle_action({"player_id": "sample"}, {"type": "bubbles_trace", "input_seq": 3, "trace": _circle()}, now + 1500)
	arena.simulate_step(0.0, now + 1560)
	await _save("active-spin")
	controller.pop_player("sample", now + 1600)
	arena.simulate_step(0.0, now + 1655)
	await _save("burst")
	arena.simulate_step(0.0, now + 1950)
	await _save("reformed")
	if bubble == null:
		push_error("Missing bubble")
		quit(1)
		return
	print("Saved PS-050 isolated animation captures")
	quit(0)


func _circle() -> Array:
	var points: Array = []
	for index: int in 65:
		var angle := float(index) / 32.0 * TAU
		points.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return points


func _save(label: String) -> void:
	for index: int in 4:
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if image.is_empty() or image.save_png(OUTPUT.path_join("%s.png" % label)) != OK:
		push_error("Could not save %s" % label)
		quit(1)
