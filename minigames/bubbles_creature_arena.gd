class_name BubblesCreatureArena
extends Node2D
## Host-owned free creatures. Call after the player arena's fixed step at the same host time.

signal jellyfish_spawned(creature_id: int, released: bool)
signal jellyfish_collected(creature_id: int, player_id: String)
signal pufferfish_warned(creature_id: int, entry: Vector2, exit: Vector2)
signal pufferfish_spawned(creature_id: int)
signal pufferfish_hit(creature_id: int, player_id: String)
signal jellyfish_scattered(player_id: String, spawned: int, discarded_by_cap: int)
signal wave_changed(high: bool, rate_per_second: float, duration_msec: int)

const JELLYFISH_SCENE: PackedScene = preload("res://minigames/bubbles_jellyfish.tscn")
const PUFFERFISH_SCENE: PackedScene = preload("res://minigames/bubbles_pufferfish.tscn")
const MAX_SAFE_SPAWN_ATTEMPTS := 64
const MAX_ACTIVE_PUFFERS := 64
const SPAWN_OUTSIDE_MARGIN := 20.0

var _controller: BubblesRoundController
var _players: BubblesPlayerArena
var _tuning: BubblesTuning
var _jellies: Dictionary = {}
var _puffers: Dictionary = {}
var _next_creature_id := 1
var _wave_high := true
var _wave_rate := 0.0
var _wave_until_msec := -1
var _jelly_credit := 0.0
var _puffer_credit := 0.0


func setup(controller: BubblesRoundController, player_arena: BubblesPlayerArena) -> bool:
	if controller == null or player_arena == null or not player_arena.bounds.has_area() or controller.tuning == null:
		return false
	_controller = controller
	_players = player_arena
	_tuning = controller.tuning
	_controller.arena_event_requested.connect(_on_arena_event)
	_controller.phase_changed.connect(_on_phase_changed)
	if _controller.phase_name() == &"active":
		_begin_wave(_controller.active_start_msec(), true)
	return true


func jellyfish_count() -> int:
	return _jellies.size()


func pufferfish_count() -> int:
	return _puffers.size()


func get_jellyfish(creature_id: int) -> BubblesJellyfish:
	return _jellies.get(creature_id) as BubblesJellyfish


func get_pufferfish(creature_id: int) -> BubblesPufferfish:
	return _puffers.get(creature_id) as BubblesPufferfish


func wave_status() -> Dictionary:
	return {"high": _wave_high, "rate_per_second": _wave_rate, "until_msec": _wave_until_msec}


func puffer_rate_at(host_time_msec: int) -> float:
	var elapsed_ratio := clampf(float(host_time_msec - _controller.active_start_msec()) / (_tuning.round_duration_seconds * 1000.0), 0.0, 1.0)
	return lerpf(_tuning.pufferfish_start_spawn_rate, _tuning.pufferfish_max_spawn_rate, elapsed_ratio)


## Explicit position seam for deterministic fixtures; ordinary spawning uses bounded random attempts.
func spawn_fresh_at(world_position: Vector2, at_msec: int, direction: Vector2 = Vector2.RIGHT) -> int:
	if _controller == null or _jellies.size() >= _tuning.max_free_jellyfish or not _safe_jellyfish_position(world_position):
		return -1
	return _create_jellyfish(world_position, direction, at_msec, false, 0)


## Explicit one-pass path seam; normal paths choose opposing edges with randomized offsets.
func schedule_puffer_path(start: Vector2, destination: Vector2, at_msec: int) -> int:
	if _controller == null or _puffers.size() >= MAX_ACTIVE_PUFFERS or not start.is_finite() or not destination.is_finite() or start.distance_to(destination) < 1.0:
		return -1
	var creature := PUFFERFISH_SCENE.instantiate() as BubblesPufferfish
	add_child(creature)
	var id := _next_creature_id
	_next_creature_id += 1
	creature.configure(id, _tuning, at_msec, start, destination)
	_puffers[id] = creature
	if creature.active:
		pufferfish_spawned.emit(id)
	else:
		pufferfish_warned.emit(id, start, destination)
	return id


