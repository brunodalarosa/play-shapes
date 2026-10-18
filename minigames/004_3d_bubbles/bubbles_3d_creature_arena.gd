class_name Bubbles3DCreatureArena
extends Node3D
## Host-owned free creatures: jellyfish waves, safe spawns, scatter after a pop, and pufferfish
## crossings. Contacts come from each creature's sensor overlapping a bubble body. Step after the
## player arena, at the same host time.

signal jellyfish_spawned(creature_id: int, released: bool)
signal jellyfish_collected(creature_id: int, player_id: String)
signal pufferfish_warned(creature_id: int, entry: Vector2, exit: Vector2)
signal pufferfish_spawned(creature_id: int)
signal pufferfish_hit(creature_id: int, player_id: String)
signal jellyfish_scattered(player_id: String, spawned: int, discarded_by_cap: int)
signal wave_changed(high: bool, rate_per_second: float, duration_msec: int)

const MAX_SAFE_SPAWN_ATTEMPTS := 64
const MAX_ACTIVE_PUFFERS := 64
## How far outside the plane a pufferfish starts and ends, beyond its own radius.
const SPAWN_OUTSIDE_MARGIN := 0.2

var swarm: Bubbles3DJellyfishSwarm
var _controller: Bubbles3DRoundController
var _players: Bubbles3DPlayerArena
var _tuning: Bubbles3DTuning
var _jellies: Dictionary[int, Bubbles3DJellyfish] = { }
var _puffers: Dictionary[int, Bubbles3DPufferfish] = { }
var _next_creature_id := 1
var _wave_high := true
var _wave_rate := 0.0
var _wave_until_msec := -1
var _jelly_credit := 0.0
var _puffer_credit := 0.0


func setup(controller: Bubbles3DRoundController, player_arena: Bubbles3DPlayerArena) -> bool:
	if controller == null or player_arena == null or controller.tuning == null:
		return false
	_controller = controller
	_players = player_arena
	_tuning = controller.tuning
	swarm = Bubbles3DJellyfishSwarm.new()
	swarm.name = "FreeJellyfish"
	add_child(swarm)
	swarm.setup(_tuning.max_free_jellyfish)
	_controller.arena_event_requested.connect(_on_arena_event)
	_controller.phase_changed.connect(_on_phase_changed)
	if _controller.phase_name() == &"active":
		_begin_wave(_controller.active_start_msec(), true)
	return true


func jellyfish_count() -> int:
	return _jellies.size()


func pufferfish_count() -> int:
	return _puffers.size()


func jellyfish_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.assign(_jellies.keys())
	ids.sort()
	return ids


func get_jellyfish(creature_id: int) -> Bubbles3DJellyfish:
	return _jellies.get(creature_id)


func get_pufferfish(creature_id: int) -> Bubbles3DPufferfish:
	return _puffers.get(creature_id)


func wave_status() -> Dictionary:
	return { "high": _wave_high, "rate_per_second": _wave_rate, "until_msec": _wave_until_msec }


func puffer_rate_at(host_time_msec: int) -> float:
	var elapsed := float(host_time_msec - _controller.active_start_msec())
	var share := clampf(elapsed / (_tuning.round_duration_seconds * 1000.0), 0.0, 1.0)
	return lerpf(_tuning.pufferfish_start_spawn_rate, _tuning.pufferfish_max_spawn_rate, share)


## Places one fresh jellyfish at an exact point, for deterministic tests; normal spawning uses
## bounded random attempts.
func spawn_fresh_at(at: Vector2, at_msec: int, heading: Vector2 = Vector2.RIGHT) -> int:
	if (
		_controller == null or _jellies.size() >= _tuning.max_free_jellyfish
		or not _safe_jellyfish_position(at)
	):
		return -1
	return _create_jellyfish(at, heading, at_msec, false, 0)


## Schedules one exact pufferfish pass, for deterministic tests; normal paths cross between
## opposite edges at random offsets.
func schedule_puffer_path(start: Vector2, destination: Vector2, at_msec: int) -> int:
	if (
		_controller == null or _puffers.size() >= MAX_ACTIVE_PUFFERS or not start.is_finite()
		or not destination.is_finite() or start.distance_to(destination) < 0.01
	):
		return -1
	var creature := Bubbles3DPufferfish.new()
	var id := _next_creature_id
	_next_creature_id += 1
	creature.name = "Pufferfish_%d" % id
	add_child(creature)
	creature.configure(
		id,
		_tuning,
		at_msec,
		start,
		destination,
		Bubbles3DPlayerArena.BUBBLE_LAYER,
		Bubbles3DPlayerArena.CREATURE_LAYER,
	)
	_puffers[id] = creature
	if creature.active:
		pufferfish_spawned.emit(id)
	else:
		pufferfish_warned.emit(id, start, destination)
	return id


