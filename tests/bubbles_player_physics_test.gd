extends SceneTree

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const Arena = preload("res://minigames/bubbles_player_arena.gd")
const BOUNDS := Rect2(0, 0, 600, 400)
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_swipe_growth_drag_and_wall()
	_test_wall_edges_and_corners()
	_test_spin_collision_and_pop()
	_test_player_counts_and_disconnect()
	_test_extreme_tuning()
	print("Bubbles player physics checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _setup(count: int = 2, countdown: float = 0.0) -> Dictionary:
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = countdown
	controller.tuning.round_duration_seconds = 10.0
	var participants: Array = []
	for index: int in count:
		participants.append({"player_id": "p%d" % index, "name": "Player %d" % index, "seat": index + 1, "state": "connected"})
	_check(controller.start_round(participants, 0, count == 1).accepted, "Round starts for %d players" % count)
	var arena := Arena.new()
	root.add_child(arena)
	_check(arena.setup(controller, BOUNDS), "Arena binds controller and bounds")
	for index: int in count:
		var x := 65.0 + float(index % 5) * 112.0
		var y := 85.0 + float(index / 5) * 170.0
		_check(arena.add_bubble("p%d" % index, Vector2(x, y)) != null, "Player bubble instantiates")
	controller.complete_entrance(0)
	if countdown == 0.0:
		arena.simulate_step(0.0, 0)
	return {"controller": controller, "arena": arena}


func _test_swipe_growth_drag_and_wall() -> void:
	var system := _setup()
	var controller: BubblesRoundController = system.controller
	var arena: BubblesPlayerArena = system.arena
	var a := arena.get_bubble("p0")
	var b := arena.get_bubble("p1")
	_check(a.is_simulated() and a.collision_radius() == 48.0, "GO enables body and configured collider")
	var short_trace := [[0.2, 0.2], [0.3, 0.2]]
	var long_trace := [[0.1, 0.2], [0.9, 0.2]]
	_check(controller.submit_trace("p0", 1, short_trace, 1).accepted, "Short host-accepted swipe reaches bubble")
	_check(controller.submit_trace("p1", 1, long_trace, 1).accepted, "Long host-accepted swipe reaches bubble")
	_check(is_equal_approx(a.velocity.x, b.velocity.x), "Excess swipe length does not increase impulse")
	for index: int in 40:
		controller.submit_trace("p0", index + 2, short_trace, index + 2)
	_check(a.velocity.length() <= a.effective_max_speed() + 0.001, "Repeated swipes respect speed cap")
	a.velocity = Vector2(200.0, 0.0)
	a.global_position = Vector2(300, 200)
	b.global_position = Vector2(500, 300)
	arena.simulate_step(0.05, 60)
	_check(a.velocity.x < 200.0 and a.velocity.x > 0.0, "Water drag slows unattended bubble")
	a.global_position = Vector2(50, 200)
	a.velocity = Vector2(-100, 0)
	arena.simulate_step(0.05, 110)
	_check(a.global_position.x >= a.collision_radius() and a.velocity.x > 0.0, "Invisible wall bounces bubble inward")
	for index: int in 100:
		controller.record_jellyfish_capture("p0", 120 + index)
	arena.simulate_step(0.0, 220)
	_check(a.score() == 100 and a.bubble_radius() == controller.tuning.max_radius, "Score is uncapped while radius is capped")
	_check(a.collision_radius() == controller.tuning.max_radius, "Collision radius follows visual growth")
	_check(a.get_node("BubbleVisual").captured_visual_count == controller.tuning.captured_visual_cap, "Visible jellyfish obey cap")
	_check(a.effective_mass() > b.effective_mass() and a.effective_max_speed() < b.effective_max_speed(), "Larger bubble gains mass and loses speed")


func _test_spin_collision_and_pop() -> void:
	var system := _setup()
	var controller: BubblesRoundController = system.controller
	var arena: BubblesPlayerArena = system.arena
	var a := arena.get_bubble("p0")
	var b := arena.get_bubble("p1")
	a.global_position = Vector2(240, 200)
	b.global_position = Vector2(320, 200)
	a.velocity = Vector2(50, 0)
	b.velocity = Vector2.ZERO
	_check(controller.submit_trace("p0", 1, _circle(), 1).action == &"spin", "Completed host gesture activates spin")
	_check(a.is_spinning(1), "Bubble consumes authoritative spin state")
	arena.simulate_step(0.0, 1)
	_check(is_equal_approx(a.velocity.x, 50.0) and b.velocity.x > 0.0, "Spinning bubble resists knockback and shoves opponent")
	var baseline := _setup()
	var baseline_controller: BubblesRoundController = baseline.controller
	var baseline_arena: BubblesPlayerArena = baseline.arena
	baseline_controller.tuning.spin_shove_impulse = 0.0
	var base_a := baseline_arena.get_bubble("p0")
	var base_b := baseline_arena.get_bubble("p1")
	base_a.global_position = Vector2(240, 200)
	base_b.global_position = Vector2(320, 200)
	base_a.velocity = Vector2(50, 0)
	base_b.velocity = Vector2.ZERO
	baseline_controller.submit_trace("p0", 1, _circle(), 1)
	baseline_arena.simulate_step(0.0, 1)
	_check(is_equal_approx(b.velocity.x - base_b.velocity.x, controller.tuning.spin_shove_impulse), "Spin adds exactly configured shove over normal collision")
	_check(controller.submit_trace("p0", 2, [[0.2, 0.2], [0.3, 0.2]], 2).action == &"swipe", "Later swipe works during spin")
	_check(a.velocity.x > 50.0, "Spin preserves momentum while swipe adds impulse")
	for index: int in 5:
		controller.record_jellyfish_capture("p0", 10 + index)
	var pop: Dictionary = a.request_puffer_pop(20)
	_check(pop.accepted and pop.lost == 5 and a.score() == 0, "Puffer hook asks controller to remove full score")
	_check(not a.is_spinning(20) and a.is_invulnerable(20), "Pop clears spin and starts i-frames")
	_check(a.collision_radius() < controller.tuning.starting_radius, "Re-form starts from a small bubble")
	_check(a.get_node("ShapeCharacter").player_color == Color.WHITE, "Recovery blinks character white")
	_check(not a.request_jellyfish_collection(21).accepted and not a.request_puffer_pop(21).accepted, "I-frames block collecting and hazards")
	controller.advance(120)
	var resumed_arena := Arena.new()
	root.add_child(resumed_arena)
	resumed_arena.setup(controller, BOUNDS)
	var resumed := resumed_arena.add_bubble("p0", Vector2(150, 200))
	_check(resumed.is_invulnerable(120) and resumed.collision_radius() < controller.tuning.starting_radius, "Late arena binding restores pop recovery from host snapshot")
	arena.simulate_step(0.0, 380)
	_check(is_equal_approx(a.collision_radius(), controller.tuning.starting_radius), "Bubble re-forms by configured duration")
	arena.simulate_step(0.0, 2020)
	_check(not a.is_invulnerable(2020) and a.get_node("ShapeCharacter").player_color != Color.WHITE, "I-frames end and original color returns")
	_check(a.request_jellyfish_collection(2021).accepted, "Collection resumes after i-frames")


func _test_wall_edges_and_corners() -> void:
	var system := _setup(1)
	var arena: BubblesPlayerArena = system.arena
	var bubble := arena.get_bubble("p0")
	var radius := bubble.collision_radius()
	var cases: Array[Dictionary] = [
		{"start": Vector2(radius, 200.0), "incoming": Vector2(-100.0, 0.0), "outgoing": Vector2(1.0, 0.0), "label": "left edge"},
		{"start": Vector2(arena.bounds.end.x - radius, 200.0), "incoming": Vector2(100.0, 0.0), "outgoing": Vector2(-1.0, 0.0), "label": "right edge"},
		{"start": Vector2(300.0, radius), "incoming": Vector2(0.0, -100.0), "outgoing": Vector2(0.0, 1.0), "label": "top edge"},
		{"start": Vector2(300.0, arena.bounds.end.y - radius), "incoming": Vector2(0.0, 100.0), "outgoing": Vector2(0.0, -1.0), "label": "bottom edge"},
		{"start": Vector2(radius, radius), "incoming": Vector2(-100.0, -100.0), "outgoing": Vector2(1.0, 1.0), "label": "top-left corner"},
		{"start": arena.bounds.end - Vector2.ONE * radius, "incoming": Vector2(100.0, 100.0), "outgoing": Vector2(-1.0, -1.0), "label": "bottom-right corner"},
	]
	var host_time := 1
	for collision: Dictionary in cases:
		bubble.global_position = collision.start
		bubble.velocity = collision.incoming
		_check(arena.simulate_step(0.05, host_time), "%s step is accepted" % collision.label)
		var outgoing: Vector2 = collision.outgoing
		var inside := bubble.global_position.x >= arena.bounds.position.x + radius - 0.001
		inside = inside and bubble.global_position.x <= arena.bounds.end.x - radius + 0.001
		inside = inside and bubble.global_position.y >= arena.bounds.position.y + radius - 0.001
		inside = inside and bubble.global_position.y <= arena.bounds.end.y - radius + 0.001
		var direction_ok := (outgoing.x == 0.0 or signf(bubble.velocity.x) == outgoing.x)
		direction_ok = direction_ok and (outgoing.y == 0.0 or signf(bubble.velocity.y) == outgoing.y)
		_check(inside and direction_ok, "%s rebounds inward and stays inside the arena" % collision.label)
		host_time += 1


func _test_player_counts_and_disconnect() -> void:
	for count: int in range(1, 11):
		var system := _setup(count, 1.0)
		var controller: BubblesRoundController = system.controller
		var arena: BubblesPlayerArena = system.arena
		_check(not arena.get_bubble("p0").is_simulated(), "Pre-GO bubble stays still")
		arena.simulate_step(1.0 / 60.0, 1000)
		_check(arena.get_bubble("p0").is_simulated(), "GO enables %d-player simulation" % count)
		_check(arena.simulate_step(1.0 / 60.0, 1016), "%d-player step is stable" % count)
		if count == 2:
			var roster := [{"player_id": "p0", "state": "reconnecting"}, {"player_id": "p1", "state": "connected"}]
			controller.observe_registry(roster, 1020)
			var bubble := arena.get_bubble("p0")
			bubble.velocity = Vector2(60, 0)
			var before := bubble.global_position
			arena.simulate_step(1.0 / 60.0, 1036)
			_check(not bubble.has_live_connection() and bubble.is_simulated() and bubble.global_position.x > before.x, "Disconnected bubble keeps moving")
		controller.queue_free()
		arena.queue_free()


func _test_extreme_tuning() -> void:
	var system := _setup(1)
	var controller: BubblesRoundController = system.controller
	var arena: BubblesPlayerArena = system.arena
	var bubble := arena.get_bubble("p0")
	controller.tuning.starting_radius = 16.0
	controller.tuning.max_radius = 32.0
	controller.tuning.radius_per_jellyfish = 10.0
	controller.tuning.mass_growth_per_jellyfish = 0.2
	controller.tuning.speed_reduction_per_jellyfish = 0.1
	controller.tuning.swipe_impulse = 1000.0
	controller.tuning.max_player_speed = 50.0
	controller.tuning.water_drag = 8.0
	controller.tuning.wall_bounciness = 1.0
	for index: int in 20:
		controller.record_jellyfish_capture("p0", index)
	controller.submit_trace("p0", 1, [[0.1, 0.2], [0.9, 0.2]], 20)
	bubble.global_position = Vector2(17, 200)
	arena.simulate_step(0.05, 70)
	_check(is_finite(bubble.velocity.x) and is_finite(bubble.velocity.y) and bubble.velocity.length() <= bubble.effective_max_speed() + 0.001, "Extreme valid tuning keeps velocity finite and capped")
	_check(bubble.collision_radius() == 32.0 and bubble.effective_mass() > 1.0, "Extreme growth keeps finite capped radius and increased mass")
	_check(bubble.global_position.x >= bubble.collision_radius(), "Extreme radius remains inside boundary")


func _circle() -> Array:
	var points: Array = []
	for index: int in 65:
		var angle := float(index) / 32.0 * TAU
		points.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return points


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