func simulate_step(delta: float, host_time_msec: int) -> bool:
	if _controller == null or not is_finite(delta) or delta < 0.0 or delta > 0.05 or host_time_msec < 0:
		return false
	if not _controller.advance(host_time_msec).accepted:
		return false
	var phase := _controller.phase_name()
	if phase not in [&"countdown", &"active"]:
		return true
	for id: int in _jellies.keys():
		var jelly: BubblesJellyfish = _jellies[id]
		var unit := _controller.next_random_unit() if jelly.needs_turn(host_time_msec) else 0.5
		jelly.simulate_step(delta, host_time_msec, unit)
		if jelly.is_offscreen(_players.bounds):
			_remove_jellyfish(id)
	if phase != &"active":
		return true
	_collect_jellyfish(host_time_msec)
	_step_puffers(delta, host_time_msec)
	_advance_wave(host_time_msec)
	_jelly_credit += _wave_rate * delta
	while _jelly_credit >= 1.0 and _jellies.size() < _tuning.max_free_jellyfish:
		_jelly_credit -= 1.0
		_try_spawn_safe(host_time_msec)
	if _jellies.size() >= _tuning.max_free_jellyfish:
		_jelly_credit = 0.0
	_puffer_credit += puffer_rate_at(host_time_msec) * delta
	while _puffer_credit >= 1.0:
		_puffer_credit -= 1.0
		if _puffers.size() < MAX_ACTIVE_PUFFERS:
			_spawn_random_puffer(host_time_msec)
	return true


func _on_phase_changed(phase: StringName, _snapshot: Dictionary) -> void:
	if phase == &"active":
		_begin_wave(_controller.active_start_msec(), true)
		_jelly_credit = 0.0
		_puffer_credit = 0.0


func _on_arena_event(kind: StringName, player_id: String, data: Dictionary) -> void:
	match kind:
		&"place_starting_jellyfish":
			for index: int in mini(int(data.get("count", 0)), _tuning.max_free_jellyfish):
				if not _try_spawn_safe(_controller.last_host_time_msec()):
					break
		&"pop":
			_scatter_from_pop(player_id, data)


func _try_spawn_safe(at_msec: int) -> bool:
	if _jellies.size() >= _tuning.max_free_jellyfish:
		return false
	var bounds := _players.bounds
	var radius := _tuning.jellyfish_collider_radius
	if bounds.size.x <= radius * 2.0 or bounds.size.y <= radius * 2.0:
		return false
	for attempt: int in MAX_SAFE_SPAWN_ATTEMPTS:
		var x := lerpf(bounds.position.x + radius, bounds.end.x - radius, _controller.next_random_unit())
		var y := lerpf(bounds.position.y + radius, bounds.end.y - radius, _controller.next_random_unit())
		var position_world := Vector2(x, y)
		if _safe_jellyfish_position(position_world):
			var angle := _controller.next_random_unit() * TAU
			_create_jellyfish(position_world, Vector2.from_angle(angle), at_msec, false, 0)
			return true
	return false


func _safe_jellyfish_position(world_position: Vector2) -> bool:
	if not world_position.is_finite():
		return false
	var radius := _tuning.jellyfish_collider_radius
	var bounds := _players.bounds.grow(-radius)
	if not bounds.has_area() or not bounds.has_point(world_position):
		return false
	for player_id: String in _players.bubble_ids():
		var bubble := _players.get_bubble(player_id)
		if bubble.visible and world_position.distance_to(bubble.global_position) < radius + bubble.collision_radius() + _tuning.jellyfish_spawn_clearance:
			return false
	for puffer: BubblesPufferfish in _puffers.values():
		if not puffer.finished and world_position.distance_to(puffer.global_position) < radius + puffer.radius + _tuning.jellyfish_spawn_clearance:
			return false
	return true


func _create_jellyfish(world_position: Vector2, direction: Vector2, at_msec: int, from_pop: bool, lockout_msec: int) -> int:
	var creature := JELLYFISH_SCENE.instantiate() as BubblesJellyfish
	add_child(creature)
	var id := _next_creature_id
	_next_creature_id += 1
	creature.configure(id, _tuning, at_msec, world_position, direction, from_pop, lockout_msec)
	_jellies[id] = creature
	jellyfish_spawned.emit(id, from_pop)
	return id


func _collect_jellyfish(host_time_msec: int) -> void:
	for id: int in _jellies.keys():
		var jelly: BubblesJellyfish = _jellies[id]
		if not jelly.is_collectible(host_time_msec):
			continue
		for player_id: String in _players.bubble_ids():
			var bubble := _players.get_bubble(player_id)
			if not bubble.is_simulated() or jelly.global_position.distance_to(bubble.global_position) > jelly.radius + bubble.collision_radius():
				continue
			if bubble.request_jellyfish_collection(host_time_msec).accepted:
				_remove_jellyfish(id)
				jellyfish_collected.emit(id, player_id)
				break


func _remove_jellyfish(id: int) -> void:
	var creature: BubblesJellyfish = _jellies.get(id)
	if creature != null:
		_jellies.erase(id)
		creature.queue_free()


