extends TestScript
## The phone protocol of Bubbles and jellyfishes 3D: only its two message types, strict field
## validation, host-measured touch timing, screen-to-plane axes, the live drag stretch and its
## rate limits, snapshots without spin, and pushed feedback and visuals.

var _controller: Bubbles3DRoundController
var _protocol: Bubbles3DProtocol
var _sent: Array[Dictionary] = []
var _broadcasts := 0
var _drags: Array[Vector2] = []
var _swipes: Array[Vector2] = []
var _p1 := { "player_id": "p1" }


func _run() -> void:
	_controller = Bubbles3DRoundController.new()
	root.add_child(_controller)
	_controller.set_process(false)
	_controller.tuning = Bubbles3DTuning.new()
	_controller.tuning.countdown_seconds = 0.0
	_protocol = Bubbles3DProtocol.new(_controller)
	_protocol.send_requested.connect(
		func(player_id: String, message: Dictionary, coalesce: bool) -> void:
			_sent.append({ "to": player_id, "message": message, "coalesce": coalesce }),
	)
	_protocol.broadcast_requested.connect(
		func() -> void:
			_broadcasts += 1,
	)
	_controller.drag_visual_changed.connect(
		func(_id: String, drag: Vector2, _started: int) -> void:
			_drags.append(drag),
	)
	_controller.arena_event_requested.connect(
		func(kind: StringName, _id: String, data: Dictionary) -> void:
			if kind == &"swipe":
				_swipes.append(data.direction),
	)
	check(
		_protocol.handles("bubbles_3d_touch") and _protocol.handles("bubbles_3d_release"),
		"Both types",
	)
	check(not _protocol.handles("bubbles_3d_spin"), "No spin message is handled")

	var players := [
		{ "player_id": "p1", "seat": 1, "state": "connected" },
		{ "player_id": "p2", "seat": 2, "state": "connected" },
	]
	_controller.start_round(players, 0)
	_controller.complete_entrance(0)
	_controller.advance(0)
	check(_broadcasts >= 1, "Phase changes ask for a broadcast")

	_test_validation()
	_test_touch_and_release()
	_test_snapshot_and_pushes()
	_protocol.detach()
	check(
		not _controller.feedback_requested.is_connected(_protocol._on_feedback),
		"Detaching disconnects the protocol from the round",
	)


func _touch(sequence: Variant, stage: String, at: int, drag: Variant = null) -> Dictionary:
	var message := { "type": "bubbles_3d_touch", "input_seq": sequence, "stage": stage }
	if drag != null:
		message.drag = drag
	return _protocol.handle_message(_p1, message, at)


func _release(sequence: Variant, displacement: Variant, at: int) -> Dictionary:
	var message := {
		"type": "bubbles_3d_release",
		"input_seq": sequence,
		"displacement": displacement,
	}
	return _protocol.handle_message(_p1, message, at)


func _test_validation() -> void:
	var anonymous := { "type": "bubbles_3d_touch", "input_seq": 1 }
	var unjoined := _protocol.handle_message({ }, anonymous, 10)
	check(not unjoined.accepted, "An unjoined connection is rejected")
	check(not _touch(1.5, "start", 10).accepted, "A fractional sequence is rejected")
	check(not _touch(-1, "start", 10).accepted, "A negative sequence is rejected")
	check(not _touch(1, "spin", 10).accepted, "An unknown stage is rejected")
	check(not _touch(1, "start", 10, [1, 0]).accepted, "A start with a drag is rejected")
	var extra := { "type": "bubbles_3d_touch", "input_seq": 1, "stage": "start", "player_id": "p2" }
	check(not _protocol.handle_message(_p1, extra, 10).accepted, "A claimed identity is rejected")
	check(not _release(1, [0.2], 10).accepted, "A short displacement is rejected")
	check(not _release(1, [INF, 0.0], 10).accepted, "A non-finite displacement is rejected")
	check(not _release(1, ["x", 0.0], 10).accepted, "A text displacement is rejected")


