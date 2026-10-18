extends TestScript
## The 3D arenas on real Jolt physics frames: bubbles stay locked to the plane, swipes push them
## up to the speed cap, walls and other bubbles rebound them, the collider always equals the drawn
## radius, and jellyfish and pufferfish sensors catch, pop and scatter as the rules say, up to the
## zero-time freeze.

const STEP_MSEC := 1000.0 / 60.0

var _world: Node3D
var _controller: Bubbles3DRoundController
var _players: Bubbles3DPlayerArena
var _creatures: Bubbles3DCreatureArena
var _clock := 0.0


func _run() -> void:
	await _test_plane_swipes_and_walls()
	await _test_bumps()
	await _test_catching_and_growth()
	await _test_pop_scatter_and_invulnerability()
	await _test_spawning_limits()
	await _test_zero_freeze_and_leave()


func _tuning() -> Bubbles3DTuning:
	var tuning := Bubbles3DTuning.new()
	tuning.instructions_seconds = 0.0
	tuning.countdown_seconds = 0.0
	tuning.round_duration_seconds = 60.0
	tuning.starting_jellyfish = 0
	tuning.jellyfish_low_spawn_rate = 0.0
	tuning.jellyfish_high_spawn_rate = 0.0
	tuning.pufferfish_start_spawn_rate = 0.0
	tuning.pufferfish_max_spawn_rate = 0.0
	tuning.pufferfish_warning_enabled = false
	tuning.jellyfish_speed = 0.0
	return tuning


## A fresh round with [param count] players placed at [param places], already active.
func _begin(count: int, places: Array[Vector2], tuning := _tuning()) -> void:
	if _world != null:
		_world.queue_free()
		await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	_controller = Bubbles3DRoundController.new()
	_world.add_child(_controller)
	# Set after entering the tree, where the controller adopts the active preset.
	_controller.tuning = tuning
	_controller.set_random_seed(4)
	_players = Bubbles3DPlayerArena.new()
	_world.add_child(_players)
	_creatures = Bubbles3DCreatureArena.new()
	_world.add_child(_creatures)
	var roster: Array = []
	for index: int in count:
		roster.append({ "player_id": "p%d" % index, "seat": index + 1, "name": "P%d" % index })
	_clock = 1000.0
	check(_controller.start_round(roster, int(_clock), count == 1).accepted, "The round starts")
	# The test drives the host clock itself.
	_controller.set_process(false)
	_players.setup(_controller, Rect2(-8.4, -4.0, 16.8, 7.8))
	for index: int in count:
		_players.add_bubble("p%d" % index, places[index])
	_creatures.setup(_controller, _players)
	_controller.complete_entrance(int(_clock))
	await _steps(2)
	check(_controller.phase_name() == &"active", "The round is active")


func _steps(count: int) -> void:
	for _step: int in count:
		_clock += STEP_MSEC
		_players.simulate_step(STEP_MSEC / 1000.0, int(_clock))
		_creatures.simulate_step(STEP_MSEC / 1000.0, int(_clock))
		await physics_frame


func _now() -> int:
	return int(_clock)


func _swipe(player_id: String, sequence: int, direction: Vector2) -> void:
	_controller.submit_swipe(player_id, sequence, direction * 0.3, _now())


func _test_plane_swipes_and_walls() -> void:
	await _begin(1, [Vector2.ZERO])
	var bubble := _players.get_bubble("p0")
	check(not bubble.freeze, "An active bubble is simulated")
	_swipe("p0", 1, Vector2(1.0, 0.0))
	await _steps(1)
	var speed := bubble.plane_velocity().length()
	check(
		absf(speed - _controller.tuning.swipe_impulse) < 0.2,
		"A swipe gives a base-mass bubble the swipe speed",
	)
	check(bubble.plane_velocity().x > 0.0, "A swipe pushes along its direction")
	for sequence: int in range(2, 8):
		_swipe("p0", sequence, Vector2(1.0, 0.0))
		await _steps(1)
	var cap := _controller.tuning.max_speed_for(bubble.bubble_radius())
	check(bubble.plane_velocity().length() <= cap + 0.01, "Repeated swipes stop at the speed cap")

	check(PlaneLock3D.is_on_plane(bubble), "The bubble stays at depth zero without turning")

	bubble.global_position = Vector3(8.0, 0.0, 0.0)
	bubble.linear_velocity = Vector3(4.0, 0.0, 0.0)
	var before := 4.0 * exp(-_controller.tuning.water_drag * 0.25)
	var after := 0.0
	var furthest := 0.0
	for _step: int in 30:
		await _steps(1)
		furthest = maxf(furthest, bubble.global_position.x)
		if bubble.plane_velocity().x < 0.0:
			after = -bubble.plane_velocity().x
			break
	var expected := before * _controller.tuning.wall_bounciness
	check(after > 0.0, "The right wall sends the bubble back")
	check(absf(after - expected) < 0.6, "A wall rebounds with its bounciness")
	check(furthest <= 9.6 - bubble.collision_radius() + 0.05, "The bubble never passes the wall")

	bubble.linear_velocity = Vector3(3.0, 1.0, 0.0)
	await _steps(120)
	check(bubble.plane_velocity().length() < 0.1, "Water drag slows a drifting bubble")


