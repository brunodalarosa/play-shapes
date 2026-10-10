class_name TiltShiftArena
extends Node2D
## Shared gameplay/preview physics. The caller supplies content, roster and host clock.

signal ball_spawned(ball: TiltShiftBall)
signal ball_removed(handle: TiltShiftState.BallHandle, basket_id: String)
signal stopped

const WORLD_UNITS := 1000.0
const WALL_THICKNESS := 20.0

var controller: TiltShiftShiftController
var clock: Callable = Time.get_ticks_msec
var spawned_count: int = 0
var positive_spawned_count: int = 0
var negative_spawned_count: int = 0
var peak_live_balls: int = 0
var position_seed_used: int = 0
var last_step_usec: int = 0
var _profile: TiltShiftPhysicsTuning
var _snapshot: TiltShiftState.Snapshot
var _paddles: Array[TiltShiftPaddleBody] = []
var _balls: Array[TiltShiftBall] = []
var _floor: Array[StaticBody2D] = []
var _walls: Array[StaticBody2D] = []
var _schedule := PackedInt32Array()
var _negative_schedule := PackedInt32Array()
var _next_negative_delivery: int = 0
var _round_duration: int = 0
var _next_delivery: int = 0
var _active: bool = false
var visible_top: float = 0.0
var _delivery_duration: int = 0
var _positions := RandomNumberGenerator.new()
var placeholder_visible := true:
	set(value):
		placeholder_visible = value
		for paddle: TiltShiftPaddleBody in _paddles:
			paddle.placeholder_visible = value
		for ball: TiltShiftBall in _balls:
			ball.placeholder_visible = value
		queue_redraw()


func start_shift(
	selected: TiltShiftTuning,
	players: Array[TiltShiftState.Player],
	wait_for_initial_motion: bool = false,
) -> TiltShiftState.Result:
	if selected == null:
		return TiltShiftState.rejected(&"invalid_tuning")
	var errors := selected.validation_errors()
	if not errors.is_empty():
		return TiltShiftState.rejected(&"invalid_tuning", errors)
	if controller != null and controller.snapshot().phase not in [&"idle", &"finished"]:
		return TiltShiftState.rejected(&"shift_already_running")
	stop()
	controller = TiltShiftShiftController.new()
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


func start_next_round() -> TiltShiftState.Result:
	if controller == null or _active:
		return TiltShiftState.rejected(&"next_round_unavailable")
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
		controller.queue_free()
	controller = null
	_snapshot = null
	_profile = null
	_schedule.clear()
	_negative_schedule.clear()
	queue_redraw()


func live_balls() -> Array[TiltShiftBall]:
	return _balls.duplicate()


func paddle_bodies() -> Array[TiltShiftPaddleBody]:
	return _paddles.duplicate()


func floor_bodies() -> Array[StaticBody2D]:
	return _floor.duplicate()


