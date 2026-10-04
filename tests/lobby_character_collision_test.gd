extends TestScript
## Two real lobby bodies must block each other and rebound after a top landing.

const WORLD: PackedScene = preload("res://scenes/lobby_playground_world.tscn")


func _run() -> void:
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	root.add_child(world)
	var registry := PlayerRegistry.new(10, 60.0)
	var reconcile := func() -> void:
		world.reconcile(registry.public_players())
	registry.players_changed.connect(reconcile)
	var now := Time.get_ticks_msec()
	var first := registry.join_player(100, "First", true, now)
	var second := registry.join_player(101, "Second", true, now)
	var mover := world.character_for(String(first.player.player_id))
	var target := world.character_for(String(second.player.player_id))
	for unused: int in 6:
		await physics_frame
	check(mover.is_on_floor() and target.is_on_floor(), "Both players start on the shelf")

	# Freeze one player so the moving body has a stable collision target.
	target.set_connected(false)
	mover.position = target.position + Vector2(-100.0, 0.0)
	mover.velocity = Vector2.ZERO
	for unused: int in 35:
		mover.motor.set_input(Vector2.RIGHT, "move", Time.get_ticks_msec())
		await physics_frame
	var reached := mover.position.x > target.position.x - 95.0
	var blocked := mover.position.x <= target.position.x - 44.0
	check(reached and blocked, "A moving player reaches but cannot pass through another player")
	check(
		target.position.x == target.spawn_point.x,
		"A disconnected player remains stationary during a bump",
	)

	mover.clear_input()
	mover.position = target.position + Vector2(0.0, -220.0)
	mover.velocity = Vector2.ZERO
	var bounced := false
	var impact_y := 0.0
	for unused: int in 90:
		await physics_frame
		if mover.velocity.y < -100.0:
			bounced = true
			impact_y = mover.position.y
			break
	check(bounced, "Landing on another player produces an upward rebound")
	check(not mover.motor.request_jump(), "The rebound does not allow an extra grounded jump")
	var highest_y := impact_y
	for unused: int in 25:
		await physics_frame
		highest_y = minf(highest_y, mover.position.y)
	check(
		impact_y - highest_y >= 10.0 and impact_y - highest_y <= 70.0,
		"The player bounce is visible but modest",
	)
	for unused: int in 70:
		await physics_frame
	check(
		mover.is_on_floor() and absf(mover.velocity.y) < 1.0,
		"The rebound settles rather than repeating forever",
	)
	world.queue_free()
	await process_frame

	# The registry holds the callback and the callback holds the registry, so neither is
	# freed until one lets go.
	registry.players_changed.disconnect(reconcile)
