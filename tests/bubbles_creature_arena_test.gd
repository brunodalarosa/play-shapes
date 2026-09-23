extends SceneTree

const Controller = preload("res://minigames/bubbles_round_controller.gd")
const PlayerArena = preload("res://minigames/bubbles_player_arena.gd")
const CreatureArena = preload("res://minigames/bubbles_creature_arena.gd")
const BOUNDS := Rect2(0, 0, 1000, 600)
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_starting_spawn_and_entrance()
	_test_waves_cap_and_edges()
	_test_puffer_warning_crossing_and_pop()
	_test_scatter_lockout_and_extreme_count()
	print("Bubbles creature arena checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _setup(count: int = 2, countdown := 0.0, starting := 0) -> Dictionary:
	var controller := Controller.new()
	root.add_child(controller)
	controller.tuning = BubblesTuning.new()
	controller.tuning.instructions_seconds = 0.0
	controller.tuning.countdown_seconds = countdown
	controller.tuning.round_duration_seconds = 10.0
	controller.tuning.starting_jellyfish = starting
	controller.set_random_seed(1432)
	var participants: Array = []
	for index: int in count:
		participants.append({"player_id": "p%d" % index, "name": "Player %d" % index, "seat": index + 1, "state": "connected"})
	_check(controller.start_round(participants, 0, count == 1).accepted, "Creature fixture round starts")
	var players := PlayerArena.new()
	root.add_child(players)
	_check(players.setup(controller, BOUNDS), "Player arena setup")
	for index: int in count:
		var position := Vector2(250 + (index % 5) * 125, 220 + (index / 5) * 230)
		players.add_bubble("p%d" % index, position)
	var creatures := CreatureArena.new()
	root.add_child(creatures)
	_check(creatures.setup(controller, players), "Creature arena setup")
	controller.complete_entrance(0)
	if countdown == 0.0:
		players.simulate_step(0.0, 0)
		creatures.simulate_step(0.0, 0)
	return {"controller": controller, "players": players, "creatures": creatures}


func _test_starting_spawn_and_entrance() -> void:
	var fixture := _setup(2, 3.0, 5)
	var controller: BubblesRoundController = fixture.controller
	var players: BubblesPlayerArena = fixture.players
	var creatures: BubblesCreatureArena = fixture.creatures
	_check(creatures.jellyfish_count() == 5, "Configured starting population appears during countdown")
	for id: int in creatures._jellies.keys():
		var jelly := creatures.get_jellyfish(id)
		_check(not jelly.is_collectible(0), "Entrance locks starting jellyfish")
		for player_id: String in players.bubble_ids():
			var bubble := players.get_bubble(player_id)
			_check(jelly.global_position.distance_to(bubble.global_position) >= jelly.radius + bubble.collision_radius() + controller.tuning.jellyfish_spawn_clearance, "Starting spawn respects player clearance")
	players.simulate_step(0.0, 3000)
	creatures.simulate_step(0.0, 3000)
	var bubble := players.get_bubble("p0")
	_check(creatures.spawn_fresh_at(bubble.global_position, 3000) == -1, "Explicit unsafe spawn is rejected")
	var fixture_id := creatures._create_jellyfish(bubble.global_position, Vector2.ZERO, 3000, false, 0)
	creatures.simulate_step(0.0, 3599)
	_check(controller.personal_snapshot("p0").score == 0, "Entrant cannot be caught one millisecond early")
	creatures.simulate_step(0.0, 3600)
	_check(controller.personal_snapshot("p0").score == 1 and creatures.get_jellyfish(fixture_id) == null, "Entrant is collectible exactly at host unlock")
	var offscreen := creatures._create_jellyfish(Vector2(800, 400), Vector2.RIGHT, 3600, false, 0)
	creatures.get_jellyfish(offscreen).global_position = Vector2(1100, 400)
	creatures.simulate_step(0.0, 3601)
	_check(creatures.get_jellyfish(offscreen) == null, "Jellyfish despawns after leaving arena margin")
	_check((players.get_bubble("p0") as CollisionObject2D).collision_layer == 16 and creatures.get_jellyfish(1).collision_layer == 32 and creatures.get_jellyfish(1).collision_mask == 0, "Player and jellyfish collision layers remain separate")


func _test_waves_cap_and_edges() -> void:
	var fixture := _setup()
	var controller: BubblesRoundController = fixture.controller
	var creatures: BubblesCreatureArena = fixture.creatures
	controller.tuning.max_free_jellyfish = 8
	controller.tuning.jellyfish_low_spawn_rate = 2.0
	controller.tuning.jellyfish_high_spawn_rate = 10.0
	controller.tuning.jellyfish_wave_min_seconds = 1.0
	controller.tuning.jellyfish_wave_max_seconds = 2.0
	var waves: Array[Dictionary] = []
	creatures.wave_changed.connect(func(high: bool, rate: float, duration: int) -> void:
		waves.append({"high": high, "rate": rate, "duration": duration}))
	# Start a fresh wave after setting the fixture tuning.
	creatures._begin_wave(0, true)
	for tick: int in 80:
		var at := (tick + 1) * 50
		creatures.simulate_step(0.05, at)
		_check(creatures.jellyfish_count() <= 8, "Wave spawn never breaches free cap")
	_check(waves.size() >= 2, "Timed waves transition")
	for index: int in waves.size():
		var wave := waves[index]
		_check(wave.duration >= 1000 and wave.duration <= 2000 and wave.rate >= 0.0 and wave.rate <= 10.0, "Random wave duration and rate stay bounded")
		if index > 0:
			_check(wave.high != waves[index - 1].high, "High and low waves alternate")
	var path_ids: Array[int] = []
	for edge: int in 4:
		controller.inject_random_values([(float(edge) + 0.1) / 4.0, 0.2, 0.8])
		creatures._spawn_random_puffer(4000)
		path_ids.append(creatures._next_creature_id - 1)
	for edge: int in 4:
		var puffer := creatures.get_pufferfish(path_ids[edge])
		_check(puffer != null and not BOUNDS.has_point(puffer.start_position) and not BOUNDS.has_point(puffer.end_position), "Puffer path begins and ends offscreen")
		_check(puffer.direction.length() > 0.99, "Puffer path has a valid one-pass direction")
		_check(puffer.collision_layer == 64 and puffer.collision_mask == 0, "Pufferfish does not collide with NPC layer")
	_check(creatures.spawn_fresh_at(creatures.get_pufferfish(path_ids[0]).global_position, 4000) == -1, "Safe spawn avoids a warned hazard")
	_check(creatures.puffer_rate_at(0) < creatures.puffer_rate_at(5000) and creatures.puffer_rate_at(5000) < creatures.puffer_rate_at(10000), "Puffer spawn rate rises through the round")


func _test_puffer_warning_crossing_and_pop() -> void:
	var fixture := _setup()
	var controller: BubblesRoundController = fixture.controller
	var players: BubblesPlayerArena = fixture.players
	var creatures: BubblesCreatureArena = fixture.creatures
	controller.tuning.pufferfish_warning_seconds = 0.5
	controller.tuning.pufferfish_speed = 400.0
	controller.tuning.pufferfish_start_spawn_rate = 0.0
	controller.tuning.pufferfish_max_spawn_rate = 0.0
	players.get_bubble("p0").global_position = Vector2(500, 300)
	players.get_bubble("p1").global_position = Vector2(800, 500)
	for index: int in 5:
		controller.record_jellyfish_capture("p0", index)
	controller.submit_trace("p0", 1, _circle(), 5)
	_check(players.get_bubble("p0").is_spinning(5), "Hazard fixture starts during active spin")
	var hits: Array[String] = []
	creatures.pufferfish_hit.connect(func(_id: int, player_id: String) -> void: hits.append(player_id))
	var id := creatures.schedule_puffer_path(Vector2(-50, 300), Vector2(1050, 300), Vector2(16, 300), 0)
	var puffer := creatures.get_pufferfish(id)
	_check(not puffer.active and puffer.warning_until_msec == 500, "Enabled edge warning precedes hazard")
	creatures.simulate_step(0.0, 499)
	_check(not puffer.active and controller.personal_snapshot("p0").score == 5, "Warning alone never pops a player")
	for tick: int in 55:
		creatures.simulate_step(0.05, 500 + tick * 50)
	_check(hits == ["p0"] and controller.personal_snapshot("p0").score == 0, "Puffer pops spinning bubble once through host rule")
	_check(creatures.get_pufferfish(id) == null, "Pufferfish despawns after one full crossing")
	var no_warning := _setup()
	var no_warning_controller: BubblesRoundController = no_warning.controller
	var no_warning_creatures: BubblesCreatureArena = no_warning.creatures
	no_warning_controller.tuning.pufferfish_warning_enabled = false
	var immediate := no_warning_creatures.schedule_puffer_path(Vector2(-50, 300), Vector2(1050, 300), Vector2(16, 300), 0)
	_check(no_warning_creatures.get_pufferfish(immediate).active, "Disabled warning activates puffer immediately")


func _test_scatter_lockout_and_extreme_count() -> void:
	var fixture := _setup()
	var controller: BubblesRoundController = fixture.controller
	var players: BubblesPlayerArena = fixture.players
	var creatures: BubblesCreatureArena = fixture.creatures
	controller.tuning.pop_disappear_ratio = 0.4
	controller.tuning.released_collection_lockout_seconds = 0.5
	for index: int in 5:
		controller.record_jellyfish_capture("p0", index)
	var scatter: Array[Dictionary] = []
	creatures.jellyfish_scattered.connect(func(id: String, spawned: int, discarded: int) -> void:
		scatter.append({"id": id, "spawned": spawned, "discarded": discarded}))
	var pop: Dictionary = players.get_bubble("p0").request_puffer_pop(10)
	_check(pop.accepted and pop.released == 3 and creatures.jellyfish_count() == 3, "Pop scatters retained ratio immediately")
	_check(scatter.size() == 1 and scatter[0].spawned == 3, "Scatter event reports actual free creatures")
	controller.tuning.pufferfish_warning_enabled = false
	var protected_hits: Array[String] = []
	creatures.pufferfish_hit.connect(func(_id: int, id: String) -> void: protected_hits.append(id))
	var protected_id := creatures.schedule_puffer_path(players.get_bubble("p0").global_position,
		players.get_bubble("p0").global_position + Vector2(100, 0), players.get_bubble("p0").global_position, 10)
	creatures.simulate_step(0.0, 10)
	_check(creatures.get_pufferfish(protected_id) != null and protected_hits.is_empty(),
		"Puffer collision respects post-pop invulnerability")
	var jelly := creatures.get_jellyfish(creatures._jellies.keys()[0])
	jelly.global_position = players.get_bubble("p1").global_position
	creatures.simulate_step(0.0, 10)
	_check(controller.personal_snapshot("p1").score == 0, "Released jellyfish cannot recollect in pop frame")
	creatures.simulate_step(0.0, 509)
	_check(controller.personal_snapshot("p1").score == 0, "Released jellyfish stays locked until exact end")
	creatures.simulate_step(0.0, 510)
	_check(controller.personal_snapshot("p1").score == 1, "Released jellyfish becomes collectible at exact lockout end")
	var zero_lock := _setup()
	var zero_controller: BubblesRoundController = zero_lock.controller
	var zero_players: BubblesPlayerArena = zero_lock.players
	var zero_creatures: BubblesCreatureArena = zero_lock.creatures
	zero_controller.tuning.released_collection_lockout_seconds = 0.0
	zero_controller.record_jellyfish_capture("p0", 0)
	zero_players.get_bubble("p0").request_puffer_pop(1)
	var zero_jelly := zero_creatures.get_jellyfish(zero_creatures._jellies.keys()[0])
	zero_jelly.global_position = zero_players.get_bubble("p1").global_position
	zero_creatures.simulate_step(0.0, 1)
	_check(zero_controller.personal_snapshot("p1").score == 0, "Zero lockout still prevents same-frame recollection")
	zero_creatures.simulate_step(0.0, 2)
	_check(zero_controller.personal_snapshot("p1").score == 1, "Zero lockout releases on the next host millisecond")

	var extreme := _setup(10)
	var extreme_controller: BubblesRoundController = extreme.controller
	var extreme_players: BubblesPlayerArena = extreme.players
	var extreme_creatures: BubblesCreatureArena = extreme.creatures
	extreme_controller.tuning.max_free_jellyfish = 200
	extreme_controller.tuning.pop_disappear_ratio = 0.0
	var extreme_scatter: Array[Dictionary] = []
	extreme_creatures.jellyfish_scattered.connect(func(_id: String, spawned: int, discarded: int) -> void:
		extreme_scatter.append({"spawned": spawned, "discarded": discarded}))
	for index: int in 1000:
		extreme_controller.record_jellyfish_capture("p0", index)
	var extreme_pop: Dictionary = extreme_players.get_bubble("p0").request_puffer_pop(1000)
	_check(extreme_pop.accepted and extreme_pop.released == 1000 and extreme_creatures.jellyfish_count() <= 200, "Extreme score scatter remains bounded by free cap")
	_check(extreme_scatter.size() == 1 and extreme_scatter[0].spawned == 200 and extreme_scatter[0].discarded == 800,
		"Cap overflow is reported and discarded deterministically")
	extreme_creatures.simulate_step(0.0, 1000)
	_check(extreme_creatures.jellyfish_count() <= 200, "Extreme-count step remains bounded")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _circle() -> Array:
	var points: Array = []
	for index: int in 65:
		var angle := float(index) / 32.0 * TAU
		points.append([0.5 + 0.2 * cos(angle), 0.5 + 0.2 * sin(angle)])
	return points
