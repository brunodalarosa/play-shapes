class_name Bubbles3DPlayerBubble
extends RigidBody3D
## One player's bubble: a plane-locked Jolt body whose sphere always matches the drawn radius,
## with the player's Cubio and caught jellyfishes floating inside. Only controller events move
## it; contacts with other bubbles and the walls are left to the physics engine.

signal bumped(other_id: String)

const CUBIO_SCENE: PackedScene = preload("res://characters/cubio_3d.tscn")
const BLINK_PERIOD_MSEC := 100
const PHONE_VISUAL_SEND_INTERVAL_MSEC := 50
## Caught jellyfishes are drawn this share of a free jellyfish's width.
const CAUGHT_WIDTH_SHARE := 0.6

var player_id := ""
var tuning: Bubbles3DTuning
var shell: BubbleShell3D
var cubio: Cubio3D
var caught: Bubbles3DJellyfishSwarm
var _controller: Bubbles3DRoundController
var _collider: CollisionShape3D
var _sphere: SphereShape3D
var _material: PhysicsMaterial
var _hand_wobble: Bubbles3DHandWobble
var _player_color := Color("1e88e5")
var _score := 0
var _invulnerable_until_msec := -1
var _pop_at_msec := -1
var _visual_host_msec := 0
var _active := false
var _left := false
var _connected := true
var _swipe_at_msec := -1
var _swipe_direction := Vector2.ZERO
var _live_drag_target := Vector2.ZERO
var _live_drag_display := Vector2.ZERO
var _live_drag_started_msec := -1
var _drag_last_msec := -1
var _phone_visual_sent_msec := -1
var _bob_phase := 0.0
var _lean := 0.0


func _init() -> void:
	can_sleep = false
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	contact_monitor = true
	max_contacts_reported = 4
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_material = PhysicsMaterial.new()
	_material.friction = 0.0
	physics_material_override = _material
	_sphere = SphereShape3D.new()
	_collider = CollisionShape3D.new()
	_collider.name = "Collider"
	_collider.shape = _sphere
	_collider.disabled = true
	add_child(_collider)
	shell = BubbleShell3D.new()
	shell.name = "Shell"
	add_child(shell)
	cubio = CUBIO_SCENE.instantiate() as Cubio3D
	cubio.name = "Cubio"
	add_child(cubio)
	caught = Bubbles3DJellyfishSwarm.new()
	caught.name = "Caught"
	add_child(caught)
	PlaneLock3D.lock(self)
	body_entered.connect(_on_body_entered)


func _ready() -> void:
	cubio.nameplate.visible = false
	var skeletons := cubio.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_hand_wobble = Bubbles3DHandWobble.new()
		skeletons[0].add_child(_hand_wobble)


func configure(
	id: String,
	color: Color,
	selected_tuning: Bubbles3DTuning,
	collision_layer_bits: int,
	collision_mask_bits: int,
) -> void:
	assert(not id.is_empty() and selected_tuning != null)
	player_id = id
	tuning = selected_tuning
	collision_layer = collision_layer_bits
	collision_mask = collision_mask_bits
	# Godot adds the two bodies' bounce, so each bubble carries half of a bump's rebound.
	_material.bounce = tuning.bump_bounciness * 0.5
	_player_color = color
	cubio.player_color = color
	caught.setup(tuning.captured_visual_cap)
	shell.droplet_count = tuning.pop_droplet_count
	shell.droplet_seconds = tuning.burst_seconds
	_bob_phase = float(absi(id.hash()) % 1000) / 1000.0 * TAU
	_refresh_visual(0)


func bind_controller(controller: Bubbles3DRoundController) -> void:
	assert(controller != null and not player_id.is_empty())
	_controller = controller
	_controller.arena_event_requested.connect(_on_arena_event)
	_controller.personal_state_changed.connect(_on_personal_state)
	_controller.drag_visual_changed.connect(_on_drag_visual_changed)
	_controller.phase_changed.connect(_on_phase_changed)
	apply_authoritative_snapshot(_controller.personal_snapshot(player_id))
	set_host_phase(_controller.phase_name())


func apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or snapshot.get("player_id", "") != player_id:
		return
	_score = maxi(0, int(snapshot.get("score", 0)))
	_invulnerable_until_msec = int(snapshot.get("invulnerable_until_msec", -1))
	_pop_at_msec = int(snapshot.get("last_pop_msec", _pop_at_msec))
	_visual_host_msec = maxi(_visual_host_msec, int(snapshot.get("host_time_msec", 0)))
	_connected = bool(snapshot.get("connected", true))
	_left = bool(snapshot.get("left", false))
	if _left:
		_leave()
	if not _connected or snapshot.get("phase", &"idle") != &"active":
		_live_drag_target = Vector2.ZERO
	_refresh_visual(_visual_host_msec)


