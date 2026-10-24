extends TestScript
## Measures the host cost of ten Playground characters on Jolt: every motor's physics callback,
## including its move and its one-way checks, while all ten run back and forth and jump through
## the landings. Run with --headless on the target PC.

const WORLD := preload("res://scenes/lobby_playground_world.tscn")
const SAMPLE_STEPS := 1200


class StepClock:
	extends Node
	var began := 0
	var steps: Array[float] = []
	## The clock that opens each step; empty for the opening clock itself.
	var opening: StepClock


	func _physics_process(_delta: float) -> void:
		if opening == null:
			began = Time.get_ticks_usec()
		else:
			steps.append(float(Time.get_ticks_usec() - opening.began) / 1000.0)


func _run() -> void:
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	root.add_child(world)
	var players: Array[Dictionary] = []
	for index: int in 10:
		players.append(
			{
				"player_id": "p%d" % index,
				"seat": index + 1,
				"name": "Player %d" % (index + 1),
				"state": "connected",
				"character_color": "#1E88E5",
			}
		)
	world.reconcile(players)
	var start := StepClock.new()
	start.process_physics_priority = -1000
	var finish := StepClock.new()
	finish.opening = start
	finish.process_physics_priority = 1000
	root.add_child(start)
	root.add_child(finish)

	for step: int in SAMPLE_STEPS:
		for index: int in 10:
			var character := world.character_for("p%d" % index)
			# Each runs a different stretch and jumps whenever it can, so landings are crossed.
			var direction := 1.0 if (step / (60 + index * 7)) % 2 == 0 else -1.0
			character.motor.set_input(Vector2(direction, 0.0), "move", Time.get_ticks_msec())
			character.motor.request_jump()
		await physics_frame

	var samples: Array[float] = finish.steps.slice(60)
	samples.sort()
	var total := 0.0
	for sample: float in samples:
		total += sample
	var average := total / samples.size()
	var slow: float = samples[floori(samples.size() * 0.95)]
	print(
		"[GODOT-RUNTIME] Playground lobby, 10 characters on Jolt: physics callbacks average "
		+ "%.3f ms a step, 95th percentile %.3f ms, worst %.3f ms over %d steps; %s"
		% [average, slow, samples[-1], samples.size(), OS.get_processor_name()]
	)
	check(samples.size() > SAMPLE_STEPS - 100, "Enough physics steps were measured")
	start.queue_free()
	finish.queue_free()
	world.queue_free()
	await process_frame
