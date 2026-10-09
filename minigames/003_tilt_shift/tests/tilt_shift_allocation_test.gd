extends TestScript


func _run() -> void:
	_test_rosters_and_cycles()
	_test_rejections_and_seeds()
	_test_geometry()
	_test_graph_optimality()


func _test_rosters_and_cycles() -> void:
	for count: int in [2, 4, 6, 8, 10]:
		for seed: int in [0, 13, 71]:
			var controller := TiltShiftShiftController.new()
			root.add_child(controller)
			controller.tuning = TiltShiftFixtures.tuning(12)
			controller.set_random_seed(seed)
			if not check(
				controller.start_shift(TiltShiftFixtures.players(count), 0).accepted,
				"Every allowed roster starts",
			):
				return
			var first := controller.snapshot()
			var paddle_totals := PackedInt32Array()
			paddle_totals.resize(count)
			var previous := first
			for round_index: int in 12:
				var current := controller.snapshot()
				_check_allocation(current, count)
				for index: int in current.players.size():
					var player := current.players[index]
					check(
						player.player_id == first.players[index].player_id
						and player.team == first.players[index].team,
						"Team membership remains fixed across the shift",
					)
					paddle_totals[index] += player.paddle_ids.size()
					if count in [2, 10]:
						check(
							player.paddle_ids == first.players[index].paddle_ids,
							"One and five teammates retain fixed ownership",
						)
				if round_index > 0 and count in [4, 6, 8]:
					for team: int in 2:
						check(
							current.allocations[team].owner_ids
							!= previous.allocations[team].owner_ids,
							"Intermediate team sizes change allocation every round",
						)
				for index: int in current.paddle_layout.paddles.size():
					check(
						current.paddle_layout.paddles[index].position
						== first.paddle_layout.paddles[index].position,
						"Changing assignments never moves paddles",
					)
				previous = current
				var boundary_msec := (round_index + 1) * 1000
				check(controller.advance(boundary_msec).accepted, "Round deadline advances")
				if round_index < 11:
					check(
						controller.start_next_round((round_index + 1) * 1000).accepted,
						"The host starts the next round",
					)
			for total: int in paddle_totals:
				check(total == 120 / count, "Complete repeated cycles give equal cumulative shares")
			controller.queue_free()


func _check_allocation(snapshot: TiltShiftState.Snapshot, count: int) -> void:
	var all_paddles := PackedStringArray()
	var team_counts: Array[int] = [0, 0]
	for player: TiltShiftState.Player in snapshot.players:
		team_counts[player.team] += 1
		for paddle_id: String in player.paddle_ids:
			check(not all_paddles.has(paddle_id), "A paddle never has two owners")
			all_paddles.append(paddle_id)
			for paddle: TiltShiftPaddle in snapshot.paddle_layout.paddles:
				if paddle.paddle_id == paddle_id:
					check(paddle.team == player.team, "No player controls an opponent paddle")
	check(all_paddles.size() == 10, "All ten paddles are assigned exactly once")
	check(team_counts == [count / 2, count / 2], "Teams contain equal numbers of players")
	for allocation: TiltShiftState.Allocation in snapshot.allocations:
		var observed := PackedInt32Array()
		observed.resize(count / 2)
		for owner: String in allocation.owner_ids:
			observed[allocation.player_ids.find(owner)] += 1
		check(observed == allocation.counts, "Declared quotas match actual simultaneous ownership")
		var sorted := observed.duplicate()
		sorted.sort()
		check(sorted[sorted.size() - 1] - sorted[0] <= 1, "Counts differ by at most one teammate")
		var total := 0
		for share: int in observed:
			total += share
		check(total == 5, "Each team owns exactly five paddles")
		if count == 4:
			check(
				(
					observed == PackedInt32Array([3, 2])
					if snapshot.round_number % 2 == 1
					else observed == PackedInt32Array([2, 3])
				),
				"Four-player rounds rotate 3/2",
			)


