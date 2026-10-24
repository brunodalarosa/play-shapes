class_name TiltShift3DArena
extends Node3D
## Shared gameplay and preview physics on Jolt, every body on the plane at depth zero. The caller
## supplies content, roster and host clock. The arena is centred on its origin, Y up, and one
## arena width is WORLD_UNITS world units. Rules and content measure positions from the arena's
## top-left with Y down; the arena converts between the two. It draws nothing itself.

signal ball_spawned(ball: TiltShift3DBall)
signal ball_removed(handle: TiltShift3DState.BallHandle, basket_id: String)
## A ball made a new contact with [param paddle], closing at [param speed] arena widths/s.
signal paddle_hit(paddle: TiltShift3DPaddleBody, speed: float)
## The round's paddles, walls and floor were rebuilt.
signal bodies_built
signal stopped

## World units in one arena width: 100 world units per 1,920 pixels.
const WORLD_UNITS := 19.2
const WALL_THICKNESS := 0.4
## Depth of walls and floor, front to back; more than any paddle or ball.
const WALL_DEPTH := 4.0

var controller: TiltShift3DShiftController
var clock: Callable = Time.get_ticks_msec
var spawned_count: int = 0
var positive_spawned_count: int = 0
var negative_spawned_count: int = 0
var peak_live_balls: int = 0
var position_seed_used: int = 0
var last_step_usec: int = 0
## The top of the visible frame in arena coordinates; balls enter wholly above it.
var visible_top: float = 0.0
var _profile: TiltShift3DPhysicsTuning
var _snapshot: TiltShift3DState.Snapshot
var _paddles: Array[TiltShift3DPaddleBody] = []
var _balls: Array[TiltShift3DBall] = []
var _floor: Array[StaticBody3D] = []
var _walls: Array[StaticBody3D] = []
var _schedule := PackedInt32Array()
var _negative_schedule := PackedInt32Array()
var _next_negative_delivery: int = 0
var _round_duration: int = 0
var _next_delivery: int = 0
var _active: bool = false
var _delivery_duration: int = 0
var _positions := RandomNumberGenerator.new()


func start_shift(
	selected: TiltShift3DTuning,
	players: Array[TiltShift3DState.Player],
	wait_for_initial_motion: bool = false,
) -> TiltShift3DState.Result:
	if selected == null:
		return TiltShift3DState.rejected(&"invalid_tuning")
	var errors := selected.validation_errors()
	if not errors.is_empty():
		return TiltShift3DState.rejected(&"invalid_tuning", errors)
	if controller != null and controller.snapshot().phase not in [&"idle", &"finished"]:
		return TiltShift3DState.rejected(&"shift_already_running")
	stop()
	controller = TiltShift3DShiftController.new()
	controller.tuning = selected
	add_child(controller)
	controller.round_prepared.connect(_on_round_prepared)
	controller.round_started.connect(_on_round_started)
	controller.round_ended.connect(_on_round_ended)
	controller.angle_changed.connect(_on_angle_changed)
	var result := controller.start_shift(players, clock.call(), wait_for_initial_motion)
	if not result.accepted:
		stop()
	return result


func start_next_round() -> TiltShift3DState.Result:
	if controller == null or _active:
		return TiltShift3DState.rejected(&"next_round_unavailable")
	_clear_balls()
	return controller.start_next_round(clock.call())


func stop() -> void:
	stopped.emit()
	_active = false
	_clear_balls()
	for body: Node in _paddles + _walls + _floor:
		_retire_body(body)
	_paddles.clear()
	_walls.clear()
	_floor.clear()
	if is_instance_valid(controller):
		# A stop inside one of its notifications must not let the signals it emits next,
		# such as round_started right after phase_changed, revive the arena.
		controller.round_prepared.disconnect(_on_round_prepared)
		controller.round_started.disconnect(_on_round_started)
		controller.round_ended.disconnect(_on_round_ended)
		controller.angle_changed.disconnect(_on_angle_changed)
		controller.queue_free()
	controller = null
	_snapshot = null
	_profile = null
	_schedule.clear()
	_negative_schedule.clear()


func live_balls() -> Array[TiltShift3DBall]:
	return _balls.duplicate()


func paddle_bodies() -> Array[TiltShift3DPaddleBody]:
	return _paddles.duplicate()


func floor_bodies() -> Array[StaticBody3D]:
	return _floor.duplicate()


func wall_bodies() -> Array[StaticBody3D]:
	return _walls.duplicate()


