class_name BubblesPlayerBubble
extends CharacterBody2D
## One host-simulated player body. Controller events are the only gameplay input.

const CHARACTER_MAX_SCALE := 0.55
const CHARACTER_OUTER_RADIUS := 75.0
const BLINK_PERIOD_MSEC := 100

@onready var _collider: CollisionShape2D = $CollisionShape2D
@onready var _visual: BubblesPlayerVisual = $BubbleVisual
@onready var _character: ShapeCharacter = $ShapeCharacter
@onready var _name_label: Label = $PlayerName

var player_id := ""
var tuning: BubblesTuning
var _controller: BubblesRoundController
var _player_color := Color("598df2")
var _score := 0
var _spin_until_msec := -1
var _invulnerable_until_msec := -1
var _pop_at_msec := -1
var _visual_host_msec := 0
var _active := false
var _left := false
var _connected := true
var _swipe_at_msec := -1
var _swipe_direction := Vector2.ZERO
var _spin_started_msec := -1
var _spin_release_angle := 0.0
var _burst_radius := 48.0
var _charge_progress := 0.0
var _charge_last_msec := -1
var _blink_next_msec := 0
var _blink_until_msec := -1
var _blink_index := 0


func _ready() -> void:
	set_physics_process(false)
	# PackedScene subresources can be shared across instances. Each body owns its radius.
	_collider.shape = _collider.shape.duplicate()


func configure(id: String, display_name: String, color: Color, selected_tuning: BubblesTuning) -> void:
	assert(not id.is_empty() and selected_tuning != null)
	player_id = id
	tuning = selected_tuning
	_player_color = color
	_character.player_color = color
	_name_label.text = display_name
	_blink_next_msec = roundi(selected_tuning.character_blink_interval_seconds * 1000.0 * (0.7 + float(abs(id.hash()) % 7) * 0.1))
	_refresh_visual(0)


func bind_controller(controller: BubblesRoundController) -> void:
	assert(controller != null and not player_id.is_empty())
	_controller = controller
	_controller.arena_event_requested.connect(_on_arena_event)
	_controller.personal_state_changed.connect(_on_personal_state)
	_controller.charge_visual_changed.connect(_on_charge_visual_changed)
	_controller.phase_changed.connect(_on_phase_changed)
	apply_authoritative_snapshot(_controller.personal_snapshot(player_id))
	set_host_phase(_controller.phase_name())


func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or snapshot.get("player_id", "") != player_id:
		return
	_score = maxi(0, int(snapshot.get("score", 0)))
	_spin_until_msec = int(snapshot.get("spin_until_msec", -1))
	_invulnerable_until_msec = int(snapshot.get("invulnerable_until_msec", -1))
	_pop_at_msec = int(snapshot.get("last_pop_msec", _pop_at_msec))
	_visual_host_msec = int(snapshot.get("host_time_msec", _visual_host_msec))
	_connected = bool(snapshot.get("connected", true))
	_left = bool(snapshot.get("left", false))
	if _left:
		_active = false
		visible = false
	if not _connected or snapshot.get("phase", &"idle") != &"active":
		_charge_progress = 0.0
	_refresh_visual(_visual_host_msec)


func set_host_phase(phase_name: StringName) -> void:
	_active = phase_name == &"active" and not _left
	_collider.disabled = not _active
	if not _active:
		velocity = Vector2.ZERO
		_charge_progress = 0.0


## Called once per fixed host step by BubblesPlayerArena; bounds are provided by its scene.
func simulate_step(delta: float, bounds: Rect2, host_time_msec: int) -> void:
	if tuning == null or not is_finite(delta) or delta < 0.0 or delta > 0.05 or host_time_msec < 0:
		return
	_visual_host_msec = host_time_msec
	if _charge_progress > 0.0 and host_time_msec - _charge_last_msec > BubblesProtocol.CHARGE_TIMEOUT_MSEC:
		_charge_progress = 0.0
	_refresh_visual(host_time_msec)
	if not _active or not bounds.has_area():
		return
	velocity *= exp(-tuning.water_drag * delta)
	limit_speed()
	global_position += velocity * delta
	_bounce_inside(bounds)


func request_jellyfish_collection(host_time_msec: int) -> Dictionary:
	if _controller == null:
		return {"accepted": false, "code": &"unbound"}
	return _controller.record_jellyfish_capture(player_id, host_time_msec)