func _test_rejections_and_seeds() -> void:
	var controller := TiltShiftShiftController.new()
	root.add_child(controller)
	for count: int in [0, 1, 3, 5, 7, 9, 11, 12]:
		check(
			not controller.start_shift(TiltShiftFixtures.players(count), 0).accepted,
			"Empty, odd and over-capacity rosters cannot start",
		)
	var malformed := TiltShiftFixtures.players(4)
	malformed[1].player_id = malformed[0].player_id
	check(not controller.start_shift(malformed, 0).accepted, "Duplicate identities are rejected")
	malformed[1] = null
	check(not controller.start_shift(malformed, 0).accepted, "Null identity is rejected")
	malformed = TiltShiftFixtures.players(4)
	malformed[0].player_id = ""
	check(not controller.start_shift(malformed, 0).accepted, "Missing identity is rejected")
	malformed = TiltShiftFixtures.players(4)
	malformed[0].seat = 0
	check(not controller.start_shift(malformed, 0).accepted, "Invalid seat is rejected")
	check(controller.snapshot().phase == &"idle", "Rejected preparation never creates live state")
	var signatures := PackedStringArray()
	for seed: int in [99, 99, 100, 101]:
		var seeded := TiltShiftShiftController.new()
		root.add_child(seeded)
		seeded.set_random_seed(seed)
		seeded.start_shift(TiltShiftFixtures.players(10), 0)
		var value := ""
		for player: TiltShiftState.Player in seeded.snapshot().players:
			value += "%s:%d:%s;" % [player.player_id, player.team, player.paddle_ids[0]]
		signatures.append(value)
	check(
		signatures[0] == signatures[1],
		"Injected seeds reproduce equal-team membership and allocation",
	)
	check(
		signatures[0] != signatures[2] or signatures[0] != signatures[3],
		"Different seeds vary initial team membership",
	)


func _test_geometry() -> void:
	var layout := TiltShiftFixtures.tuning().paddle_layout
	layout.paddles[0].position = Vector2(0.25, 0.125)
	layout.paddles[1].position = Vector2(0.25, 0.25)
	layout.paddles[2].position = Vector2(0.375, 0.125)
	layout.paddles[3].position = Vector2(0.325, 0.225)
	var graph := TiltShiftPaddleAllocator.neighbors(layout, 0.125001)
	check(
		_has_edge(graph, layout.paddles[0].paddle_id, layout.paddles[1].paddle_id),
		"Vertical neighbors count, including above and below",
	)
	check(
		_has_edge(graph, layout.paddles[0].paddle_id, layout.paddles[2].paddle_id),
		"Horizontal neighbors count at the threshold",
	)
	check(
		_has_edge(graph, layout.paddles[0].paddle_id, layout.paddles[3].paddle_id),
		"Diagonal neighbors count in the same distance units",
	)
	var narrower := TiltShiftPaddleAllocator.neighbors(layout, 0.124)
	check(
		not _has_edge(narrower, layout.paddles[0].paddle_id, layout.paddles[1].paddle_id),
		"Changing the designer threshold changes the inspected graph",
	)
	var exact := TiltShiftPaddleAllocator.neighbors(layout, 0.125)
	check(
		_has_edge(exact, layout.paddles[0].paddle_id, layout.paddles[1].paddle_id),
		"Exact center-distance equality is a neighbor",
	)


func _has_edge(graph: Array[TiltShiftState.Neighbor], first: String, second: String) -> bool:
	for edge: TiltShiftState.Neighbor in graph:
		if (edge.first_id == first and edge.second_id == second) \
				or (edge.first_id == second and edge.second_id == first):
			return true
	return false


func _test_graph_optimality() -> void:
	var paddles := TiltShiftFixtures.team_paddles(TiltShiftFixtures.tuning().paddle_layout, 0)
	var random := RandomNumberGenerator.new()
	random.seed = 345
	for mask: int in [0, 15, 31, 73, 341, 511, 682, 1023]:
		var graph := TiltShiftFixtures.graph(paddles, mask)
		for count: int in [1, 2, 3, 4, 5]:
			var ids := PackedStringArray()
			for index: int in count:
				ids.append("owner_%d" % index)
			for round_index: int in count:
				var result := TiltShiftPaddleAllocator.allocate(
					paddles,
					ids,
					round_index,
					graph,
					random,
				)
				var optimum := _oracle_minimum(result, graph)
				check(
					result.minimum_conflicts == optimum and result.conflicts.size() == optimum,
					"Adversarial neighbor graphs reach the exact count-constrained optimum",
				)
				if mask == 1023 and count == 2:
					check(
						optimum == 4,
						"Complete graph proves the four unavoidable balanced conflicts",
					)
				if mask == 0:
					check(optimum == 0, "No neighbors requires no compromise")


## Independent flat enumeration, unlike the allocator's pruned recursive search.
func _oracle_minimum(
	allocation: TiltShiftState.Allocation,
	graph: Array[TiltShiftState.Neighbor],
) -> int:
	var count := allocation.player_ids.size()
	var minimum := 11
	for code: int in int(pow(count, 5)):
		var remaining := code
		var owners := PackedInt32Array()
		var observed := PackedInt32Array()
		observed.resize(count)
		for index: int in 5:
			var owner := remaining % count
			remaining /= count
			owners.append(owner)
			observed[owner] += 1
		if observed != allocation.counts:
			continue
		var conflicts := 0
		for edge: TiltShiftState.Neighbor in graph:
			var first := allocation.paddle_ids.find(edge.first_id)
			var second := allocation.paddle_ids.find(edge.second_id)
			if owners[first] == owners[second]:
				conflicts += 1
		minimum = mini(minimum, conflicts)
	return minimum
