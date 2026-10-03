extends SceneTree

const SCENE: PackedScene = preload("res://scenes/pre_minigame_screen.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var screen := SCENE.instantiate() as PreMinigameScreen
	root.add_child(screen)
	var roster: Array[Dictionary] = []
	for index: int in 10:
		roster.append(
			{
				"player_id": "p%d" % index,
				"name": "Player %d" % index,
				"seat": index + 1,
				"character_color": "#598DF2",
				"ready": index % 2 == 0,
			}
		)
	screen.configure(&"bubbles", { "players": roster })
	var content: PreMinigameContent = screen._content
	var image := content.preview.get_image()
	var okay: bool = (
		content.title == "Bubbles and jellyfishes" and not content.controls.is_empty()
		and not content.win_condition.is_empty() and not content.hints.is_empty()
		and image.get_width() == 1920 and image.get_height() == 1080
		and screen._tray.get_child_count() == 10
		and screen._tray.get_child(0).get_child(0).text == "Ready!"
		and screen._tray.get_child(1).get_child(0).text == ""
	)
	if not okay:
		push_error("Reusable screen content, preview, or ordered tray failed")
	quit(0 if okay else 1)