func request_puffer_pop(host_time_msec: int) -> Dictionary:
	if _controller == null:
		return {"accepted": false, "code": &"unbound"}
	return _controller.pop_player(player_id, host_time_msec)


func is_spinning(host_time_msec: int) -> bool:
	return _active and host_time_msec >= 0 and host_time_msec < _spin_until_msec


func is_invulnerable(host_time_msec: int) -> bool:
	return _active and host_time_msec >= _pop_at_msec and _pop_at_msec >= 0 and host_time_msec < _invulnerable_until_msec


func is_simulated() -> bool:
	return _active


func has_live_connection() -> bool:
	return _connected


func score() -> int:
	return _score


func bubble_radius() -> float:
	return minf(tuning.max_radius, tuning.starting_radius + float(_score) * tuning.radius_per_jellyfish)


func collision_radius() -> float:
	return (_collider.shape as CircleShape2D).radius


func effective_mass() -> float:
	var grown := maxf(0.0, (bubble_radius() - tuning.starting_radius) / tuning.radius_per_jellyfish)
	return 1.0 + grown * tuning.mass_growth_per_jellyfish


func effective_max_speed() -> float:
	var grown := maxf(0.0, (bubble_radius() - tuning.starting_radius) / tuning.radius_per_jellyfish)
	return tuning.max_player_speed / (1.0 + grown * tuning.speed_reduction_per_jellyfish)


func limit_speed() -> void:
	velocity = velocity.limit_length(effective_max_speed())


func _bounce_inside(bounds: Rect2) -> void:
	var radius := collision_radius()
	var radius_x := radius * global_transform.x.length()
	var radius_y := radius * global_transform.y.length()
	var low := bounds.position + Vector2(radius_x, radius_y)
	var high := bounds.end - Vector2(radius_x, radius_y)
	if low.x > high.x:
		global_position.x = bounds.get_center().x
		velocity.x = 0.0
	else:
		if global_position.x < low.x:
			global_position.x = low.x
			velocity.x = absf(velocity.x) * tuning.wall_bounciness
		elif global_position.x > high.x:
			global_position.x = high.x
			velocity.x = -absf(velocity.x) * tuning.wall_bounciness
	if low.y > high.y:
		global_position.y = bounds.get_center().y
		velocity.y = 0.0
	else:
		if global_position.y < low.y:
			global_position.y = low.y
			velocity.y = absf(velocity.y) * tuning.wall_bounciness
		elif global_position.y > high.y:
			global_position.y = high.y
			velocity.y = -absf(velocity.y) * tuning.wall_bounciness


func _refresh_visual(host_time_msec: int) -> void:
	if tuning == null or _visual == null:
		return
	var reform_scale := 1.0
	if _pop_at_msec >= 0:
		var age := float(maxi(0, host_time_msec - _pop_at_msec)) / 1000.0
		reform_scale = clampf(age / tuning.bubble_reform_seconds, 0.08, 1.0)
	var rendered_radius := bubble_radius() * reform_scale
	var burst := -1.0
	if _pop_at_msec >= 0:
		var pop_age := float(host_time_msec - _pop_at_msec) / 1000.0
		if pop_age >= 0.0 and pop_age < tuning.burst_seconds:
			burst = pop_age / tuning.burst_seconds
			rendered_radius = _burst_radius
	(_collider.shape as CircleShape2D).radius = maxf(1.0, bubble_radius() * reform_scale)
	var white_blink := is_invulnerable(host_time_msec) and (host_time_msec / BLINK_PERIOD_MSEC) % 2 == 0
	_character.player_color = Color.WHITE if white_blink else _player_color
	_character.scale = Vector2.ONE * minf(CHARACTER_MAX_SCALE, bubble_radius() * 0.82 / CHARACTER_OUTER_RADIUS)
	_animate_character(host_time_msec, burst)
	var swipe_age := float(host_time_msec - _swipe_at_msec) / 1000.0 if _swipe_at_msec >= 0 else 999.0
	var pull := _swipe_direction * tuning.swipe_pull_strength * sin(PI * clampf(swipe_age / tuning.swipe_reaction_seconds, 0.0, 1.0))
	var surface_angle := float(host_time_msec - _spin_started_msec) / 1000.0 * TAU * tuning.spin_surface_turns_per_second if is_spinning(host_time_msec) and _spin_started_msec >= 0 else 0.0
	_visual.update_appearance(rendered_radius, mini(_score, tuning.captured_visual_cap), is_spinning(host_time_msec),
		white_blink, pull, surface_angle, burst, tuning.decorative_particle_count)
	_name_label.position = Vector2(-110.0, -rendered_radius - 42.0)


