class_name Bubbles3DPlayerArena
extends Node3D
## Up to ten player bubbles on the gameplay plane, inside invisible walls that stop bubbles only.
## Jolt resolves bumps and wall rebounds; this node steps visuals and reports bumps.

signal player_collision(first_id: String, second_id: String)

## Physics layer of the player bubbles.
const BUBBLE_LAYER := 1 << 9
## Physics layer of the walls at the plane's edges.
const WALL_LAYER := 1 << 10
## Physics layer of jellyfishes and pufferfishes, which only watch for bubbles.
const CREATURE_LAYER := 1 << 11
## The playable plane, centred on the origin, in world units.
const PLANE := Rect2(-9.6, -5.4, 19.2, 10.8)

## Where creatures spawn and travel, inside the plane.
var bounds := PLANE
var walls: PlaneWalls3D
var _controller: Bubbles3DRoundController
var _bubbles: Dictionary[String, Bubbles3DPlayerBubble] = { }
var _ordered_ids: Array[String] = []
var _bumped_this_step: Dictionary[String, bool] = { }


func setup(controller: Bubbles3DRoundController, creature_bounds: Rect2 = PLANE) -> bool:
	if controller == null or controller.tuning == null or not creature_bounds.has_area():
		return false
	_controller = controller
	bounds = creature_bounds
	walls = PlaneWalls3D.new()
	walls.name = "Walls"
	walls.bounds = PLANE
	walls.collision_layer = WALL_LAYER
	# Godot adds both bodies' bounce; each bubble already carries half of the bump rebound.
	var tuning := controller.tuning
	walls.bounce = maxf(0.0, tuning.wall_bounciness - tuning.bump_bounciness * 0.5)
	add_child(walls)
	return true


func add_bubble(player_id: String, start_position: Vector2) -> Bubbles3DPlayerBubble:
	if _controller == null or _bubbles.has(player_id) or _bubbles.size() >= 10:
		return null
	var snapshot := _controller.personal_snapshot(player_id)
	if snapshot.is_empty() or bool(snapshot.get("left", false)):
		return null
	var bubble := Bubbles3DPlayerBubble.new()
	bubble.name = "Bubble_%s" % player_id.validate_node_name()
	var selection := CharacterSelection.for_player(snapshot)
	bubble.configure(
		player_id,
		Color(String(selection.character_color)),
		_controller.tuning,
		BUBBLE_LAYER,
		BUBBLE_LAYER | WALL_LAYER,
	)
	add_child(bubble)
	bubble.position = PlaneLock3D.on_plane(start_position)
	bubble.bind_controller(_controller)
	bubble.bumped.connect(_on_bumped.bind(player_id))
	_bubbles[player_id] = bubble
	_ordered_ids.append(player_id)
	_ordered_ids.sort()
	return bubble


func get_bubble(player_id: String) -> Bubbles3DPlayerBubble:
	return _bubbles.get(player_id)


func bubble_ids() -> Array[String]:
	return _ordered_ids.duplicate()


## Caller supplies the host clock once per physics frame.
func simulate_step(delta: float, host_time_msec: int) -> bool:
	if _controller == null or not is_finite(delta) or delta < 0.0 or delta > 0.1:
		return false
	if not _controller.advance(host_time_msec).accepted:
		return false
	_bumped_this_step.clear()
	for player_id: String in _ordered_ids:
		_bubbles[player_id].simulate_step(delta, host_time_msec)
	return true


func _on_bumped(other_id: String, player_id: String) -> void:
	var first := mini_string(player_id, other_id)
	var second := other_id if first == player_id else player_id
	var pair := "%s:%s" % [first, second]
	# Both bodies report the same contact.
	if _bumped_this_step.has(pair):
		return
	_bumped_this_step[pair] = true
	player_collision.emit(first, second)


static func mini_string(first: String, second: String) -> String:
	return first if first < second else second