## The round's snapshot as the arena last saw it, or null.
func current_snapshot() -> TiltShift3DState.Snapshot:
	return _snapshot


## True between START and the round's end, while balls are delivered and scored.
func is_active() -> bool:
	return _active


## The arena's size in world units, for the round's layout or the default frame.
func world_size() -> Vector2:
	var size := Vector2(1.0, 0.5625)
	if _snapshot != null:
		size = _snapshot.paddle_layout.arena_size
	return size * WORLD_UNITS


## The floor's height below the arena's top, in world units.
func floor_depth() -> float:
	if _snapshot == null:
		return world_size().y
	return (_snapshot.paddle_layout.arena_size.y - _profile.bin_band) * WORLD_UNITS


## A point measured from the arena's top-left, Y down, in world units, as a 3D position.
func to_world(point: Vector2) -> Vector3:
	var size := world_size()
	return Vector3(point.x - size.x * 0.5, size.y * 0.5 - point.y, 0.0)


## A 3D position as a point measured from the arena's top-left, Y down, in world units.
func to_arena(position: Vector3) -> Vector2:
	var size := world_size()
	return Vector2(position.x + size.x * 0.5, size.y * 0.5 - position.y)


## Signed swept clearances, in arena units. Negative values are diagnostics, not auto edits.
func swept_clearances() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	if _snapshot == null:
		return values
	var floor_y := floor_depth() / WORLD_UNITS
	for index: int in _paddles.size():
		var radius := _swept_radius(_paddles[index])
		var position := to_arena(_paddles[index].position) / WORLD_UNITS
		var size := _snapshot.paddle_layout.arena_size
		values.append(minf(minf(position.x, size.x - position.x), position.y) - radius)
		values.append(floor_y - position.y - radius)
		for other: int in range(index + 1, _paddles.size()):
			var at := to_arena(_paddles[other].position) / WORLD_UNITS
			values.append(position.distance_to(at) - radius - _swept_radius(_paddles[other]))
	return values


func _swept_radius(paddle: TiltShift3DPaddleBody) -> float:
	return Vector2(paddle.size.x, paddle.size.y).length() * 0.5 / WORLD_UNITS


func _physics_process(delta: float) -> void:
	step(delta, clock.call())


func _exit_tree() -> void:
	stop()


## Called at fixed physics ticks. An injected clock makes preview and boundary tests reusable.
func step(delta: float, host_time_msec: int) -> void:
	var began := Time.get_ticks_usec()
	if controller == null or not is_finite(delta) or delta < 0.0 or delta > 0.05:
		return
	if not controller.advance(host_time_msec).accepted or _snapshot == null:
		return
	var round_token := _snapshot.round_token
	for paddle: TiltShift3DPaddleBody in _paddles:
		paddle.advance_pose(delta, _active)
	if not _active:
		return
	_observe_balls(host_time_msec)
	if not _active or _snapshot.round_token != round_token:
		return
	var elapsed := host_time_msec - _snapshot.started_at_msec
	var weight := 0.0
	if _delivery_duration > 0 and elapsed < _delivery_duration:
		weight = TiltShift3DDelivery.intensity(
			_profile.delivery_curve,
			float(elapsed) / _delivery_duration,
		)
	if weight > 0.0:
		while _next_delivery < _schedule.size() and _schedule[_next_delivery] <= elapsed:
			_spawn(host_time_msec)
			# A preview observer can stop/restart synchronously during a delivery notification.
			if not _active or _snapshot.round_token != round_token:
				return
			_next_delivery += 1
	var negative_weight := TiltShift3DDelivery.intensity(
		_profile.negative_delivery_curve,
		float(elapsed) / _round_duration,
		true,
	)
	if negative_weight > 0.0:
		while _next_negative_delivery < _negative_schedule.size() \
				and _negative_schedule[_next_negative_delivery] <= elapsed:
			_spawn(host_time_msec, -1)
			if not _active or _snapshot.round_token != round_token:
				return
			_next_negative_delivery += 1
	last_step_usec = Time.get_ticks_usec() - began


func _on_round_prepared(snapshot: TiltShift3DState.Snapshot) -> void:
	if not snapshot.reworked:
		return
	_active = false
	_clear_balls()
	for body: Node in _paddles + _walls + _floor:
		_retire_body(body)
	_paddles.clear()
	_walls.clear()
	_floor.clear()
	_snapshot = snapshot
	_profile = snapshot.physics
	if snapshot.round_number == 1:
		_positions.randomize()
		if _profile.use_position_seed:
			_positions.seed = _profile.position_seed
		position_seed_used = _positions.seed
		peak_live_balls = 0
	spawned_count = 0
	for paddle: TiltShift3DPaddle in snapshot.paddle_layout.paddles:
		_add_paddle(paddle, snapshot.paddle_layout, snapshot.auto_direction)
	_build_walls()
	_build_floor()
	for player: TiltShift3DState.Player in snapshot.players:
		_on_angle_changed(player)
	bodies_built.emit()