## Gameplay contacts happen only while the round is active; otherwise the body follows its
## owner's position, as during the entrance.
func set_host_phase(phase_name: StringName) -> void:
	_active = phase_name == &"active" and not _left
	_collider.disabled = not _active
	freeze = not _active
	if not _active:
		linear_velocity = Vector3.ZERO
		_live_drag_target = Vector2.ZERO


## Called once per physics frame by the arena with the host clock.
func simulate_step(delta: float, host_time_msec: int) -> void:
	if tuning == null or not is_finite(delta) or delta < 0.0 or delta > 0.1:
		return
	_visual_host_msec = maxi(_visual_host_msec, host_time_msec)
	var hold_limit := roundi(tuning.swipe_max_hold_seconds * 1000.0)
	var drag_stale := (
		_live_drag_started_msec >= 0 and host_time_msec - _live_drag_started_msec > hold_limit
	)
	if drag_stale or (_drag_last_msec >= 0 and host_time_msec - _drag_last_msec > 1200):
		_live_drag_target = Vector2.ZERO
	_live_drag_display = _live_drag_display.lerp(
		_live_drag_target,
		1.0 - exp(-delta / tuning.live_drag_response_seconds),
	)
	var speed_share := plane_velocity() / maxf(0.01, tuning.max_speed_for(bubble_radius()))
	_lean = lerpf(_lean, clampf(speed_share.x, -1.0, 1.0), 1.0 - exp(-delta * 6.0))
	_refresh_visual(host_time_msec)
	if (
		_controller != null
		and host_time_msec - _phone_visual_sent_msec >= PHONE_VISUAL_SEND_INTERVAL_MSEC
	):
		_phone_visual_sent_msec = host_time_msec
		_controller.personal_visual_changed.emit(player_id, phone_visual_state(host_time_msec))


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if tuning == null:
		return
	var velocity := state.linear_velocity * exp(-tuning.water_drag * state.step)
	velocity = velocity.limit_length(tuning.max_speed_for(bubble_radius()))
	velocity.z = 0.0
	state.linear_velocity = velocity


func request_jellyfish_collection(host_time_msec: int) -> Dictionary:
	if _controller == null:
		return { "accepted": false, "code": &"unbound" }
	return _controller.record_jellyfish_capture(player_id, host_time_msec)


func request_puffer_pop(host_time_msec: int) -> Dictionary:
	if _controller == null:
		return { "accepted": false, "code": &"unbound" }
	return _controller.pop_player(player_id, host_time_msec)


func is_invulnerable(host_time_msec: int) -> bool:
	return (
		_active and _pop_at_msec >= 0 and host_time_msec >= _pop_at_msec
		and host_time_msec < _invulnerable_until_msec
	)


func is_simulated() -> bool:
	return _active


func has_live_connection() -> bool:
	return _connected


func score() -> int:
	return _score


## The radius the score earns, which a re-forming bubble grows back to.
func bubble_radius() -> float:
	return tuning.radius_for(_score)


func collision_radius() -> float:
	return _sphere.radius


func plane_position() -> Vector2:
	return PlaneLock3D.plane_point(global_position)


func plane_velocity() -> Vector2:
	return Vector2(linear_velocity.x, linear_velocity.y)


## What the player's phone needs to draw this bubble as the shared screen shows it.
func phone_visual_state(host_time_msec: int) -> Dictionary:
	var stretch := shell.stretch
	var speed_share := plane_velocity() / maxf(0.01, tuning.max_speed_for(bubble_radius()))
	return {
		"host_time_msec": host_time_msec,
		"radius": snappedf(shell.shown_radius(), 0.001),
		"stretch": [snappedf(stretch.x, 0.001), snappedf(stretch.y, 0.001)],
		"velocity": [snappedf(speed_share.x, 0.01), snappedf(speed_share.y, 0.01)],
		"white": is_invulnerable(host_time_msec),
		"pop_age_msec": host_time_msec - _pop_at_msec if _pop_at_msec >= 0 else -1,
		"caught": caught.visible_count(),
	}


