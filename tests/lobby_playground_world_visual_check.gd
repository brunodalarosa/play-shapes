extends TestScript
## Captures the composed plaza lobby, empty and with ten players spread across the ground and
## every landing tier, for visual review. Run without --headless.

const OUTPUT_DIR := "res://test-results/lobby-playground-world"
const COLORS: Array[String] = [
	"#E53935",
	"#1E88E5",
	"#43A047",
	"#FBC02D",
	"#8E24AA",
	"#F57C00",
	"#00ACC1",
	"#EC407A",
	"#3949AB",
	"#8D6E63",
]
## Where each of the ten players stands, by surface name, and how far along it.
const PLACES: Array = [
	["Cafe", 0.3],
	["Cafe", 0.7],
	["ChairLeft", 0.5],
	["TableLeft", 0.3],
	["TableLeft", 0.75],
	["ChairMiddle", 0.5],
	["GroundLanding", 0.42],
	["TableRight", 0.5],
	["GroundLanding", 0.6],
	["GroundLanding", 0.25],
]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var lobby := load("res://scenes/lobby.tscn").instantiate() as Control
	root.add_child(lobby)
	await _settle(4)
	_capture("empty")

	var world: LobbyPlaygroundWorld = lobby.world
	var players: Array[Dictionary] = []
	for index: int in COLORS.size():
		players.append(
			{
				"player_id": "player-%d" % index,
				"seat": index + 1,
				"name": "Player %d" % (index + 1),
				"state": "connected",
				"character_color": COLORS[index],
			}
		)
	world.reconcile(players)
	for index: int in PLACES.size():
		var surface := world.surface_named(String(PLACES[index][0]))
		var bounds := surface.world_bounds()
		var character := world.character_for("player-%d" % index)
		character.position = Vector3(
			lerpf(bounds.position.x, bounds.end.x, float(PLACES[index][1])),
			surface.top() + 0.01,
			0.0,
		)
	world.character_for("player-6").motor.set_input(Vector2(1, 0), "move", Time.get_ticks_msec())
	world.character_for("player-2").motor.set_input(Vector2(0, -1), "crouch", Time.get_ticks_msec())
	world.character_for("player-7").motor.set_input(Vector2(0, 1), "look_up", Time.get_ticks_msec())
	await _settle(30)
	_capture("ten-players")


func _settle(frames: int) -> void:
	for _frame: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(label: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s-%dx%d.png" % [OUTPUT_DIR, label, image.get_width(), image.get_height()]
	check(image.save_png(path) == OK, "The %s capture is saved" % label)
	print("[GODOT-RUNTIME] Plaza lobby %s capture: %s" % [label, path])
