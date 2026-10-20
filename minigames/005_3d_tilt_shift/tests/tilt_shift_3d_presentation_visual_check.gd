extends TestScript
## Captures the shared screen for review: layout A with four players and layout B with six, each
## through preparation, the countdown, play with names showing, play after the names fade, and
## the round's end, with synthetic tilting. A last pass puts every player colour on both teams.
## Run without --headless.

const SCENE := preload("res://minigames/005_3d_tilt_shift/tilt_shift_3d_presentation.tscn")
const Driver := preload(
	"res://minigames/005_3d_tilt_shift/tests/tilt_shift_3d_physics_cost_check.gd"
)
const OUTPUT := "res://test-results/tilt-shift-3d/presentation/"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	await _round(0, 4, 0, "layout-a-4")
	await _round(1, 6, 0, "layout-b-6")
	await _round(0, 10, 5, "colours-a")
	await _round(1, 10, 3, "colours-b")


func _round(layout_index: int, count: int, colour_offset: int, prefix: String) -> void:
	var presentation := SCENE.instantiate() as TiltShift3DPresentation
	root.add_child(presentation)
	var source: TiltShift3DTuning = load("res://minigames/005_3d_tilt_shift/tuning/Default.tres")
	var profile: TiltShift3DTuning = source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	profile.layouts_by_round = [profile.layouts_by_round[layout_index]]
	profile.baskets_by_round.resize(1)
	profile.round_count = 1
	profile.round_duration_seconds = 12.0
	profile.physics.delivery_cutoff_seconds = 2.0
	profile.physics.use_position_seed = true
	profile.physics.position_seed = 749
	var players := TiltShift3DFixtures.players(count)
	var colours := CharacterSelection.COLORS
	for index: int in players.size():
		var colour: Dictionary = colours[(index + colour_offset) % colours.size()]
		players[index].character_color = String(colour.hex)
		players[index].player_name = "Player %d" % (index + 1)
	check(presentation.start_shift(profile, players).accepted, "%s launches" % prefix)
	await _capture(prefix + "-1-preparation.png")
	var controller := presentation.arena.controller
	controller.force_start(controller.snapshot().round_token, Time.get_ticks_msec())
	await create_timer(1.0).timeout
	await _capture(prefix + "-2-countdown.png")
	while controller.snapshot().phase != &"active":
		await process_frame
	var state := controller.snapshot()
	var controls := Driver.Controls.new()
	controls.arena = presentation.arena
	for player: TiltShift3DState.Player in state.players:
		if player.selected:
			controls.players.append(player)
	controls.token = state.round_token
	controls.started = state.started_at_msec
	root.add_child(controls)
	await create_timer(3.0).timeout
	await _capture(prefix + "-3-play-names.png")
	await create_timer(4.0).timeout
	await _capture(prefix + "-4-play.png")
	while controller.snapshot().phase == &"active":
		await process_frame
	await create_timer(0.5).timeout
	await _capture(prefix + "-5-round-end.png")
	controls.queue_free()
	presentation.stop()
	presentation.queue_free()
	await process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := OUTPUT + name
	check(image.save_png(path) == OK, "%s is saved" % name)
	print("[GODOT-RUNTIME] Tilt Shift 3D capture: %s" % path)