func _refresh_visual(host_time_msec: int) -> void:
	if tuning == null:
		return
	var radius := bubble_radius()
	var reform := 1.0
	if _pop_at_msec >= 0:
		var age := float(maxi(0, host_time_msec - _pop_at_msec)) / 1000.0
		reform = clampf(age / tuning.bubble_reform_seconds, 0.08, 1.0)
	_sphere.radius = maxf(0.01, radius * reform)
	shell.radius = radius
	mass = tuning.mass_for(radius)

	var swipe_age := (
		float(host_time_msec - _swipe_at_msec) / 1000.0 if _swipe_at_msec >= 0 else 999.0
	)
	var push := sin(PI * clampf(swipe_age / tuning.swipe_reaction_seconds, 0.0, 1.0))
	shell.stretch = (
		_swipe_direction * tuning.swipe_pull_strength * push
		+ _live_drag_display * tuning.live_drag_pull_strength
	)

	var white := is_invulnerable(host_time_msec) and (host_time_msec / BLINK_PERIOD_MSEC) % 2 == 0
	cubio.player_color = Color.WHITE if white else _player_color
	var height := tuning.character_height_for(radius)
	var seconds := float(host_time_msec) / 1000.0
	var bob := sin(seconds * 2.2 + _bob_phase) * tuning.character_bob
	var offset := _swipe_direction * push * tuning.swipe_character_push
	cubio.scale = Vector3.ONE * height
	cubio.position = Vector3(offset.x, -height * 0.5 + bob + offset.y, 0.0)
	cubio.rotation.z = -deg_to_rad(tuning.character_lean_degrees) * _lean
	if _hand_wobble != null:
		_hand_wobble.amount = tuning.character_hand_wobble * Cubio3D.SOURCE_HEIGHT / height
	_place_caught(radius, seconds)


## Caught jellyfishes orbit slowly in a ring around the Cubio, inside the shell.
func _place_caught(radius: float, seconds: float) -> void:
	var count := mini(_score, tuning.captured_visual_cap)
	caught.set_visible_count(count)
	var width := minf(tuning.jellyfish_collider_radius * 4.0 * CAUGHT_WIDTH_SHARE, radius * 0.42)
	for index: int in count:
		var phase := float(index) * 2.39996 + seconds * (0.35 + float(index % 3) * 0.08)
		var reach := radius * (0.6 + float(index % 4) * 0.055)
		var depth := sin(phase * 1.3) * radius * 0.25
		var at := Vector3(cos(phase) * reach, sin(phase) * reach, depth)
		caught.set_jellyfish(index, at, width, 0.0, sin(seconds * 1.7 + index) * 0.25)


func _leave() -> void:
	_active = false
	_left = true
	visible = false
	_collider.disabled = true
	freeze = true
	_live_drag_target = Vector2.ZERO


func _on_arena_event(kind: StringName, id: String, data: Dictionary) -> void:
	if id != player_id:
		return
	match kind:
		&"swipe":
			var direction: Vector2 = data.get("direction", Vector2.ZERO)
			var strength := float(data.get("strength", 0.0))
			if not _active or direction.length_squared() == 0.0 or not is_finite(strength):
				return
			direction = direction.normalized()
			# The impulse is the speed change times the mass, so heavy bubbles move less.
			apply_central_impulse(Vector3(direction.x, direction.y, 0.0) * strength)
			_swipe_direction = direction
			_swipe_at_msec = _visual_host_msec
		&"pop":
			_pop_at_msec = int(data.get("at_msec", _visual_host_msec))
			_visual_host_msec = maxi(_visual_host_msec, _pop_at_msec)
			linear_velocity = Vector3.ZERO
			_live_drag_target = Vector2.ZERO
			shell.pop()
			shell.reform(tuning.bubble_reform_seconds)
			_refresh_visual(_pop_at_msec)
		&"player_left":
			_leave()


func _on_drag_visual_changed(id: String, drag: Vector2, gesture_started_msec: int) -> void:
	if id != player_id or not _active or not _connected:
		return
	_live_drag_started_msec = gesture_started_msec
	_drag_last_msec = _visual_host_msec
	var hold_limit := roundi(tuning.swipe_max_hold_seconds * 1000.0)
	var within := (
		gesture_started_msec >= 0 and _visual_host_msec - gesture_started_msec <= hold_limit
	)
	_live_drag_target = drag.limit_length(1.0) if within else Vector2.ZERO


func _on_personal_state(id: String, snapshot: Dictionary) -> void:
	if id == player_id:
		apply_authoritative_snapshot(snapshot)


func _on_phase_changed(phase_name: StringName, _snapshot: Dictionary) -> void:
	set_host_phase(phase_name)


func _on_body_entered(body: Node) -> void:
	var other := body as Bubbles3DPlayerBubble
	if other != null and _active:
		bumped.emit(other.player_id)