func _scatter_from_pop(player_id: String, data: Dictionary) -> void:
	var requested := maxi(0, int(data.get("released", 0)))
	var available := maxi(0, _tuning.max_free_jellyfish - _jellies.size())
	var count := mini(requested, available)
	var bubble := _players.get_bubble(player_id)
	if bubble == null:
		jellyfish_scattered.emit(player_id, 0, requested)
		return
	var at_msec := int(data.get("at_msec", _controller.last_host_time_msec()))
	var lockout := int(data.get("lockout_msec", 0))
	var scatter_radius := _tuning.starting_radius + _tuning.jellyfish_collider_radius + 12.0
	var bounds := _players.bounds.grow(-_tuning.jellyfish_collider_radius)
	for index: int in count:
		var angle := TAU * float(index) / float(maxi(count, 1)) + (_controller.next_random_unit() - 0.5) * 0.24
		var direction := Vector2.from_angle(angle)
		var reach := scatter_radius + _controller.next_random_unit() * _tuning.jellyfish_collider_radius * 2.0
		var raw_position := bubble.global_position + direction * reach
		var position_world := Vector2(clampf(raw_position.x, bounds.position.x, bounds.end.x), clampf(raw_position.y, bounds.position.y, bounds.end.y))
		_create_jellyfish(position_world, direction, at_msec, true, lockout)
	jellyfish_scattered.emit(player_id, count, requested - count)


func _step_puffers(delta: float, host_time_msec: int) -> void:
	for id: int in _puffers.keys():
		var puffer: BubblesPufferfish = _puffers[id]
		var was_active := puffer.active
		puffer.simulate_step(delta, host_time_msec)
		if puffer.finished:
			_puffers.erase(id)
			puffer.queue_free()
			continue
		if puffer.active and not was_active:
			pufferfish_spawned.emit(id)
		if not puffer.can_hit_player():
			continue
		for player_id: String in _players.bubble_ids():
			var bubble := _players.get_bubble(player_id)
			if not bubble.is_simulated() or bubble.is_invulnerable(host_time_msec):
				continue
			if puffer.global_position.distance_to(bubble.global_position) <= puffer.radius + bubble.collision_radius():
				if bubble.request_puffer_pop(host_time_msec).accepted:
					pufferfish_hit.emit(id, player_id)


func _begin_wave(at_msec: int, first: bool) -> void:
	_wave_high = _controller.next_random_unit() >= 0.5 if first else not _wave_high
	var span := _tuning.jellyfish_wave_max_seconds - _tuning.jellyfish_wave_min_seconds
	var seconds := _tuning.jellyfish_wave_min_seconds + _controller.next_random_unit() * span
	_wave_until_msec = at_msec + roundi(seconds * 1000.0)
	var unit := _controller.next_random_unit()
	_wave_rate = lerpf(_tuning.jellyfish_low_spawn_rate, _tuning.jellyfish_high_spawn_rate, unit) if _wave_high else _tuning.jellyfish_low_spawn_rate * unit
	wave_changed.emit(_wave_high, _wave_rate, _wave_until_msec - at_msec)


func _advance_wave(host_time_msec: int) -> void:
	while host_time_msec >= _wave_until_msec and _wave_until_msec >= 0:
		_begin_wave(_wave_until_msec, false)


func _spawn_random_puffer(at_msec: int) -> void:
	var bounds := _players.bounds
	var margin := _tuning.pufferfish_collider_radius + SPAWN_OUTSIDE_MARGIN
	var edge := mini(3, floori(_controller.next_random_unit() * 4.0))
	var first := 0.1 + 0.8 * _controller.next_random_unit()
	var last := 0.1 + 0.8 * _controller.next_random_unit()
	var start := Vector2.ZERO
	var destination := Vector2.ZERO
	match edge:
		0: # left to right
			start = Vector2(bounds.position.x - margin, lerpf(bounds.position.y, bounds.end.y, first))
			destination = Vector2(bounds.end.x + margin, lerpf(bounds.position.y, bounds.end.y, last))
		1: # right to left
			start = Vector2(bounds.end.x + margin, lerpf(bounds.position.y, bounds.end.y, first))
			destination = Vector2(bounds.position.x - margin, lerpf(bounds.position.y, bounds.end.y, last))
		2: # top to bottom
			start = Vector2(lerpf(bounds.position.x, bounds.end.x, first), bounds.position.y - margin)
			destination = Vector2(lerpf(bounds.position.x, bounds.end.x, last), bounds.end.y + margin)
		3: # bottom to top
			start = Vector2(lerpf(bounds.position.x, bounds.end.x, first), bounds.end.y + margin)
			destination = Vector2(lerpf(bounds.position.x, bounds.end.x, last), bounds.position.y - margin)
	schedule_puffer_path(start, destination, at_msec)
