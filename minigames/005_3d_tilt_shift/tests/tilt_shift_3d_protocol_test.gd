extends TestScript
## The phone's view of Tilt Shift 3D: each snapshot carries the player's colour, team, paddle
## size, the paddle's look, its physical angle and the strongest face across the player's
## paddles; a face change goes out at once; spectators rest level; READY reaches the rules only
## through its own message type, and a stale one resyncs instead of failing.


func _run() -> void:
	var profile: TiltShift3DTuning = (
		load("res://minigames/005_3d_tilt_shift/tuning/Default.tres") as TiltShift3DTuning
	).duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var controller := TiltShift3DShiftController.new()
	controller.tuning = profile
	root.add_child(controller)
	var players := TiltShift3DFixtures.players(6)
	players[0].character_color = "blue"
	check(controller.start_shift(players, 0, true).accepted, "A six-player shift starts")
	var state := controller.snapshot()

	var protocol := TiltShift3DProtocol.new("generation")
	protocol.set_look(profile)
	protocol.apply_snapshot(state)
	check(protocol.handles(TiltShift3DProtocol.READY), "READY is the protocol's message")
	check(not protocol.handles("other_ready"), "Unrelated messages are not handled")

	var selected: TiltShift3DState.Player
	var spectator: TiltShift3DState.Player
	for player: TiltShift3DState.Player in state.players:
		if player.selected and selected == null:
			selected = player
		elif not player.selected and spectator == null:
			spectator = player
	var wire := protocol.snapshot_for(selected.player_id)
	check(wire.type == "tilt_shift_3d_snapshot", "Snapshots are Tilt Shift 3D's")
	check(
		wire.color == TiltShift3DPresentation.player_color(selected.character_color).to_html(false),
		"The snapshot carries the player's colour",
	)
	check(wire.team == selected.team, "It carries the player's team")
	var size: Vector2 = state.paddle_layout.paddle_size(selected.team, state.physics)
	check(wire.paddle_size == [size.x, size.y], "It carries the paddle's size in arena widths")
	var look: Dictionary = wire.look
	check(
		is_equal_approx(look.corner_ratio, 0.35) and is_equal_approx(look.gap_ratio, 0.06)
		and is_equal_approx(look.outline_ratio, 0.09) and is_equal_approx(look.face_ratio, 0.72),
		"It carries the shared screen's proportions",
	)
	check((look.outline_colors as Array).size() == 3, "It carries both teams' outlines")
	check(wire.face == "face_slightly_smiling", "A player with no expression shows the play face")
	check(JSON.stringify(wire).length() < 900, "A snapshot stays small")

	var sent: Array[Dictionary] = []
	protocol.send_requested.connect(
		func(_id: String, message: Dictionary, _coalesce: bool) -> void:
			sent.append(message),
	)
	check(protocol.apply_face(selected.player_id, "face_dizzy"), "A new face is recorded")
	check(not protocol.apply_face(selected.player_id, "face_dizzy"), "The same face is not news")
	protocol.publish(selected.player_id)
	check(sent.size() == 1 and sent[0].face == "face_dizzy", "The face goes to the phone")
	check(protocol.apply_angle(selected.player_id, 0.4), "A physical angle is recorded")
	check(
		is_equal_approx(protocol.snapshot_for(selected.player_id).angle_radians, 0.4),
		"The phone turns with the physical angle",
	)

	var waiting := protocol.snapshot_for(spectator.player_id)
	check(waiting.selected == false and waiting.angle_radians == 0.0, "Spectators rest level")
	check(
		waiting.face == "face_slightly_smiling",
		"Spectators show the play face, blinking on the phone",
	)

	var calls: Array[String] = []
	protocol.ready_action = _record.bind(calls)
	var ready := {
		"type": TiltShift3DProtocol.READY,
		"generation": "generation",
		"round_token": state.round_token,
		"ready": true,
	}
	var result := protocol.handle_message({ "player_id": selected.player_id }, ready, 0)
	check(result.accepted and not result.snapshot, "A current READY reaches the rules")
	check(calls == [selected.player_id], "It acts for the host-resolved player")
	ready.round_token = "old"
	result = protocol.handle_message({ "player_id": selected.player_id }, ready, 0)
	check(result.accepted and result.snapshot, "A stale READY is dropped with a resync")
	check(calls.size() == 1, "A stale READY never reaches the rules")
	protocol.detach()
	check(not protocol.ready_action.is_valid(), "Detaching drops the rules' callbacks")
	controller.queue_free()


func _record(
	player_id: String,
	_ready: bool,
	_token: String,
	_now: int,
	calls: Array[String],
) -> bool:
	calls.append(player_id)
	return true
