extends TestScript

const SCENE: PackedScene = preload("res://scenes/pre_minigame_screen.tscn")


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
	screen.configure(&"bubbles_3d", { "players": roster })
	var content: PreMinigameContent = screen._content
	var image := content.preview.get_image()
	var okay: bool = (
		content.title == "Bubbles and jellyfishes 3D"
		and not content.controls.is_empty() and not content.win_condition.is_empty()
		and not content.hints.is_empty() and image.get_width() == 1920
		and image.get_height() == 1080 and screen._tray.get_child_count() == 10
		and screen._tray.get_child(0).get_child(0).text == "Ready!"
		and screen._tray.get_child(1).get_child(0).text == ""
	)
	check(okay, "Reusable screen content, preview, or ordered tray failed")
	check(
		screen._characters._characters.size() == 10 and screen._characters.get_child_count() == 1,
		"Ten live characters share one isolated preview viewport",
	)
	var first: Cubio3D = screen._characters._characters["p0"]
	roster[0].ready = false
	roster[0].character_color = "#EC407A"
	screen.set_snapshot({ "players": roster })
	check(
		screen._characters._characters["p0"] == first and first.player_color == Color("#EC407A"),
		"Ready changes preserve live instances and refresh the registered tint",
	)
	screen.set_snapshot({ "players": [roster[1]] })
	check(
		screen._characters._characters.size() == 1 and screen._characters._characters.has("p1"),
		"Leaving players are removed from the live preview",
	)
	screen.queue_free()
	await process_frame
	await _check_booklet_pages()


func _check_booklet_pages() -> void:
	var screen := SCENE.instantiate() as PreMinigameScreen
	root.add_child(screen)
	screen.configure(&"tilt_shift_3d", { "players": [] })
	await _settle()
	check(_sections_stay_apart(screen), "Tilt Shift's booklet sections do not overlap")

	screen._controls.text = "Hold the phone steady. ".repeat(30).strip_edges()
	await _settle()
	var inner := screen._booklet_scroll.get_v_scroll_bar()
	check(_sections_stay_apart(screen), "Long booklet sections still do not overlap")
	check(inner.max_value > inner.page, "Long booklet text overflows into a scrollable page")
	var page := screen._booklet_scroll.get_global_rect()
	for body: Label in [screen._controls, screen._win, screen._hints]:
		var rect := body.get_global_rect()
		check(
			rect.position.x >= page.position.x and rect.end.x <= page.end.x,
			"Booklet text stays within the page width",
		)
	check(
		screen._booklet_bar.mouse_filter == Control.MOUSE_FILTER_STOP,
		"The binding becomes a usable scroll bar when the text overflows",
	)
	screen._booklet_bar.value = 120.0
	check(screen._booklet_scroll.scroll_vertical == 120, "Dragging the binding scrolls the page")
	screen._booklet_scroll.scroll_vertical = 60
	await _settle()
	check(is_equal_approx(screen._booklet_bar.value, 60.0), "Scrolling the page moves the binding")
	screen.queue_free()
	await process_frame


func _sections_stay_apart(screen: PreMinigameScreen) -> bool:
	var bodies: Array[Label] = [screen._controls, screen._win, screen._hints]
	for index: int in range(1, bodies.size()):
		var previous := bodies[index - 1].get_global_rect()
		var heading := bodies[index].get_parent().get_child(0) as Label
		if heading.get_global_rect().position.y < previous.end.y:
			return false
	return true


func _settle() -> void:
	for _frame: int in 3:
		await process_frame
