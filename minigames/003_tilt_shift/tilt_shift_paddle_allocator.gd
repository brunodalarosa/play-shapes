@tool
class_name TiltShiftPaddleAllocator
extends RefCounted
## Exact count-constrained separation on bounded team paddles, only at round boundaries.


class Search:
	extends RefCounted
	var ids := PackedStringArray()
	var quotas := PackedInt32Array()
	var used := PackedInt32Array()
	var chosen := PackedInt32Array()
	var best := PackedInt32Array()
	var edges: Array[Vector2i] = []
	var previous := PackedStringArray()
	var random: RandomNumberGenerator
	var minimum: int = 11
	var best_changes: int = -1
	var ties: int = 0


	func visit(index: int, conflicts: int) -> void:
		if conflicts > minimum:
			return
		if index == chosen.size():
			_consider(conflicts)
			return

		for owner: int in ids.size():
			if used[owner] == quotas[owner]:
				continue
			chosen[index] = owner
			used[owner] += 1
			var extra := 0
			for edge: Vector2i in edges:
				if edge.y == index and chosen[edge.x] == owner:
					extra += 1
			visit(index + 1, conflicts + extra)
			used[owner] -= 1


	func _consider(conflicts: int) -> void:
		var changes := 0
		if previous.size() == chosen.size():
			for index: int in chosen.size():
				if previous[index] != ids[chosen[index]]:
					changes += 1
		if conflicts < minimum or (conflicts == minimum and changes > best_changes):
			minimum = conflicts
			best_changes = changes
			ties = 1
			best = chosen.duplicate()
		elif conflicts == minimum and changes == best_changes:
			ties += 1
			if random.randi_range(1, ties) == 1:
				best = chosen.duplicate()


static func neighbors(
	layout: TiltShiftPaddleLayout,
	threshold: float,
) -> Array[TiltShiftState.Neighbor]:
	var result: Array[TiltShiftState.Neighbor] = []
	for first: int in layout.paddles.size():
		for second: int in range(first + 1, layout.paddles.size()):
			var a := layout.paddles[first]
			var b := layout.paddles[second]
			var distance := a.position.distance_to(b.position)
			if distance > threshold:
				continue
			var edge := TiltShiftState.Neighbor.new()
			edge.first_id = a.paddle_id
			edge.second_id = b.paddle_id
			edge.distance = distance
			result.append(edge)
	return result


static func quotas(player_count: int, round_index: int, paddle_count: int = 5) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(player_count)
	result.fill(paddle_count / player_count)
	for extra: int in paddle_count % player_count:
		result[(round_index + extra) % player_count] += 1
	return result


static func allocate(
	paddles: Array[TiltShiftPaddle],
	player_ids: PackedStringArray,
	round_index: int,
	graph: Array[TiltShiftState.Neighbor],
	random: RandomNumberGenerator,
	previous := PackedStringArray(),
) -> TiltShiftState.Allocation:
	if (
		paddles.is_empty() or paddles.size() > 5 or player_ids.is_empty() \
				or player_ids.size() > 5
		or round_index < 0
	):
		return null
	var result := TiltShiftState.Allocation.new()
	result.player_ids = player_ids.duplicate()
	result.counts = quotas(player_ids.size(), round_index, paddles.size())
	for paddle: TiltShiftPaddle in paddles:
		result.paddle_ids.append(paddle.paddle_id)

	var search := Search.new()
	search.ids = player_ids.duplicate()
	search.quotas = result.counts
	search.used.resize(player_ids.size())
	search.chosen.resize(paddles.size())
	search.previous = previous
	search.random = random
	for edge: TiltShiftState.Neighbor in graph:
		var first := result.paddle_ids.find(edge.first_id)
		var second := result.paddle_ids.find(edge.second_id)
		if first >= 0 and second >= 0:
			search.edges.append(Vector2i(mini(first, second), maxi(first, second)))

	if player_ids.size() == 1:
		result.owner_ids.resize(paddles.size())
		result.owner_ids.fill(player_ids[0])
	elif player_ids.size() == paddles.size():
		result.owner_ids = (
			previous.duplicate()
			if previous.size() == paddles.size() \
					and _same_players(previous, player_ids)
			else player_ids.duplicate()
		)
	else:
		search.visit(0, 0)
		for owner: int in search.best:
			result.owner_ids.append(player_ids[owner])

	for edge: TiltShiftState.Neighbor in graph:
		var first := result.paddle_ids.find(edge.first_id)
		var second := result.paddle_ids.find(edge.second_id)
		if first >= 0 and second >= 0 and result.owner_ids[first] == result.owner_ids[second]:
			result.conflicts.append(TiltShiftState.copy_neighbor(edge))
	result.minimum_conflicts = result.conflicts.size()
	return result


static func _same_players(first: PackedStringArray, second: PackedStringArray) -> bool:
	for id: String in first:
		if not second.has(id):
			return false
	return true