## Signed swept clearances, in arena units. Negative values are diagnostics, not auto edits.
func swept_clearances() -> PackedFloat32Array:
	var values := PackedFloat32Array()
	if _snapshot == null:
		return values
	for index: int in _paddles.size():
		var radius := _paddles[index].size.length() * 0.5 / WORLD_UNITS
		var position := _paddles[index].position / WORLD_UNITS
		var size := _snapshot.paddle_layout.arena_size
		values.append(minf(minf(position.x, size.x - position.x), position.y) - radius)
		values.append(size.y - position.y - radius)
		for other: int in range(index + 1, _paddles.size()):
			var distance := position.distance_to(_paddles[other].position / WORLD_UNITS)
			values.append(distance - radius - _paddles[other].size.length() * 0.5 / WORLD_UNITS)
	return values


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
	for paddle: TiltShiftPaddleBody in _paddles:
		paddle.advance_pose(delta, _active)
	if not _active:
		return
	_observe_balls(host_time_msec)
	if not _active or _snapshot.round_token != round_token:
		return
	var elapsed := host_time_msec - _snapshot.started_at_msec
	var weight := 0.0
	if _delivery_duration > 0 and elapsed < _delivery_duration:
		weight = TiltShiftDelivery.intensity(
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
	var negative_weight := TiltShiftDelivery.intensity(
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


func _on_round_prepared(snapshot: TiltShiftState.Snapshot) -> void:
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
	for paddle: TiltShiftPaddle in snapshot.paddle_layout.paddles:
		var body := TiltShiftPaddleBody.new()
		body.configure(
			paddle,
			_profile,
			WORLD_UNITS,
			snapshot.paddle_layout,
			snapshot.auto_direction,
		)
		body.placeholder_visible = placeholder_visible
		add_child(body)
		_paddles.append(body)
	_build_walls()
	_build_floor()
	for player: TiltShiftState.Player in snapshot.players:
		_on_angle_changed(player)
	queue_redraw()


func _on_round_started(snapshot: TiltShiftState.Snapshot) -> void:
	_clear_balls()
	_snapshot = snapshot
	_profile = snapshot.physics
	if snapshot.round_number == 1 and not snapshot.reworked:
		_positions.randomize()
		if _profile.use_position_seed:
			_positions.seed = _profile.position_seed
		position_seed_used = _positions.seed
		peak_live_balls = 0
		for paddle: TiltShiftPaddle in snapshot.paddle_layout.paddles:
			var body := TiltShiftPaddleBody.new()
			body.configure(paddle, _profile, WORLD_UNITS)
			body.placeholder_visible = placeholder_visible
			add_child(body)
			_paddles.append(body)
		_build_walls()
	for player: TiltShiftState.Player in snapshot.players:
		_on_angle_changed(player)
	if not snapshot.reworked:
		_build_floor()
	_delivery_duration = snapshot.deadline_msec - snapshot.started_at_msec \
			- roundi(_profile.delivery_cutoff_seconds * 1000.0)
	_schedule = TiltShiftDelivery.schedule(
		_profile.ball_count,
		_profile.delivery_curve,
		_delivery_duration,
	)
	_next_delivery = 0
	_round_duration = snapshot.deadline_msec - snapshot.started_at_msec
	_negative_schedule = TiltShiftDelivery.schedule(
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
	queue_redraw()


func _on_round_ended(_state: TiltShiftState.Snapshot) -> void:
	_active = false
	_clear_balls()


func _on_angle_changed(player: TiltShiftState.Player) -> void:
	for paddle: TiltShiftPaddleBody in _paddles:
		if player.paddle_ids.has(paddle.paddle_id):
			paddle.target_angle = player.angle_radians


func _spawn(host_time_msec: int, score_value: int = 1) -> TiltShiftBall:
	if not _active or score_value not in [-1, 1]:
		return null
	if score_value > 0 and positive_spawned_count >= _profile.ball_count:
		return null
	if score_value < 0 and negative_spawned_count >= _profile.negative_ball_count:
		return null
	var registration := controller.register_ball(_snapshot.round_token, host_time_msec, score_value)
	if not registration.accepted:
		return null
	var ball := TiltShiftBall.new()
	ball.handle = registration.ball
	ball.score_value = score_value
	ball.configure(_profile, WORLD_UNITS)
	ball.placeholder_visible = placeholder_visible
	var center := _snapshot.paddle_layout.arena_size.x * 0.5
	var horizontal := _positions.randf_range(-_profile.spawn_half_width, _profile.spawn_half_width)
	var spawn_y := _profile.ball_radius * WORLD_UNITS
	if _snapshot.reworked:
		spawn_y = visible_top - (_profile.spawn_height + _profile.ball_radius) * WORLD_UNITS
	ball.position = Vector2((center + horizontal) * WORLD_UNITS, spawn_y)
	ball.previous_position = ball.position
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


func _observe_balls(host_time_msec: int) -> void:
	var height := _snapshot.paddle_layout.arena_size.y * WORLD_UNITS
	var width := _snapshot.paddle_layout.arena_size.x * WORLD_UNITS
	for ball: TiltShiftBall in _balls.duplicate():
		if ball.resolved:
			continue
		var previous := ball.previous_position
		var current := ball.position
		if previous.y < height and current.y >= height:
			var fraction := (height - previous.y) / (current.y - previous.y)
			var crossing := lerpf(previous.x, current.x, fraction)
			# A continuous basket row has shared rims, not gaps. Its center decides which
			# basket catches a straddling ball; gapped presets still require a full fit.
			var fit_radius := 0.0 if _floor.is_empty() else ball.radius
			var tolerance := TiltShiftBasketPreset.REFLECTION_TOLERANCE * WORLD_UNITS
			for basket: TiltShiftBasketOpening in _snapshot.basket_preset.openings:
				var left := (basket.center - basket.width * 0.5) * WORLD_UNITS
				var right := (basket.center + basket.width * 0.5) * WORLD_UNITS
				if crossing - fit_radius >= left - tolerance \
						and crossing + fit_radius <= right + tolerance:
					_resolve(ball, basket.basket_id, host_time_msec)
					break
		if ball.resolved:
			continue
		if (
			not current.is_finite() or current.x < -ball.radius or current.x > width + ball.radius \
					or current.y > height + ball.radius * 2.0
			or current.y
			< minf(-height, visible_top - (_profile.spawn_height + 0.1) * WORLD_UNITS - height)
		):
			_resolve(ball, "", host_time_msec)
		else:
			ball.previous_position = current


func _resolve(ball: TiltShiftBall, basket_id: String, host_time_msec: int) -> void:
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
	for ball: TiltShiftBall in _balls:
		ball.resolved = true
		_retire_body(ball)
	_balls.clear()


func _retire_body(body: Node) -> void:
	if body is CollisionObject2D:
		body.set("collision_layer", 0)
		body.set("collision_mask", 0)
	body.queue_free()


func _wall(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 2
	body.collision_mask = 1
	var material := PhysicsMaterial.new()
	material.friction = _profile.paddle_friction
	material.rough = true
	body.physics_material_override = material
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return body


func set_visible_top(value: float) -> void:
	if not is_finite(value) or is_equal_approx(value, visible_top):
		return
	visible_top = value
	if _snapshot != null:
		for body: StaticBody2D in _walls:
			_retire_body(body)
		_walls.clear()
		_build_walls()


func _build_walls() -> void:
	var size := _snapshot.paddle_layout.arena_size * WORLD_UNITS
	var top := minf(0, visible_top - (_profile.spawn_height + 0.1) * WORLD_UNITS)
	for horizontal: float in [-WALL_THICKNESS * 0.5, size.x + WALL_THICKNESS * 0.5]:
		_walls.append(
			_wall(
				Vector2(horizontal, (size.y + top) * 0.5),
				Vector2(WALL_THICKNESS, size.y - top + WALL_THICKNESS),
			)
		)


func _build_floor() -> void:
	for body: StaticBody2D in _floor:
		_retire_body(body)
	_floor.clear()
	var openings := _snapshot.basket_preset.openings.duplicate()
	openings.sort_custom(
		func(a: TiltShiftBasketOpening, b: TiltShiftBasketOpening) -> bool:
			return a.center < b.center,
	)
	var previous := 0.0
	var height := _snapshot.paddle_layout.arena_size.y * WORLD_UNITS
	for basket: TiltShiftBasketOpening in openings:
		var left := (basket.center - basket.width * 0.5) * WORLD_UNITS
		_floor_segment(previous, left, height)
		previous = (basket.center + basket.width * 0.5) * WORLD_UNITS
	_floor_segment(previous, _snapshot.paddle_layout.arena_size.x * WORLD_UNITS, height)


func _floor_segment(left: float, right: float, height: float) -> void:
	if right - left <= TiltShiftBasketPreset.REFLECTION_TOLERANCE * WORLD_UNITS:
		return
	_floor.append(
		_wall(
			Vector2((left + right) * 0.5, height + WALL_THICKNESS * 0.5),
			Vector2(right - left, WALL_THICKNESS),
		)
	)


func _draw() -> void:
	if _snapshot == null or not placeholder_visible:
		return
	var size := _snapshot.paddle_layout.arena_size * WORLD_UNITS
	draw_rect(Rect2(Vector2.ZERO, size), Color("ede5d5"))
	for basket: TiltShiftBasketOpening in _snapshot.basket_preset.openings:
		var colors: Array[Color] = [Color("ec9644"), Color("598df2"), Color("78684d")]
		var position := Vector2(basket.center - basket.width * 0.5, size.y / WORLD_UNITS)
		draw_rect(
			Rect2(position * WORLD_UNITS, Vector2(basket.width * WORLD_UNITS, 24)),
			colors[basket.team],
		)