func simulate_step(delta: float, host_time_msec: int) -> bool:
	if _controller == null or not is_finite(delta) or delta < 0.0 or delta > 0.1:
		return false
	if not _controller.advance(host_time_msec).accepted:
		return false
	var phase := _controller.phase_name()
	if phase not in [&"countdown", &"active"]:
		_draw_jellies(host_time_msec)
		return true
	for id: int in jellyfish_ids():
		var jelly := _jellies[id]
		var unit := _controller.next_random_unit() if jelly.needs_turn(host_time_msec) else 0.5
		jelly.simulate_step(delta, host_time_msec, unit)
		if jelly.is_outside(Bubbles3DPlayerArena.PLANE):
			_remove_jellyfish(id)
	if phase == &"active":
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
	_draw_jellies(host_time_msec)
	return true


func _draw_jellies(host_time_msec: int) -> void:
	var ids := jellyfish_ids()
	swarm.set_visible_count(ids.size())
	var free_width := _tuning.jellyfish_collider_radius * 4.0
	for index: int in ids.size():
		var jelly := _jellies[ids[index]]
		var age := float(maxi(0, host_time_msec - jelly.spawned_at_msec)) / 1000.0
		var breath := TAU * age / _tuning.jellyfish_breath_period_seconds
		var pulse := 1.0 + sin(breath) * _tuning.jellyfish_breath_amplitude
		var width := free_width * jelly.entrance_scale(host_time_msec) * pulse
		var flash := 1.0 if jelly.flashes_white(host_time_msec) else 0.0
		swarm.set_jellyfish(index, jelly.position, width, flash, sin(breath * 0.5) * 0.12)


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
		var x := lerpf(
			bounds.position.x + radius,
			bounds.end.x - radius,
			_controller.next_random_unit(),
		)
		var y := lerpf(
			bounds.position.y + radius,
			bounds.end.y - radius,
			_controller.next_random_unit(),
		)
		var at := Vector2(x, y)
		if _safe_jellyfish_position(at):
			var heading := Vector2.from_angle(_controller.next_random_unit() * TAU)
			_create_jellyfish(at, heading, at_msec, false, 0)
			return true
	return false


func _safe_jellyfish_position(at: Vector2) -> bool:
	if not at.is_finite():
		return false
	var radius := _tuning.jellyfish_collider_radius
	var area := _players.bounds.grow(-radius)
	if not area.has_area() or not area.has_point(at):
		return false
	for player_id: String in _players.bubble_ids():
		var bubble := _players.get_bubble(player_id)
		var reach := radius + bubble.bubble_radius() + _tuning.jellyfish_spawn_clearance
		if bubble.visible and at.distance_to(bubble.plane_position()) < reach:
			return false
	for puffer: Bubbles3DPufferfish in _puffers.values():
		var reach := radius + puffer.radius + _tuning.jellyfish_spawn_clearance
		if not puffer.finished and at.distance_to(puffer.plane_position()) < reach:
			return false
	return true


func _create_jellyfish(
	at: Vector2,
	heading: Vector2,
	at_msec: int,
	from_pop: bool,
	lockout_msec: int,
) -> int:
	var creature := Bubbles3DJellyfish.new()
	var id := _next_creature_id
	_next_creature_id += 1
	creature.name = "Jellyfish_%d" % id
	creature.configure(
		id,
		_tuning,
		at_msec,
		at,
		heading,
		Bubbles3DPlayerArena.BUBBLE_LAYER,
		Bubbles3DPlayerArena.CREATURE_LAYER,
		from_pop,
		lockout_msec,
	)
	add_child(creature)
	_jellies[id] = creature
	jellyfish_spawned.emit(id, from_pop)
	return id


## Each collectible jellyfish goes to the first bubble, by player ID, that its sensor overlaps.
func _collect_jellyfish(host_time_msec: int) -> void:
	for id: int in jellyfish_ids():
		var jelly := _jellies[id]
		if not jelly.is_collectible(host_time_msec):
			continue
		for bubble: Bubbles3DPlayerBubble in _touching_bubbles(jelly):
			if bubble.request_jellyfish_collection(host_time_msec).accepted:
				_remove_jellyfish(id)
				jellyfish_collected.emit(id, bubble.player_id)
				break


