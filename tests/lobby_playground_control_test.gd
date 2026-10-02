extends SceneTree
## Registry reconciliation, authoritative input, and platform motion in the real world.

const WORLD: PackedScene = preload("res://scenes/lobby_playground_world.tscn")
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	root.add_child(world)
	var registry := PlayerRegistry.new(10, 60.0)
	var refresh := func() -> void: world.reconcile(registry.public_players())
	registry.players_changed.connect(refresh)
	var now := Time.get_ticks_msec()
	var first := registry.join_player(100, "First", true, now, "square", "#EC407A")
	var second := registry.join_player(101, "Second", true, now, "rhombus", "#00ACC1")
	var first_id := String(first.player.player_id)
	var second_id := String(second.player.player_id)
	var first_character := world.character_for(first_id)
	var second_character := world.character_for(second_id)
	_check(first_character != null and second_character != null and first_character != second_character
		and first_character.spawn_point == Vector2(218, 400)
		and second_character.spawn_point == Vector2(555, 400),
		"Players get distinct seat anchors and one character each")
	_check(first.player.character_shape == "squircle" and second.player.character_shape == "squircle"
		and first_character.get_node("Nameplate").text == "First"
		and (first_character.get_node("SquircleV1Playback/Colorable") as Sprite2D).texture.resource_path == "res://assets/runtime/animated_characters/squircle/v1/idle-front-colorable.png"
		and (first_character.get_node("SquircleV1Playback/Colorable") as Sprite2D).material.get_shader_parameter("player_color") == Color("#EC407A"),
		"Lobby Squircle v1 uses the name and registered tint")
	_check(first_character.collision_layer == 256 and first_character.collision_mask == 384,
		"Characters collide with one-way platforms and one another")
	for unused: int in 5:
		await physics_frame
	_check(first_character.is_on_floor(), "Spawned character lands on the first shelf")
	var first_player := registry.player_for_connection(100)
	var second_player := registry.player_for_connection(101)
	_check(not world.handle_input({}, {"type": "lobby_move", "input_seq": 1, "horizontal": 1.0, "vertical": 0.0, "stance": "move"}, now).accepted,
		"Unregistered input is rejected")
	_check(not world.handle_input(first_player, {"type": "lobby_move", "input_seq": 1, "horizontal": 2.0}, now).accepted
		and not world.handle_input(first_player, {"type": "lobby_move", "input_seq": 1, "horizontal": "1"}, now).accepted,
		"Out-of-range and nonnumeric movement are rejected")
	_check(world.handle_input(first_player, {"type": "lobby_move", "input_seq": 1, "horizontal": 0.0, "vertical": 1.0, "stance": "look_up"}, now).accepted,
		"Vertical intent reaches the host motor")
	await physics_frame
	await physics_frame
	_check(first_character.motor.presentation_action() == "look_up"
		and first_character.get_node("SquircleV1Playback").get("_clip_key") == "look_up-front", "Grounded up uses the approved held pose")
	world.reset_sequence(first_id)
	_check(world.handle_input(first_player, {"type": "lobby_move", "input_seq": 1, "horizontal": 0.7, "vertical": 0.0, "stance": "move"}, now).accepted
		and world.handle_input(second_player, {"type": "lobby_move", "input_seq": 1, "horizontal": -0.5, "vertical": 0.0, "stance": "move"}, now).accepted,
		"Separate players can hold independent analog movement")
	_check(not world.handle_input(first_player, {"type": "lobby_move", "input_seq": 1, "horizontal": -1.0}, now).accepted
		and not world.handle_input(first_player, {"type": "lobby_move", "input_seq": 0, "horizontal": -1.0}, now).accepted,
		"Duplicate and stale sequences cannot replace current intent")
	for unused: int in 8:
		await physics_frame
	_check(first_character.position.x > first_character.spawn_point.x
		and second_character.position.x < second_character.spawn_point.x,
		"The host advances characters in opposite directions independently")
	_check((first_character.get_node("SquircleV1Playback/Face") as Sprite2D).flip_h
		and not (second_character.get_node("SquircleV1Playback/Face") as Sprite2D).flip_h
		and (first_character.get_node("SquircleV1Playback/Colorable") as Sprite2D).flip_h
		== (first_character.get_node("SquircleV1Playback/Face") as Sprite2D).flip_h,
		"Three-quarter body and face point in the direction of travel")
	_check(world.handle_input(first_player, {"type": "lobby_jump_release", "input_seq": 2, "horizontal": 0.0, "vertical": 0.0, "stance": "neutral", "action": "jump"}, now).jumped
		and not world.handle_input(first_player, {"type": "lobby_jump_release", "input_seq": 3, "horizontal": 0.0, "vertical": 0.0, "stance": "neutral", "action": "jump"}, now).jumped,
		"One grounded release queues exactly one jump")
	await physics_frame
	_check(first_character.velocity.y < 0.0 and not world.handle_input(first_player,
		{"type": "lobby_jump_release", "input_seq": 4, "horizontal": 0.0, "vertical": 0.0, "stance": "neutral", "action": "jump"}, now).jumped,
		"Airborne release cannot queue another jump")
	world.clear_all_input()
	_check(first_character.motor.axes == Vector2.ZERO and second_character.motor.axes == Vector2.ZERO,
		"State transitions clear every held stick")
	registry.disconnect_connection(100, now)
	_check(world.character_for(first_id) == first_character and not first_character.connected
		and not first_character.is_physics_processing(), "Reconnect grace retains a stationary character")
	var resumed := registry.resume_player(102, registry.session_id, first.reconnect_token, now + 1000)
	_check(resumed.accepted and world.character_for(first_id) == first_character and first_character.connected,
		"Resume restores control to the same character")
	for index: int in range(2, 10):
		registry.join_player(100 + index + 1, "Player %d" % index, true, now)
	_check(world.get_node("CharactersFrontOfPanels").get_child_count() == 10,
		"All ten registered seats spawn a character")
	registry.leave_connection(101)
	await process_frame
	var replacement := registry.join_player(200, "Replacement", true, now)
	_check(replacement.accepted and replacement.player.seat == 2
		and world.character_for(String(replacement.player.player_id)).spawn_point == Vector2(555, 400),
		"A released seat reuses its anchor without overlapping an occupied seat")
	first_character.position.y = first_character.motor.fall_reset_y + 10.0
	await physics_frame
	await physics_frame
	_check(first_character.position.distance_to(first_character.spawn_point) < 3.0,
		"A fallen character returns to its assigned anchor")
	registry.disconnect_connection(102, now)
	registry.expire_players(now + 60000)
	await process_frame
	_check(world.character_for(first_id) == null, "Expired reservation removes its character")
	registry.players_changed.disconnect(refresh)
	world.queue_free()
	await process_frame
	print("Lobby playground control checks: %d failures" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)
