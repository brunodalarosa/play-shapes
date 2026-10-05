extends TestScript
## Controller-only timing evidence, separate from machine-independent correctness checks.


func _run() -> void:
	var directory := "res://test-results/tilt-shift"
	DirAccess.make_dir_recursive_absolute(directory)
	_write_assignments(directory)
	var file := FileAccess.open(directory.path_join("cost.txt"), FileAccess.WRITE)
	var machine := "%s; Godot %s" % [OS.get_processor_name(), Engine.get_version_info().string]
	print(machine)
	file.store_line(machine)
	for threshold: float in [0.24, 2.0]:
		for count: int in [4, 6, 8, 10]:
			var transitions: Array[int] = []
			var assignments: Array[int] = []
			var profile := TiltShiftFixtures.tuning(2)
			profile.neighbor_distance = threshold
			var graph := TiltShiftPaddleAllocator.neighbors(profile.paddle_layout, threshold)
			var paddles := TiltShiftFixtures.team_paddles(profile.paddle_layout, 0)
			var ids := PackedStringArray()
			for index: int in count / 2:
				ids.append("player_%d" % index)
			var random := RandomNumberGenerator.new()
			random.seed = 8
			var initial := TiltShiftPaddleAllocator.allocate(paddles, ids, 0, graph, random)
			var previous := initial.owner_ids
			for iteration: int in 220:
				var controller := TiltShiftShiftController.new()
				controller.tuning = profile
				controller.set_random_seed(iteration)
				var started := controller.start_shift(TiltShiftFixtures.players(count), 0)
				if not check(started.accepted, "Cost workload starts with valid content"):
					controller.free()
					return
				var before := Time.get_ticks_usec()
				controller.advance(1000)
				controller.start_next_round(1000)
				var elapsed := Time.get_ticks_usec() - before
				controller.free()
				before = Time.get_ticks_usec()
				var allocation := TiltShiftPaddleAllocator.allocate(
					paddles,
					ids,
					1,
					graph,
					random,
					previous,
				)
				var assignment_elapsed := Time.get_ticks_usec() - before
				if not check(allocation != null, "Assignment workload returns a valid allocation"):
					return
				if iteration >= 20:
					transitions.append(elapsed)
					assignments.append(assignment_elapsed)
			var context := "%d players, distance %.2f" % [count, threshold]
			var assignment_line := "%s; one-team assignment %s" % [context, _timings(assignments)]
			var transition_line := "%s; both-team transition %s" % [context, _timings(transitions)]
			print(assignment_line)
			print(transition_line)
			file.store_line(assignment_line)
			file.store_line(transition_line)
	file.close()


func _timings(samples: Array[int]) -> String:
	samples.sort()
	return "median=%d us p95=%d us max=%d us n=%d" % [
		samples[samples.size() / 2],
		samples[ceili(samples.size() * 0.95) - 1],
		samples.back(),
		samples.size(),
	]


func _write_assignments(directory: String) -> void:
	var report := FileAccess.open(directory.path_join("assignments.md"), FileAccess.WRITE)
	report.store_line("# Tilt Shift allocation diagnostics\n")
	report.store_line("Synthetic four-round samples, seed 72, default layout and distance 0.24.")
	report.store_line("The neighbor graph measures center distance in arena-width units.")
	report.store_line("Physics, phone input and strategic fairness are not demonstrated.\n")
	var profile := TiltShiftFixtures.tuning()
	var graph := TiltShiftPaddleAllocator.neighbors(
		profile.paddle_layout,
		profile.neighbor_distance,
	)
	report.store_line("## Neighbor pairs\n")
	report.store_line("| First paddle | Second paddle | Distance |\n| --- | --- | --- |")
	for edge: TiltShiftState.Neighbor in graph:
		report.store_line("| %s | %s | %.5f |" % [edge.first_id, edge.second_id, edge.distance])
	for count: int in [2, 4, 6, 8, 10]:
		var controller := TiltShiftShiftController.new()
		controller.tuning = profile
		controller.set_random_seed(72)
		controller.start_shift(TiltShiftFixtures.players(count), 0)
		report.store_line("\n## %d players\n" % count)
		report.store_line("| Round | Team | Player | Simultaneous paddles | Paddle IDs |")
		report.store_line("| --- | --- | --- | --- | --- |")
		for round_index: int in 4:
			var snapshot := controller.snapshot()
			for player: TiltShiftState.Player in snapshot.players:
				var team := "Orange" if player.team == 0 else "Blue"
				report.store_line(
					"| %d | %s | %s | %d | %s |"
					% [
						snapshot.round_number,
						team,
						player.player_id,
						player.paddle_ids.size(),
						", ".join(player.paddle_ids),
					]
				)
			controller.advance((round_index + 1) * 1000)
			if round_index < 3:
				controller.start_next_round((round_index + 1) * 1000)
		controller.free()
		report.store_line("\n| Round | Team | Minimum conflicts | Conflicting pairs |")
		report.store_line("| --- | --- | --- | --- |")
		controller = TiltShiftShiftController.new()
		controller.tuning = profile
		controller.set_random_seed(72)
		controller.start_shift(TiltShiftFixtures.players(count), 0)
		for round_index: int in 4:
			var snapshot := controller.snapshot()
			for team: int in 2:
				var allocation := snapshot.allocations[team]
				var conflicts := PackedStringArray()
				for edge: TiltShiftState.Neighbor in allocation.conflicts:
					conflicts.append("%s / %s" % [edge.first_id, edge.second_id])
				report.store_line(
					"| %d | %s | %d | %s |"
					% [
						snapshot.round_number,
						"Orange" if team == 0 else "Blue",
						allocation.minimum_conflicts,
						"; ".join(conflicts),
					]
				)
			controller.advance((round_index + 1) * 1000)
			if round_index < 3:
				controller.start_next_round((round_index + 1) * 1000)
		controller.free()
	report.close()