func _on_round_started(snapshot: TiltShift3DState.Snapshot) -> void:
	_clear_balls()
	_snapshot = snapshot
	_profile = snapshot.physics
	var rebuilt := false
	if snapshot.round_number == 1 and not snapshot.reworked:
		_positions.randomize()
		if _profile.use_position_seed:
			_positions.seed = _profile.position_seed
		position_seed_used = _positions.seed
		peak_live_balls = 0
		for paddle: TiltShift3DPaddle in snapshot.paddle_layout.paddles:
			_add_paddle(paddle, null, 1.0)
		_build_walls()
		rebuilt = true
	for player: TiltShift3DState.Player in snapshot.players:
		_on_angle_changed(player)
	if not snapshot.reworked:
		_build_floor()
	_delivery_duration = snapshot.deadline_msec - snapshot.started_at_msec \
			- roundi(_profile.delivery_cutoff_seconds * 1000.0)
	_schedule = TiltShift3DDelivery.schedule(
		_profile.ball_count,
		_profile.delivery_curve,
		_delivery_duration,
	)
	_next_delivery = 0
	_round_duration = snapshot.deadline_msec - snapshot.started_at_msec
	_negative_schedule = TiltShift3DDelivery.schedule(
		_profile.negative_ball_count,
		_profile.negative_delivery_curve,
		_round_duration,
		true,
	)
	_next_negative_delivery = 0
	spawned_count = 0
	positive_spawned_count = 0
	negative_spawned_count = 0
	_active = true
	if rebuilt:
		bodies_built.emit()


func _on_round_ended(_state: TiltShift3DState.Snapshot) -> void:
	_active = false
	_clear_balls()


func _on_angle_changed(player: TiltShift3DState.Player) -> void:
	for paddle: TiltShift3DPaddleBody in _paddles:
		if player.paddle_ids.has(paddle.paddle_id):
			paddle.target_angle = player.angle_radians


func _add_paddle(
	paddle: TiltShift3DPaddle,
	layout: TiltShift3DPaddleLayout,
	direction: float,
) -> void:
	var body := TiltShift3DPaddleBody.new()
	body.configure(paddle, _profile, WORLD_UNITS, layout, direction)
	body.position = to_world(paddle.position * WORLD_UNITS)
	add_child(body)
	_paddles.append(body)


func _spawn(host_time_msec: int, score_value: int = 1) -> TiltShift3DBall:
	if not _active or score_value not in [-1, 1]:
		return null
	if score_value > 0 and positive_spawned_count >= _profile.ball_count:
		return null
	if score_value < 0 and negative_spawned_count >= _profile.negative_ball_count:
		return null
	var registration := controller.register_ball(_snapshot.round_token, host_time_msec, score_value)
	if not registration.accepted:
		return null
	var ball := TiltShift3DBall.new()
	ball.handle = registration.ball
	ball.score_value = score_value
	ball.configure(_profile, WORLD_UNITS)
	var center := _snapshot.paddle_layout.arena_size.x * 0.5
	var horizontal := _positions.randf_range(-_profile.spawn_half_width, _profile.spawn_half_width)
	var spawn_y := _profile.ball_radius * WORLD_UNITS
	if _snapshot.reworked:
		spawn_y = visible_top - (_profile.spawn_height + _profile.ball_radius) * WORLD_UNITS
	var point := Vector2((center + horizontal) * WORLD_UNITS, spawn_y)
	ball.position = to_world(point)
	ball.previous_position = point
	ball.paddle_touched.connect(_on_paddle_touched)
	add_child(ball)
	_balls.append(ball)
	spawned_count += 1
	if score_value < 0:
		negative_spawned_count += 1
	else:
		positive_spawned_count += 1
	peak_live_balls = maxi(peak_live_balls, _balls.size())
	ball_spawned.emit(ball)
	return ball


func _on_paddle_touched(paddle: TiltShift3DPaddleBody, speed: float) -> void:
	if _active and is_instance_valid(paddle):
		paddle_hit.emit(paddle, speed / WORLD_UNITS)


