extends TestScript
## Invisible side walls stop a character with its centre on the screen edge at both 16:9 host
## sizes, and follow the view when the window is resized.

const WORLD := preload("res://scenes/lobby_playground_world.tscn")
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]
## Long enough to cross the whole plaza at top speed.
const RUN_FRAMES := 480
## How far from the exact edge, as a share of screen width, the stopped centre may land.
const EDGE_TOLERANCE := 0.02


func _run() -> void:
	for size: Vector2i in SIZES:
		await _check_size(size)


func _check_size(size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	root.add_child(viewport)
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	viewport.add_child(world)
	world.reconcile(
		[
			{
				"player_id": "runner",
				"seat": 5,
				"name": "Runner",
				"state": "connected",
				"character_color": "#F57C00",
			},
		]
	)
	var runner := world.character_for("runner")
	for direction: float in [-1.0, 1.0]:
		for _frame: int in RUN_FRAMES:
			runner.motor.set_input(Vector2(direction, 0.0), "move", Time.get_ticks_msec())
			await physics_frame
		var centre := LobbyPlaygroundWorld.to_world(runner.position + Vector2(0.0, -48.0))
		var screen_x := world.camera.unproject_position(centre).x
		var edge := 0.0 if direction < 0.0 else float(size.x)
		check(
			runner.is_on_floor() and absf(screen_x - edge) <= size.x * EDGE_TOLERANCE,
			"Running %s at %s stops with the centre on the screen edge (%.0f)"
			% ["left" if direction < 0.0 else "right", size, screen_x],
		)
	runner.clear_input()

	var narrow := Vector2i(size.x / 2, size.y)
	viewport.size = narrow
	await process_frame
	var left_wall := world.get_node("Simulation/PlatformSurfaces/LeftWall") as Node2D
	var stop := LobbyPlaygroundWorld.BODY_HALF_WIDTH + LobbyPlaygroundWorld.WALL_THICKNESS * 0.5
	var height := Vector2(
		0.0,
		-LobbyPlaygroundWorld.WALL_FIT_HEIGHT * LobbyPlaygroundWorld.PIXELS_PER_UNIT,
	)
	var stopped := LobbyPlaygroundWorld.to_world(left_wall.position + Vector2(stop, 0.0) + height)
	check(
		absf(world.camera.unproject_position(stopped).x) <= narrow.x * EDGE_TOLERANCE,
		"Narrowing the view at %s brings the walls in with it" % size,
	)
	viewport.queue_free()
	await process_frame