func _test_bumps() -> void:
	await _begin(2, [Vector2(-1.0, 0.0), Vector2(1.0, 0.0)])
	var collisions: Array[String] = []
	_players.player_collision.connect(
		func(first: String, second: String) -> void:
			collisions.append("%s:%s" % [first, second]),
	)
	var left := _players.get_bubble("p0")
	var right := _players.get_bubble("p1")
	_swipe("p0", 1, Vector2(1.0, 0.0))
	await _steps(90)
	check(collisions.size() >= 1 and collisions[0] == "p0:p1", "Two bubbles report their bump")
	check(right.plane_velocity().x > 0.0, "A bump pushes the other bubble away")
	# Equal masses at the bump bounciness e keep (1 - e) / (1 + e) of the pushed bubble's speed.
	var bounce := _controller.tuning.bump_bounciness
	var share := left.plane_velocity().x / right.plane_velocity().x
	check(
		absf(share - (1.0 - bounce) / (1.0 + bounce)) < 0.08,
		"A bump shares speed by the bump bounciness",
	)
	var gap := right.plane_position().distance_to(left.plane_position())
	var touching := left.collision_radius() + right.collision_radius()
	check(gap >= touching - 0.05, "Bubbles do not sink into each other")
	check(
		PlaneLock3D.is_on_plane(left) and PlaneLock3D.is_on_plane(right),
		"A bump leaves both bubbles on the plane",
	)


func _test_catching_and_growth() -> void:
	await _begin(1, [Vector2(-5.0, 0.0)])
	var bubble := _players.get_bubble("p0")
	var id := _creatures.spawn_fresh_at(Vector2(0.0, 0.0), _now())
	check(id > 0, "A jellyfish spawns at a safe point")
	bubble.global_position = Vector3(0.0, 0.0, 0.0)
	await _steps(2)
	check(_controller.personal_snapshot("p0").score == 0, "A growing-in jellyfish cannot be caught")
	await _steps(40)
	check(_controller.personal_snapshot("p0").score == 1, "A grown jellyfish is caught on contact")
	check(_creatures.get_jellyfish(id) == null, "A caught jellyfish leaves the arena")

	for index: int in 30:
		_controller.record_jellyfish_capture("p0", _now())
	await _steps(2)
	var radius := _controller.tuning.radius_for(31)
	check(is_equal_approx(bubble.collision_radius(), radius), "The collider grows with the catch")
	check(is_equal_approx(bubble.shell.radius, radius), "The drawn bubble matches the collider")
	check(
		bubble.caught.visible_count() == _controller.tuning.captured_visual_cap,
		"At most the visual cap of caught jellyfishes are drawn",
	)
	check(
		is_equal_approx(bubble.mass, _controller.tuning.mass_for(radius)),
		"A bigger bubble is heavier",
	)
	check(
		_controller.tuning.max_speed_for(radius) < _controller.tuning.max_player_speed,
		"A bigger bubble has a lower speed cap",
	)