func _observe_balls(host_time_msec: int) -> void:
	var height := floor_depth()
	var width := world_size().x
	for ball: TiltShift3DBall in _balls.duplicate():
		if ball.resolved:
			continue
		var previous := ball.previous_position
		var current := to_arena(ball.position)
		if previous.y < height and current.y >= height:
			var fraction := (height - previous.y) / (current.y - previous.y)
			var crossing := lerpf(previous.x, current.x, fraction)
			# A continuous basket row has shared rims, not gaps. Its center decides which
			# basket catches a straddling ball; gapped presets still require a full fit.
			var fit_radius := 0.0 if _floor.is_empty() else ball.radius
			var tolerance := TiltShift3DBasketPreset.REFLECTION_TOLERANCE * WORLD_UNITS
			for basket: TiltShift3DBasketOpening in _snapshot.basket_preset.openings:
				var left := (basket.center - basket.width * 0.5) * WORLD_UNITS
				var right := (basket.center + basket.width * 0.5) * WORLD_UNITS
				if crossing - fit_radius >= left - tolerance \
						and crossing + fit_radius <= right + tolerance:
					_resolve(ball, basket.basket_id, host_time_msec)
					break
		if ball.resolved:
			continue
		var top := visible_top - (_profile.spawn_height + 0.1) * WORLD_UNITS - height
		if (
			not current.is_finite() or current.x < -ball.radius or current.x > width + ball.radius \
					or current.y > height + ball.radius * 2.0
			or current.y < minf(-height, top)
		):
			_resolve(ball, "", host_time_msec)
		else:
			ball.previous_position = current


func _resolve(ball: TiltShift3DBall, basket_id: String, host_time_msec: int) -> void:
	if ball.resolved:
		return
	ball.resolved = true
	if basket_id.is_empty():
		controller.discard_ball(ball.handle, host_time_msec)
	else:
		controller.resolve_ball(ball.handle, basket_id, host_time_msec)
	_balls.erase(ball)
	_retire_body(ball)
	ball_removed.emit(ball.handle, basket_id)


func _clear_balls() -> void:
	for ball: TiltShift3DBall in _balls:
		ball.resolved = true
		_retire_body(ball)
	_balls.clear()


func _retire_body(body: Node) -> void:
	if body is CollisionObject3D:
		body.set("collision_layer", 0)
		body.set("collision_mask", 0)
	body.queue_free()


## A static box centred on [param center], measured in arena coordinates.
func _wall(center: Vector2, size: Vector2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = to_world(center)
	body.collision_layer = 2
	body.collision_mask = 1
	var material := PhysicsMaterial.new()
	material.friction = _profile.paddle_friction
	material.rough = true
	body.physics_material_override = material
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y, WALL_DEPTH)
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body


func set_visible_top(value: float) -> void:
	if not is_finite(value) or is_equal_approx(value, visible_top):
		return
	visible_top = value
	if _snapshot != null:
		for body: StaticBody3D in _walls:
			_retire_body(body)
		_walls.clear()
		_build_walls()


func _build_walls() -> void:
	var width := world_size().x
	var height := floor_depth()
	var top := minf(0, visible_top - (_profile.spawn_height + 0.1) * WORLD_UNITS)
	for horizontal: float in [-WALL_THICKNESS * 0.5, width + WALL_THICKNESS * 0.5]:
		_walls.append(
			_wall(
				Vector2(horizontal, (height + top) * 0.5),
				Vector2(WALL_THICKNESS, height - top + WALL_THICKNESS),
			)
		)


func _build_floor() -> void:
	for body: StaticBody3D in _floor:
		_retire_body(body)
	_floor.clear()
	var openings := _snapshot.basket_preset.openings.duplicate()
	openings.sort_custom(
		func(a: TiltShift3DBasketOpening, b: TiltShift3DBasketOpening) -> bool:
			return a.center < b.center,
	)
	var previous := 0.0
	var height := floor_depth()
	for basket: TiltShift3DBasketOpening in openings:
		var left := (basket.center - basket.width * 0.5) * WORLD_UNITS
		_floor_segment(previous, left, height)
		previous = (basket.center + basket.width * 0.5) * WORLD_UNITS
	_floor_segment(previous, world_size().x, height)


func _floor_segment(left: float, right: float, height: float) -> void:
	if right - left <= TiltShift3DBasketPreset.REFLECTION_TOLERANCE * WORLD_UNITS:
		return
	_floor.append(
		_wall(
			Vector2((left + right) * 0.5, height + WALL_THICKNESS * 0.5),
			Vector2(right - left, WALL_THICKNESS),
		)
	)
