class_name BubblesPlayerArena
extends Node2D
## Fixed-order kinematics and pair collisions for up to ten player bubbles.
## Later arena systems may call collection/pop hooks; no NPCs live here.

signal player_collision(first_id: String, second_id: String, spun_id: String)

const BUBBLE_SCENE: PackedScene = preload("res://minigames/bubbles_player_bubble.tscn")
const PLAYER_RESTITUTION := 0.5
var bounds := Rect2()
var wall_bounds := Rect2()
var _controller: BubblesRoundController
var _bubbles: Dictionary = {}
var _ordered_ids: Array[String] = []


func setup(controller: BubblesRoundController, arena_bounds: Rect2, viewport_bounds: Rect2 = Rect2()) -> bool:
	if controller == null or not arena_bounds.has_area() or controller.tuning == null:
		return false
	_controller = controller
	bounds = arena_bounds
	wall_bounds = viewport_bounds if viewport_bounds.has_area() else arena_bounds
	return true


func set_wall_bounds(viewport_bounds: Rect2) -> bool:
	if not viewport_bounds.has_area():
		return false
	wall_bounds = viewport_bounds
	return true


func add_bubble(player_id: String, start_position: Vector2) -> BubblesPlayerBubble:
	if _controller == null or _bubbles.has(player_id) or _bubbles.size() >= 10:
		return null
	var snapshot := _controller.personal_snapshot(player_id)
	if snapshot.is_empty() or bool(snapshot.get("left", false)):
		return null
	var bubble := BUBBLE_SCENE.instantiate() as BubblesPlayerBubble
	add_child(bubble)
	bubble.global_position = start_position
	var selection := CharacterSelection.for_player(snapshot)
	bubble.configure(
		player_id,
		String(snapshot.get("name", "")),
		Color(String(selection.character_color)),
		_controller.tuning,
		StringName(selection.character_shape)
	)
	bubble.bind_controller(_controller)
	_bubbles[player_id] = bubble
	_ordered_ids.append(player_id)
	_ordered_ids.sort()
	return bubble


func get_bubble(player_id: String) -> BubblesPlayerBubble:
	return _bubbles.get(player_id) as BubblesPlayerBubble


func bubble_ids() -> Array[String]:
	return _ordered_ids.duplicate()


## Caller supplies the host clock and a fixed delta, normally 1/60 second.
func simulate_step(delta: float, host_time_msec: int) -> bool:
	if _controller == null or not is_finite(delta) or delta < 0.0 or delta > 0.05 or host_time_msec < 0:
		return false
	if not _controller.advance(host_time_msec).accepted:
		return false
	for player_id: String in _ordered_ids:
		var bubble: BubblesPlayerBubble = _bubbles[player_id]
		bubble.simulate_step(delta, wall_bounds, host_time_msec)
	for first: int in _ordered_ids.size():
		for second: int in range(first + 1, _ordered_ids.size()):
			var a: BubblesPlayerBubble = _bubbles[_ordered_ids[first]]
			var b: BubblesPlayerBubble = _bubbles[_ordered_ids[second]]
			if _resolve_pair(a, b, host_time_msec):
				var spun_id := a.player_id if a.is_spinning(host_time_msec) else (b.player_id if b.is_spinning(host_time_msec) else "")
				player_collision.emit(a.player_id, b.player_id, spun_id)
	# Pair separation can move a body through the invisible boundary.
	for player_id: String in _ordered_ids:
		var bubble: BubblesPlayerBubble = _bubbles[player_id]
		bubble.simulate_step(0.0, wall_bounds, host_time_msec)
	return true


func _resolve_pair(a: BubblesPlayerBubble, b: BubblesPlayerBubble, host_time_msec: int) -> bool:
	if not a.is_simulated() or not b.is_simulated():
		return false
	var delta := b.global_position - a.global_position
	var distance := delta.length()
	var minimum := a.collision_radius() + b.collision_radius()
	if distance >= minimum:
		return false
	var normal := delta / distance if distance > 0.0001 else Vector2.RIGHT
	var a_spins := a.is_spinning(host_time_msec)
	var b_spins := b.is_spinning(host_time_msec)
	var inverse_a := 0.0 if a_spins else 1.0 / a.effective_mass()
	var inverse_b := 0.0 if b_spins else 1.0 / b.effective_mass()
	var separation_a := 0.5 if inverse_a + inverse_b == 0.0 else inverse_a / (inverse_a + inverse_b)
	var separation_b := 1.0 - separation_a
	var overlap := minimum - distance
	a.global_position -= normal * overlap * separation_a
	b.global_position += normal * overlap * separation_b
	var closing_speed := (a.velocity - b.velocity).dot(normal)
	if closing_speed > 0.0 and inverse_a + inverse_b > 0.0:
		var impulse := (1.0 + PLAYER_RESTITUTION) * closing_speed / (inverse_a + inverse_b)
		a.velocity -= normal * impulse * inverse_a
		b.velocity += normal * impulse * inverse_b
	if a_spins and not b_spins:
		b.velocity += normal * a.tuning.spin_shove_impulse / b.effective_mass()
	elif b_spins and not a_spins:
		a.velocity -= normal * b.tuning.spin_shove_impulse / a.effective_mass()
	a.limit_speed()
	b.limit_speed()
	return true
