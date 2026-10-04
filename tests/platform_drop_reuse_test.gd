extends TestScript
## Real physics on generic bodies: no LobbySquircle, registry or UI required.

const FIXTURE := preload("res://tests/fixtures/platform_reuse.tscn")
var _fixture: Node2D
var _body: CharacterBody2D
var _other: CharacterBody2D
var _motor: PlatformMotor
var _top: PlatformSurface
var _lower: PlatformSurface
var _ground: PlatformSurface


func _run() -> void:
	_fixture = FIXTURE.instantiate()
	root.add_child(_fixture)
	_body = _fixture.get_node("Body")
	_other = _fixture.get_node("OtherBody")
	_motor = _body.get_node("PlatformMotor")
	_top = _fixture.get_node("OpenTop")
	_lower = _fixture.get_node("OpenLower")
	_ground = _fixture.get_node("ClosedGround")
	await _frames(5)
	check(_motor.supporting_surface() == _top, "Generic motor resolves its actual Open support")
	_down()
	check(_motor.presentation_action() == "crouch", "Grounded down selects crouch")
	var shape: CollisionShape2D = _body.get_node("CollisionShape2D")
	check(
		(shape.shape as CapsuleShape2D).height == 96.0 and shape.position == Vector2(0, -48),
		"Crouch preserves full upright hitbox and feet",
	)
	check(
		_motor.request_fall() and _body.get_collision_exceptions() == [_top]
		and _body.floor_snap_length == 0.0 and _body.collision_mask == 384,
		"Drop excludes only support and temporarily suspends snap",
	)
	check(
		not _motor.request_fall() and not _motor.request_jump(),
		"Repeated/competing attempts cannot queue during drop",
	)
	await _frames(42)
	check(
		_motor.supporting_surface() == _lower and absf(_body.position.y - 390.0) < 1.0,
		"Drop lands on the next Open platform below",
	)
	check(
		_other.is_on_floor() and absf(_other.position.y - 240.0) < 1.0
		and _other.get_collision_exceptions().is_empty() and _top.collision_layer == 128,
		"Other player and shared support remain untouched",
	)
	check(
		_body.get_collision_exceptions().is_empty() and _body.floor_snap_length == 8.0,
		"Full clearance restores support and floor snap",
	)
	_down()
	check(not _motor.request_fall(), "Held-down repeated release cannot bypass the next floor")
	_motor.set_input(Vector2.ZERO, "neutral", Time.get_ticks_msec())
	_down()
	check(_motor.request_fall(), "Fresh downward gesture allows a deliberate second descent")
	await _frames(42)
	check(_motor.supporting_surface() == _ground, "Second deliberate drop lands on Closed ground")
	_down()
	check(
		not _motor.request_fall() and _body.velocity.y >= 0.0,
		"Closed rejects FALL without jumping",
	)
	await _frames(4)
	check(
		_body.is_on_floor() and absf(_body.position.y - 540.0) < 1.0,
		"Closed remains dependable after rejected attempt",
	)
	_top.drop_rule = PlatformSurface.DropRule.CLOSED
	await _place(Vector2(180, 240))
	_down()
	check(
		not _motor.request_fall(),
		"Changing one authored Open to Closed changes only its drop rule",
	)
	check(
		(_top.get_node("LandingTop") as CollisionShape2D).one_way_collision,
		"Closed still preserves its one-way underside",
	)
	_top.drop_rule = PlatformSurface.DropRule.OPEN
	_motor.set_input(Vector2(0, 1), "look_up", Time.get_ticks_msec())
	check(_motor.presentation_action() == "look_up", "Grounded up selects look-up")
	_motor.set_input(Vector2(0.7, 0.7), "move", Time.get_ticks_msec())
	check(
		_motor.presentation_action() not in ["look_up", "crouch"],
		"Diagonal returns to ordinary locomotion",
	)
	_down()
	_motor.expire_input(Time.get_ticks_msec() + 351)
	check(
		_motor.axes == Vector2.ZERO and _motor.stance == "neutral" and not _motor._jump_queued,
		"Lost release expires both axes and stance",
	)
	await _frames(2)
	_down()
	check(_motor.request_fall(), "Drop begins for disconnect cleanup")
	_motor.set_enabled(false)
	check(
		_body.get_collision_exceptions().is_empty() and _body.floor_snap_length == 8.0
		and _motor.axes == Vector2.ZERO and _motor.stance == "neutral",
		"Disconnect clears exclusion, snap, stance and actions",
	)
	_motor.set_enabled(true)
	_down()
	check(not _motor.request_fall(), "Resume cannot reuse cached floor contacts before physics")
	await _frames(2)
	_down()
	check(_motor.request_fall(), "Fresh post-resume physics allows control")
	_motor.clear_input()
	check(
		_body.get_collision_exceptions().is_empty(),
		"Active-context exit restores exclusion immediately",
	)
	await _place(Vector2(180, 190))
	_down()
	check(not _motor.request_fall(), "Airborne fall attempt is discarded")
	await _frames(30)
	check(
		_motor.supporting_surface() == _top and _body.get_collision_exceptions().is_empty(),
		"Rejected airborne FALL never becomes a later drop",
	)
	# Closely stacked tops: the lower support must catch even before full-body clearance.
	_lower.position.y = 290
	await _frames(2)
	_down()
	check(_motor.request_fall(), "Drop into close stacked surface begins")
	await _frames(24)
	check(
		_motor.supporting_surface() == _lower and _body.get_collision_exceptions().is_empty(),
		"Close lower contact restores upper while keeping the lower landing",
	)
	_lower.position.y = 395
	# Player support must not inherit the platform beneath that other player.
	await _place(Vector2(_other.position.x, _other.position.y - 96))
	await _frames(5)
	_down()
	check(
		_body.is_on_floor() and _motor.supporting_surface() == null and not _motor.request_fall(),
		"Standing on another character rejects FALL",
	)
	# Existing player rebound survives extraction.
	await _place(Vector2(_other.position.x, 100))
	_body.velocity.y = 250
	var bounced := false
	for index: int in 20:
		await _frames(1)
		if _body.velocity.y < 0:
			bounced = true
			break
	check(bounced, "Falling onto another character retains bounce")
	await _place(Vector2(180, 240))
	_motor.drop_timeout_seconds = 0.1
	_motor.drop_speed = 1.0
	_motor.gravity = 0.0
	_down()
	check(_motor.request_fall(), "Slow clearance timeout begins")
	await _frames(8)
	check(
		_body.get_collision_exceptions().is_empty() and _body.floor_snap_length == 8.0,
		"Timeout restores collision even without clearance",
	)
	_motor.gravity = 1350
	_motor.drop_speed = 80
	_motor.drop_timeout_seconds = 0.65
	await _place(Vector2(559, 240))
	_down()
	check(_motor.request_fall(), "Edge drop begins")
	_body.position.x = 600
	await _frames(2)
	check(
		_body.get_collision_exceptions().is_empty(),
		"Horizontal clearance at edge restores exclusion",
	)
	await _place(Vector2(180, 240))
	_down()
	check(_motor.request_fall(), "Fall reset cleanup begins")
	_body.position.y = _motor.fall_reset_y + 10
	await _frames(2)
	check(
		_body.get_collision_exceptions().is_empty() and _motor.axes == Vector2.ZERO,
		"Fall reset clears temporary contact and intent",
	)
	await _place(Vector2(180, 240))
	_motor.set_input(Vector2.ZERO, "neutral", Time.get_ticks_msec())
	check(_motor.request_jump(), "Grounded jump accepted before lost-input timeout")
	_motor.expire_input(Time.get_ticks_msec() + 351)
	await _frames(2)
	check(_body.velocity.y >= 0 and _body.is_on_floor(), "Expired jump never executes later")
	_down()
	check(_motor.request_fall(), "Input lease cleanup begins")
	_motor.expire_input(Time.get_ticks_msec() + 351)
	check(
		_body.get_collision_exceptions().is_empty() and _body.floor_snap_length == 8.0,
		"Input expiry also restores transient drop contact",
	)
	await _place(Vector2(180, 240))
	_down()
	check(_motor.request_fall(), "Removal cleanup begins")
	_body.remove_child(_motor)
	check(
		_body.get_collision_exceptions().is_empty() and _body.floor_snap_length == 8.0,
		"Removing component restores the surviving body",
	)
	_motor.free()
	# A freed support must not leave an exclusion or a dangling access in another motor.
	var other_motor: PlatformMotor = _other.get_node("PlatformMotor")
	other_motor.set_input(Vector2(0, -1), "crouch", Time.get_ticks_msec())
	check(other_motor.request_fall(), "Support removal cleanup begins")
	_top.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	check(
		_other.get_collision_exceptions().is_empty() and _other.floor_snap_length == 8.0,
		"Freeing active support restores contact without dangling accesses",
	)
	_fixture.queue_free()
	await process_frame


func _down() -> void:
	_motor.set_input(Vector2(0, -1), "crouch", Time.get_ticks_msec())


func _place(point: Vector2) -> void:
	_motor.clear_input()
	_body.position = point
	_body.velocity = Vector2.ZERO
	await _frames(3)


func _frames(count: int) -> void:
	for index: int in count:
		# Refresh to simulate the real phone heartbeat rather than expire mid-scenario.
		_motor.set_input(_motor.axes, _motor.stance, Time.get_ticks_msec())
		await physics_frame
		await process_frame