func _test_pop_scatter_and_invulnerability() -> void:
	await _begin(1, [Vector2(0.0, 0.0)])
	var bubble := _players.get_bubble("p0")
	for index: int in 10:
		_controller.record_jellyfish_capture("p0", _now())
	var hits: Array[String] = []
	_creatures.pufferfish_hit.connect(
		func(_id: int, player_id: String) -> void:
			hits.append(player_id),
	)
	_creatures.schedule_puffer_path(Vector2(-3.0, 0.0), Vector2(12.0, 0.0), _now())
	for _step: int in 90:
		await _steps(1)
		if not hits.is_empty():
			break
	check(hits == ["p0"], "A pufferfish pops the bubble it touches")
	check(_controller.personal_snapshot("p0").score == 0, "A pop loses the whole catch")
	check(_creatures.jellyfish_count() == 5, "Half the catch scatters around the pop")
	var scattered := _creatures.get_jellyfish(_creatures.jellyfish_ids()[0])
	check(scattered.released and not scattered.is_collectible(_now()), "Scattered ones are locked")
	var blinked := false
	for _step: int in 12:
		await _steps(1)
		blinked = blinked or scattered.flashes_white(_now())
	check(blinked, "Scattered jellyfishes blink white during the lockout")
	check(bubble.is_invulnerable(_now()), "A popped bubble is invulnerable")
	check(_controller.personal_snapshot("p0").score == 0, "An invulnerable bubble catches nothing")
	_creatures.schedule_puffer_path(Vector2(-3.0, 0.0), Vector2(12.0, 0.0), _now())
	await _steps(60)
	check(hits.size() == 1, "An invulnerable bubble cannot pop again")
	bubble.global_position = Vector3(0.0, 4.0, 0.0)
	await _steps(90)
	check(not bubble.is_invulnerable(_now()), "The invulnerability ends")
	check(PlaneLock3D.is_on_plane(bubble), "A pop leaves the bubble on the plane")


func _test_spawning_limits() -> void:
	var tuning := _tuning()
	tuning.jellyfish_low_spawn_rate = 10.0
	tuning.jellyfish_high_spawn_rate = 15.0
	tuning.max_free_jellyfish = 12
	tuning.starting_jellyfish = 6
	tuning.pufferfish_start_spawn_rate = 0.5
	tuning.pufferfish_max_spawn_rate = 2.0
	await _begin(2, [Vector2(-6.0, 0.0), Vector2(6.0, 0.0)], tuning)
	check(_creatures.jellyfish_count() == 6, "The starting population is placed before GO")
	await _steps(180)
	check(_creatures.jellyfish_count() <= 12, "The free-jellyfish cap holds")
	check(_creatures.jellyfish_count() >= 10, "Waves keep spawning up to the cap")
	var start := _controller.active_start_msec()
	check(
		_creatures.puffer_rate_at(start) < _creatures.puffer_rate_at(start + 50000),
		"The pufferfish rate rises over the round",
	)
	for id: int in _creatures.jellyfish_ids():
		var jelly := _creatures.get_jellyfish(id)
		var clear := true
		for player_id: String in _players.bubble_ids():
			var bubble := _players.get_bubble(player_id)
			if jelly.plane_position().distance_to(bubble.plane_position()) < bubble.bubble_radius():
				clear = false
		check(clear or not jelly.is_collectible(jelly.spawned_at_msec), "Spawns avoid bubbles")
	check(
		_creatures.swarm.visible_count() == _creatures.jellyfish_count(),
		"Every free jellyfish is drawn",
	)


func _test_zero_freeze_and_leave() -> void:
	var tuning := _tuning()
	tuning.round_duration_seconds = 10.0
	await _begin(2, [Vector2(-3.0, 0.0), Vector2(3.0, 0.0)], tuning)
	_controller.observe_registry([{ "player_id": "p0", "state": "connected" }], _now())
	var left := _players.get_bubble("p1")
	check(not left.visible and left.freeze, "A player who leaves loses the bubble")
	_clock = float(_controller.finish_msec()) - STEP_MSEC
	await _steps(2)
	check(_controller.phase_name() == &"results", "Zero ends the round")
	var bubble := _players.get_bubble("p0")
	check(bubble.freeze, "Zero freezes the bubbles")
	var id := _creatures.spawn_fresh_at(Vector2(0.0, 3.0), _now())
	bubble.global_position = Vector3(0.0, 3.0, 0.0)
	await _steps(30)
	check(
		id == -1 or _controller.result_snapshot().by_player_id.p0.score == 0,
		"Nothing counts after zero",
	)
