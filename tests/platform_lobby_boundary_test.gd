extends SceneTree
## Full Playground adapter: atomic release context, ordering and lifecycle cleanup.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := (load("res://scenes/lobby_playground_world.tscn") as PackedScene).instantiate() as LobbyPlaygroundWorld
	root.add_child(world)
	var players: Array[Dictionary] = [
		{"player_id": "first", "seat": 1, "name": "First", "state": "connected", "character_color": "#EC407A"},
		{"player_id": "second", "seat": 2, "name": "Second", "state": "connected", "character_color": "#00ACC1"},
	]
	world.reconcile(players)
	var first := world.character_for("first")
	var second := world.character_for("second")
	for index: int in 5:
		await physics_frame
		await process_frame
	var release := {"type": "lobby_fall_release", "action": "fall", "horizontal": 0.1, "vertical": -0.8,
		"stance": "crouch", "input_seq": 1, "player_id": "second"}
	var result := world.handle_input(players[0], release, Time.get_ticks_msec())
	_check(result.accepted and result.dropped and first.motor.axes.is_equal_approx(Vector2(0.1, -0.8))
		and first.motor.stance == "crouch" and second.motor.axes == Vector2.ZERO,
		"Release applies latest axes atomically only to the registered identity, ignoring forged player_id")
	_check(world.handle_input(players[0], release, Time.get_ticks_msec()).code == "stale_sequence", "Duplicate FALL cannot change intent")
	release.input_seq = 2
	_check(not world.handle_input(players[0], release, Time.get_ticks_msec()).dropped, "Repeated airborne FALL is discarded")
	for index: int in 48:
		first.motor.set_input(first.motor.axes, first.motor.stance, Time.get_ticks_msec())
		await physics_frame
		await process_frame
	_check(absf(first.position.y - 675.0) < 1.0 and absf(second.position.y - 400.0) < 1.0,
		"Playground FALL descends one actual support without disturbing another player")
	release.input_seq = 3
	_check(not world.handle_input(players[0], release, Time.get_ticks_msec()).dropped, "Repeated held FALL cannot bypass next shelf")
	for invalid: Variant in [0, -1, 1.5, NAN, INF, 9007199254740992.0, "4", null]:
		release.input_seq = invalid
		_check(not world.handle_input(players[0], release, Time.get_ticks_msec()).accepted, "Invalid sequence rejected")
	release.input_seq = 4
	release.action = "jump"
	_check(world.handle_input(players[0], release, Time.get_ticks_msec()).code == "invalid_action", "Explicit FALL cannot dispatch JUMP")
	release.action = "fall"
	release.stance = "look_up"
	_check(world.handle_input(players[0], release, Time.get_ticks_msec()).code == "invalid_stance", "Invalid hint cannot consume sequence")
	release.stance = "crouch"
	_check(world.handle_input(players[0], release, Time.get_ticks_msec()).accepted, "Valid input retains sequence after invalid packets")
	world.reset_sequence("first")
	_check(first.motor.axes == Vector2.ZERO and first.motor.stance == "neutral"
		and first.get_collision_exceptions().is_empty(), "Resume clears stance, queued actions and collision exceptions")
	await physics_frame
	await process_frame
	release.input_seq = 1
	_check(world.handle_input(players[0], release, Time.get_ticks_msec()).dropped, "New connection gets a fresh deliberate attempt")
	players[0].state = "reconnecting"
	world.reconcile(players)
	_check(first.get_collision_exceptions().is_empty() and first.floor_snap_length == 8.0
		and first.motor.stance == "neutral" and not first.motor.enabled, "Registry disconnect clears the active drop")
	_check(world.handle_input(players[0], release, Time.get_ticks_msec()).code == "not_joined", "Disconnected record cannot control character")
	players[0].state = "connected"
	world.reconcile(players)
	await physics_frame
	await process_frame
	release.input_seq = 1
	world.handle_input(players[0], release, Time.get_ticks_msec())
	world.clear_all_input()
	_check(first.get_collision_exceptions().is_empty() and first.motor.axes == Vector2.ZERO,
		"Leaving active context clears live drop and both axes")
	world.queue_free()
	await process_frame
	print("Platform lobby boundary checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
