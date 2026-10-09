@tool
class_name TiltShiftState
extends RefCounted
## Typed host contracts; later transport converts these to its own wire representation.


class Player:
	extends RefCounted
	var player_id: String = ""
	var player_name: String = ""
	var character_color: String = ""
	var seat: int = 1
	var team: int = -1
	var connected: bool = true
	var angle_radians: float = 0.0
	var paddle_ids := PackedStringArray()


class Neighbor:
	extends RefCounted
	var first_id: String
	var second_id: String
	var distance: float


class Allocation:
	extends RefCounted
	var paddle_ids := PackedStringArray()
	var owner_ids := PackedStringArray()
	var player_ids := PackedStringArray()
	var counts := PackedInt32Array()
	var minimum_conflicts: int = 0
	var conflicts: Array[Neighbor] = []


class BallHandle:
	extends RefCounted
	var round_token: String
	var index: int


class Snapshot:
	extends RefCounted
	var phase: StringName
	var round_token: String
	var round_number: int
	var round_count: int
	var started_at_msec: int
	var deadline_msec: int
	var scores: Array[int] = [0, 0]
	var winner: int = -1
	var is_draw: bool = false
	var players: Array[Player] = []
	var allocations: Array[Allocation] = []
	var neighbors: Array[Neighbor] = []
	var neighbor_distance: float
	var paddle_layout: TiltShiftPaddleLayout
	var basket_preset: TiltShiftBasketPreset
	var physics: TiltShiftPhysicsTuning


class Result:
	extends RefCounted
	var accepted: bool = false
	var reason: StringName = &""
	var errors := PackedStringArray()
	var ball: BallHandle


static func accepted(ball: BallHandle = null) -> Result:
	var result := Result.new()
	result.accepted = true
	result.ball = ball
	return result


static func copy_player(source: Player) -> Player:
	var result := Player.new()
	result.player_id = source.player_id
	result.player_name = source.player_name
	result.character_color = source.character_color
	result.seat = source.seat
	result.team = source.team
	result.connected = source.connected
	result.angle_radians = source.angle_radians
	result.paddle_ids = source.paddle_ids.duplicate()
	return result


static func copy_neighbor(source: Neighbor) -> Neighbor:
	var result := Neighbor.new()
	result.first_id = source.first_id
	result.second_id = source.second_id
	result.distance = source.distance
	return result


static func copy_allocation(source: Allocation) -> Allocation:
	var result := Allocation.new()
	result.paddle_ids = source.paddle_ids.duplicate()
	result.owner_ids = source.owner_ids.duplicate()
	result.player_ids = source.player_ids.duplicate()
	result.counts = source.counts.duplicate()
	result.minimum_conflicts = source.minimum_conflicts
	for conflict: Neighbor in source.conflicts:
		result.conflicts.append(copy_neighbor(conflict))
	return result


static func rejected(reason: StringName, errors := PackedStringArray()) -> Result:
	var result := Result.new()
	result.reason = reason
	result.errors = errors.duplicate()
	return result
