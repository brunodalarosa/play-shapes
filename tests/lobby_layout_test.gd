extends SceneTree
## Structural and overflow checks for the two-section host lobby at 16:9.

const FHD_CANVAS_SIZE := Vector2i(1920, 1080)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	# canvas_items keeps the 1920x1080 logical canvas when the host window is
	# resized to 1152x648, so bounds are checked in the effective canvas space.
	viewport.size = FHD_CANVAS_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var lobby := load("res://scenes/lobby.tscn").instantiate() as Control
	viewport.add_child(lobby)
	await process_frame
	await process_frame

	_check(lobby.get_node_or_null("Scroll") == null,
		"[AUTO] Lobby has no page-level scroll container")
	var title := lobby.get_node("PageMargin/Page/Title") as Label
	_check(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"[AUTO] PLAY SHAPES remains horizontally centered")
	_check(title.get_theme_color("font_color").g > title.get_theme_color("font_color").r,
		"[AUTO] PLAY SHAPES retains its green emphasis")
	_check(title.get_theme_font_size("font_size") == 44 and title.get_global_rect().position.y >= 48.0,
		"[AUTO] PLAY SHAPES uses the larger title size and safe top margin")
	var sections := lobby.get_node("PageMargin/Page/Sections") as HBoxContainer
	_check(sections.get_child_count() == 2
		and sections.get_child(0).name == &"JoinSection"
		and sections.get_child(1).name == &"PlayerSection",
		"[AUTO] Join and player content are ordered as two horizontal sections")
	_check(_visible_controls_fit(lobby, FHD_CANVAS_SIZE),
		"[AUTO] Empty lobby controls fit inside the FHD canvas")
	var refresh := lobby.get_node("%Refresh") as Button
	var copy := lobby.get_node("%Copy") as Button
	var start := lobby.get_node("%StartMinigame") as Button
	_check(refresh.size.y >= 52.0 and copy.size.y >= 52.0 and start.size.y >= 60.0,
		"[AUTO] Lobby actions use the taller button treatment")
	_check(start.size.x == 360.0 and start.get_global_rect().get_center().x > FHD_CANVAS_SIZE.x * 0.5,
		"[AUTO] Start action is fixed-width and centered in the player section")

	var host := root.get_node("SessionHost")
	for index: int in 20:
		var joined: Dictionary = host.player_registry.join_player(
			1000 + index, "Player %02d" % (index + 1), true, 1000 + index)
		_check(bool(joined.accepted), "[AUTO] Representative player %d joins" % (index + 1))
	await process_frame
	await process_frame
	var roster := lobby.get_node("%PlayerRoster") as GridContainer
	_check(roster.columns == 2 and roster.get_child_count() == 20,
		"[AUTO] Maximum roster uses two readable columns")
	_check(_visible_controls_fit(lobby, FHD_CANVAS_SIZE),
		"[AUTO] Maximum roster controls fit inside the FHD canvas")

	viewport.queue_free()
	print("Lobby layout checks passed on the FHD canvas with empty and 20-player states")
	quit(0)

func _visible_controls_fit(lobby: Control, viewport_size: Vector2i) -> bool:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	for node: Node in lobby.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if not viewport_rect.encloses(rect):
			push_error("%s exceeds the viewport: %s" % [control.get_path(), rect])
			return false
	return true

func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