func _animate_character(host_time_msec: int, burst: float) -> void:
	_character.visible = burst < 0.0
	if not _character.visible:
		return
	var seconds := float(host_time_msec) / 1000.0
	var bob := sin(seconds * 2.2 + float(abs(player_id.hash()) % 10)) * tuning.character_float_pixels
	var swipe_age := float(host_time_msec - _swipe_at_msec) / 1000.0 if _swipe_at_msec >= 0 else 999.0
	var push := sin(PI * clampf(swipe_age / tuning.swipe_reaction_seconds, 0.0, 1.0))
	_character.position = Vector2(0.0, bob) + _swipe_direction * push * tuning.swipe_character_push_pixels
	var turn := 0.0
	if _charge_progress > 0.0:
		turn = seconds * TAU * tuning.charge_turns_per_second * (0.5 + _charge_progress * 0.5)
	elif _spin_started_msec >= 0:
		var release_age := float(host_time_msec - _spin_started_msec) / 1000.0
		turn = _spin_release_angle * (1.0 - smoothstep(0.0, tuning.spin_release_seconds, release_age))
	var body := _character.get_node("Body") as Sprite2D
	var face := _character.get_node("Face") as Sprite2D
	var left_hand := _character.get_node("LeftHand") as Sprite2D
	var right_hand := _character.get_node("RightHand") as Sprite2D
	var left_foot := _character.get_node("LeftFoot") as Sprite2D
	var right_foot := _character.get_node("RightFoot") as Sprite2D
	body.rotation = turn + sin(seconds * 1.7) * 0.05
	face.rotation = 0.0
	face.position = Vector2(0, -5) + _swipe_direction * push * 3.0
	left_hand.position = Vector2(-52, -4).rotated(turn) + _swipe_direction * push * 9.0
	right_hand.position = Vector2(52, -4).rotated(turn) + _swipe_direction * push * 9.0
	left_foot.position = Vector2(-23, 62).rotated(turn)
	right_foot.position = Vector2(23, 62).rotated(turn)
	if host_time_msec >= _blink_next_msec:
		_blink_until_msec = host_time_msec + 140
		_blink_index += 1
		_blink_next_msec = host_time_msec + roundi(tuning.character_blink_interval_seconds * 1000.0 * (0.72 + float(_blink_index % 5) * 0.14))
	face.texture = CharacterExpression.FACES[&"blink"] if host_time_msec < _blink_until_msec else CharacterExpression.FACES[&"neutral"]


func _on_arena_event(kind: StringName, id: String, data: Dictionary) -> void:
	if id != player_id:
		return
	match kind:
		&"swipe":
			if not _active:
				return
			var direction: Vector2 = data.get("direction", Vector2.ZERO)
			var strength := float(data.get("strength", 0.0))
			if direction.length_squared() > 0.0 and is_finite(strength):
				velocity += direction.normalized() * strength / effective_mass()
				limit_speed()
				_swipe_direction = direction.normalized()
				_swipe_at_msec = _visual_host_msec
		&"spin":
			_spin_started_msec = int(data.get("started_msec", _visual_host_msec))
			_spin_release_angle = fposmod(float(_spin_started_msec) / 1000.0 * TAU * tuning.charge_turns_per_second * (0.5 + _charge_progress * 0.5), TAU)
			_charge_progress = 0.0
		&"pop":
			_burst_radius = _visual.radius
			_pop_at_msec = int(data.get("at_msec", -1))
			_visual_host_msec = _pop_at_msec
			velocity = Vector2.ZERO
			_charge_progress = 0.0
			_refresh_visual(_pop_at_msec)
		&"player_left":
			_active = false
			visible = false
			_collider.disabled = true
			_charge_progress = 0.0


func _on_charge_visual_changed(id: String, progress: float) -> void:
	if id == player_id and _active and _connected:
		_charge_progress = clampf(progress, 0.0, 1.0)
		_charge_last_msec = _visual_host_msec


func _on_personal_state(id: String, snapshot: Dictionary) -> void:
	if id == player_id:
		apply_authoritative_snapshot(snapshot)


func _on_phase_changed(phase_name: StringName, _snapshot: Dictionary) -> void:
	set_host_phase(phase_name)