func _test_touch_and_release() -> void:
	check(_touch(1, "start", 100).accepted, "A touch starts")
	check(_drags.back() == Vector2.ZERO, "A new touch starts without stretch")
	check(_touch(1, "drag", 120, [4, -4]).accepted, "A drag updates the stretch")
	check(_drags.back().is_equal_approx(Vector2(1.0, 1.0)), "Screen up is plane up")
	check(not _touch(1, "drag", 130, [5, 0]).accepted, "A drag beyond four steps is rejected")
	check(not _touch(1, "drag", 130, [1.5, 0]).accepted, "A fractional drag is rejected")
	var before := _drags.size()
	_touch(1, "drag", 140, [0, 1])
	check(_drags.size() == before, "Drags closer than the interval are dropped")
	var released := _release(1, [0.3, -0.2], 300)
	check(
		released.accepted and released.reply.action == "swipe" and released.snapshot,
		"A quick release swipes and asks for a snapshot",
	)
	check(_swipes.back().is_equal_approx(Vector2(0.3, 0.2).normalized()), "The swipe is flipped")
	check(_drags.back() == Vector2.ZERO, "Releasing settles the stretch")
	check(not _release(1, [0.3, 0.0], 310).accepted, "A sequence swipes once")

	_touch(2, "start", 400)
	var slow := _release(2, [0.3, 0.0], 400 + 2000)
	check(
		slow.reply.action == "none" and slow.reply.reason == "swipe_too_slow",
		"The host times holds",
	)

	_touch(3, "start", 3000)
	check(_touch(3, "cancel", 3010).accepted, "A touch can be canceled")
	check(not _release(3, [0.3, 0.0], 3020).accepted, "A canceled touch cannot swipe")

	_touch(4, "start", 4000)
	for index: int in 60:
		_touch(4, "drag", 4000 + 70 * (index + 1), [index % 3, 0])
	var drags := _drags.size()
	_touch(4, "drag", 9000, [1, 1])
	check(_drags.size() == drags, "A touch sends at most a bounded number of drags")
	var held := _release(4, [0.3, 0.0], 9050)
	check(held.reply.reason == "swipe_too_slow", "A long hold stays timed from its start")
	check(not _touch(2, "start", 9100).accepted, "An old sequence cannot restart a touch")


func _test_snapshot_and_pushes() -> void:
	var snapshot := _protocol.snapshot_for("p1")
	check(snapshot.type == "bubbles_3d_snapshot" and snapshot.phase == "active", "A live snapshot")
	for key: String in snapshot.keys():
		check(not key.contains("spin") and not key.contains("charge"), "No spin field: %s" % key)
	check(snapshot.visual_tuning.visual_cap == 16, "The snapshot carries the visual cap")
	check(_protocol.snapshot_for("nobody").type == "lobby", "Strangers wait for the next game")

	_sent.clear()
	_controller.record_jellyfish_capture("p1", 9500)
	var feedback := _sent.filter(
		func(entry: Dictionary) -> bool:
			return entry.message.type == "bubbles_3d_feedback",
	)
	check(
		feedback.size() == 1 and feedback[0].message.event == "captured"
		and feedback[0].message.score == 1,
		"A catch sends feedback with the new score",
	)
	_controller.pop_player("p1", 9600)
	var popped := _sent.filter(
		func(entry: Dictionary) -> bool:
			return entry.message.get("event", "") == "pop",
	)
	check(popped.size() == 1 and popped[0].message.lost == 1, "A pop tells the phone what it lost")
	_controller.personal_visual_changed.emit("p1", { "radius": 0.5 })
	var visual: Dictionary = _sent.back()
	check(
		visual.message.type == "bubbles_3d_visual" and visual.coalesce,
		"Visuals go out coalesced",
	)