func _touching_bubbles(sensor: Area3D) -> Array[Bubbles3DPlayerBubble]:
	var touching: Array[Bubbles3DPlayerBubble] = []
	for body: Node3D in sensor.get_overlapping_bodies():
		var bubble := body as Bubbles3DPlayerBubble
		if bubble != null and bubble.is_simulated():
			touching.append(bubble)
	touching.sort_custom(
		func(a: Bubbles3DPlayerBubble, b: Bubbles3DPlayerBubble) -> bool:
			return a.player_id < b.player_id,
	)
	return touching


func _remove_jellyfish(id: int) -> void:
	var creature: Bubbles3DJellyfish = _jellies.get(id)
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
	var scatter_radius := _tuning.starting_radius + _tuning.jellyfish_collider_radius + 0.12
	var area := _players.bounds.grow(-_tuning.jellyfish_collider_radius)
	var centre := bubble.plane_position()
	for index: int in count:
		var jitter := (_controller.next_random_unit() - 0.5) * 0.24
		var heading := Vector2.from_angle(TAU * float(index) / float(maxi(count, 1)) + jitter)
		var spread := _controller.next_random_unit() * _tuning.jellyfish_collider_radius * 2.0
		var raw := centre + heading * (scatter_radius + spread)
		var at := Vector2(
			clampf(raw.x, area.position.x, area.end.x),
			clampf(raw.y, area.position.y, area.end.y),
		)
		_create_jellyfish(at, heading, at_msec, true, lockout)
	jellyfish_scattered.emit(player_id, count, requested - count)


func _step_puffers(delta: float, host_time_msec: int) -> void:
	var ids: Array[int] = []
	ids.assign(_puffers.keys())
	ids.sort()
	for id: int in ids:
		var puffer := _puffers[id]
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
		for bubble: Bubbles3DPlayerBubble in _touching_bubbles(puffer):
			if bubble.is_invulnerable(host_time_msec):
				continue
			if bubble.request_puffer_pop(host_time_msec).accepted:
				pufferfish_hit.emit(id, bubble.player_id)


func _begin_wave(at_msec: int, first: bool) -> void:
	_wave_high = _controller.next_random_unit() >= 0.5 if first else not _wave_high
	var span := _tuning.jellyfish_wave_max_seconds - _tuning.jellyfish_wave_min_seconds
	var seconds := _tuning.jellyfish_wave_min_seconds + _controller.next_random_unit() * span
	_wave_until_msec = at_msec + roundi(seconds * 1000.0)
	var unit := _controller.next_random_unit()
	_wave_rate = (
		lerpf(_tuning.jellyfish_low_spawn_rate, _tuning.jellyfish_high_spawn_rate, unit)
		if _wave_high
		else _tuning.jellyfish_low_spawn_rate * unit
	)
	wave_changed.emit(_wave_high, _wave_rate, _wave_until_msec - at_msec)


func _advance_wave(host_time_msec: int) -> void:
	while host_time_msec >= _wave_until_msec and _wave_until_msec >= 0:
		_begin_wave(_wave_until_msec, false)


func _spawn_random_puffer(at_msec: int) -> void:
	var plane := Bubbles3DPlayerArena.PLANE
	var margin := _tuning.pufferfish_radius() + SPAWN_OUTSIDE_MARGIN
	var edge := mini(3, floori(_controller.next_random_unit() * 4.0))
	var first := 0.1 + 0.8 * _controller.next_random_unit()
	var last := 0.1 + 0.8 * _controller.next_random_unit()
	var left := plane.position.x - margin
	var right := plane.end.x + margin
	var bottom := plane.position.y - margin
	var top := plane.end.y + margin
	var start := Vector2.ZERO
	var destination := Vector2.ZERO
	match edge:
		0:
			start = Vector2(left, lerpf(plane.position.y, plane.end.y, first))
			destination = Vector2(right, lerpf(plane.position.y, plane.end.y, last))
		1:
			start = Vector2(right, lerpf(plane.position.y, plane.end.y, first))
			destination = Vector2(left, lerpf(plane.position.y, plane.end.y, last))
		2:
			start = Vector2(lerpf(plane.position.x, plane.end.x, first), top)
			destination = Vector2(lerpf(plane.position.x, plane.end.x, last), bottom)
		3:
			start = Vector2(lerpf(plane.position.x, plane.end.x, first), bottom)
			destination = Vector2(lerpf(plane.position.x, plane.end.x, last), top)
	schedule_puffer_path(start, destination, at_msec)
