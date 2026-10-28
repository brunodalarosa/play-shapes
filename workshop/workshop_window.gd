class_name WorkshopWindow
extends VBoxContainer
## The shared workshop window: a top bar for presets and the preset the game uses, and four
## named panels, 1 Shared screen, 2 Phone view, 3 Minigame flow and 4 Tunables, with grips
## between them. Any panel can pop out into its own window; the layout is remembered.
##
## A minigame's workshop scene builds one with [method setup], fills the first three panels and
## restarts its game on [signal restart_requested]. The Tunables panel comes from the preset.
## It wears [WorkshopTheme], Material Design 3's dark scheme.

## Restart the game with [member WorkshopTuning.running].
signal restart_requested
## A key the window does not use, from it or a popped-out panel.
signal key_pressed(event: InputEventKey)

var tuning: WorkshopTuning
var presets: WorkshopPresets
var game_preset: WorkshopGamePreset
var layout: WorkshopLayout
var preset_name := WorkshopPresets.DEFAULT_NAME
## Shown at the left of the top bar, such as "Flappy Race workshop".
var title := "Workshop"
var shared_screen := WorkshopDockablePanel.new(1, "Shared screen")
var phone_view := WorkshopDockablePanel.new(2, "Phone view")
var flow := WorkshopDockablePanel.new(3, "Minigame flow")
var tunables := WorkshopDockablePanel.new(4, "Tunables")
var tunables_panel: WorkshopTunablesPanel
var top_split := HSplitContainer.new()
var bottom_split := HSplitContainer.new()
var rows_split := VSplitContainer.new()
var preset_picker := OptionButton.new()
## The preset the game uses, as a chip.
var game_label := Label.new()
var use_button := Button.new()
var status := Label.new()
var dialog := ConfirmationDialog.new()
var _preset_menu := MenuButton.new()
var _copy_menu := PopupMenu.new()
var _edits := Label.new()
var _save := Button.new()
var _undo := Button.new()
var _redo := Button.new()
var _revert := Button.new()
var _windows := Node.new()
var _dialog_text := Label.new()
var _dialog_name := LineEdit.new()
var _dialog_action := Callable()


func _init() -> void:
	name = "WorkshopWindow"
	theme = WorkshopTheme.theme()
	WorkshopTheme.fill(self, 10)
	add_theme_constant_override(&"separation", 10)
	# A control grows past its parent while its minimum is large, as wrapping labels are before
	# their first layout, and does not shrink back by itself.
	minimum_size_changed.connect(_refit, CONNECT_DEFERRED)


func _refit() -> void:
	WorkshopTheme.fill(self, 10)


func _draw() -> void:
	# The background reaches past the window's margin to the edges.
	draw_rect(Rect2(-position, get_parent_area_size()), WorkshopTheme.SURFACE)


## Opens [param preset_to_edit] from [param workshop_presets], the minigame's presets, whose
## [param active_field] entry in Active Presets says which one the game uses.
func setup(
	workshop_id: String,
	workshop_presets: WorkshopPresets,
	active_field: String,
	preset_to_edit := "",
	active_presets_path := WorkshopGamePreset.ACTIVE_PRESETS_PATH,
) -> void:
	presets = workshop_presets
	game_preset = WorkshopGamePreset.new(active_field, active_presets_path)
	layout = WorkshopLayout.new(workshop_id)
	if preset_to_edit.is_empty():
		var used := game_preset.current_path()
		preset_to_edit = used.get_file().get_basename() if presets.has(_name_of(used)) else ""
	if preset_to_edit.is_empty() or not presets.has(preset_to_edit):
		preset_to_edit = WorkshopPresets.DEFAULT_NAME
	preset_name = preset_to_edit
	var reference := presets.load_preset(WorkshopPresets.DEFAULT_NAME)
	tuning = WorkshopTuning.new(presets.load_preset(preset_name), reference)
	tuning.changed.connect(_refresh)

	_build_top_bar()
	_build_panels()
	_build_dialog()
	add_child(_windows)
	_windows.name = "Windows"
	_refresh()
	_restore_layout.call_deferred()


func panels() -> Array[WorkshopDockablePanel]:
	return [shared_screen, phone_view, flow, tunables]


## Edits [param name] instead, after a confirmation when edits would be lost.
func open_preset(name: String) -> void:
	var switch := func() -> void:
		preset_name = name
		tuning.load_preset(presets.load_preset(name))
		_refresh()
	_confirm_unless_clean(
		"Open %s and drop %d unsaved edits?" % [name, tuning.edit_count()],
		switch,
	)


## Writes the edited values to the preset's file. Saving over Default asks a second time.
func save_preset() -> void:
	if preset_name == WorkshopPresets.DEFAULT_NAME and tuning.edit_count() > 0:
		_ask("Save over Default, the preset every new one starts from?", _write_preset)
	else:
		_write_preset()


func save_preset_as(name: String) -> String:
	if presets.has(name):
		return "A preset named %s already exists." % name
	var problem := presets.save(tuning.edited, name)
	if problem.is_empty():
		preset_name = name
		tuning.mark_saved()
		_set_status("Saved as %s." % name)
	return problem


## Makes the game use the saved preset, after a confirmation listing what changes.
func use_in_game() -> void:
	if tuning.edit_count() > 0:
		_set_status("Save %s first; the game uses saved presets." % preset_name)
		return
	if not tuning.errors().is_empty():
		_set_status("%s has errors; fix them before the game uses it." % preset_name)
		return
	var used_path := game_preset.current_path()
	var used: Resource = (
		WorkshopTuning.copy(ResourceLoader.load(used_path, "", ResourceLoader.CACHE_MODE_IGNORE))
		if not used_path.is_empty() and FileAccess.file_exists(used_path)
		else tuning.reference
	)
	var lines := tuning.describe_differences(used, tuning.saved)
	var question := "The game will use %s instead of %s.\n\n%s" % [
		preset_name,
		_name_of(used_path),
		"\n".join(lines) if not lines.is_empty() else "No value changes.",
	]
	_ask(question + "\n\nCommit Tuning/Active Presets.tres afterwards.", _write_game_preset)


## Restores every panel into this window and the grips to the middle.
func reset_layout() -> void:
	for panel: WorkshopDockablePanel in panels():
		panel.dock()
	for split: SplitContainer in [top_split, bottom_split, rows_split]:
		split.split_offset = 0
	layout.clear()
	_set_status("Layout reset.")


func save_layout() -> void:
	if layout == null:
		return
	var splits: Dictionary[String, int] = {
		"top": top_split.split_offset,
		"bottom": bottom_split.split_offset,
		"rows": rows_split.split_offset,
	}
	layout.save(splits, panels())


func _build_top_bar() -> void:
	var surface := PanelContainer.new()
	surface.name = "TopBar"
	surface.theme_type_variation = &"TopBar"
	add_child(surface)
	var bar := HBoxContainer.new()
	surface.add_child(bar)
	var heading := Label.new()
	heading.text = title
	heading.theme_type_variation = &"TitleLabel"
	bar.add_child(heading)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	bar.add_child(gap)
	preset_picker.custom_minimum_size = Vector2(200, 0)
	preset_picker.tooltip_text = "The preset being edited"
	preset_picker.item_selected.connect(
		func(index: int) -> void:
			open_preset(preset_picker.get_item_text(index)),
	)
	bar.add_child(preset_picker)
	_preset_menu.text = "⋯"
	_preset_menu.tooltip_text = "Duplicate, rename, delete or copy a tab"
	var menu := _preset_menu.get_popup()
	menu.add_item("Duplicate…", 0)
	menu.add_item("Rename…", 1)
	menu.add_item("Delete…", 2)
	_copy_menu.name = "CopyTab"
	menu.add_child(_copy_menu)
	menu.add_submenu_node_item("Copy a tab from", _copy_menu)
	menu.id_pressed.connect(_on_preset_menu)
	_copy_menu.index_pressed.connect(_on_copy_tab)
	bar.add_child(_preset_menu)
	_edits.theme_type_variation = &"CautionChip"
	_edits.uppercase = true
	_edits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_edits)
	for button: Button in [_save, _undo, _redo, _revert]:
		bar.add_child(button)
	_save.text = "Save"
	_save.pressed.connect(save_preset)
	var save_as := Button.new()
	save_as.text = "Save as…"
	save_as.pressed.connect(_ask_name.bind("Save as", "", save_preset_as))
	bar.add_child(save_as)
	bar.move_child(save_as, _save.get_index() + 1)
	_revert.text = "Revert"
	_revert.pressed.connect(
		func() -> void:
			_ask("Drop %d unsaved edits?" % tuning.edit_count(), tuning.revert),
	)
	_undo.text = "Undo"
	_undo.theme_type_variation = &"TextButton"
	_undo.pressed.connect(tuning.undo_edit)
	_redo.text = "Redo"
	_redo.theme_type_variation = &"TextButton"
	_redo.pressed.connect(tuning.redo_edit)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.add_child(status)
	status.theme_type_variation = &"HelpLabel"
	var uses := Label.new()
	uses.text = "Game uses"
	uses.theme_type_variation = &"BodyLabel"
	bar.add_child(uses)
	game_label.theme_type_variation = &"QuietChip"
	game_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(game_label)
	use_button.theme_type_variation = &"FilledButton"
	use_button.pressed.connect(use_in_game)
	bar.add_child(use_button)
	var reset := Button.new()
	reset.theme_type_variation = &"TextButton"
	reset.text = "Reset layout"
	reset.pressed.connect(reset_layout)
	bar.add_child(reset)


func _build_panels() -> void:
	rows_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_split.name = "Rows"
	add_child(rows_split)
	for split: HSplitContainer in [top_split, bottom_split]:
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rows_split.add_child(split)
		split.dragged.connect(
			func(_offset: int) -> void:
				save_layout(),
		)
	rows_split.dragged.connect(
		func(_offset: int) -> void:
			save_layout(),
	)
	top_split.name = "Top"
	bottom_split.name = "Bottom"
	top_split.add_child(shared_screen)
	top_split.add_child(phone_view)
	bottom_split.add_child(flow)
	bottom_split.add_child(tunables)
	shared_screen.size_flags_stretch_ratio = 2.0
	tunables.size_flags_stretch_ratio = 1.3
	tunables_panel = WorkshopTunablesPanel.new(tuning)
	tunables_panel.restart_requested.connect(restart_requested.emit)
	tunables.set_body(tunables_panel)
	for panel: WorkshopDockablePanel in panels():
		panel.window_host = _windows
		panel.popped_changed.connect(_on_popped_changed)


func _build_dialog() -> void:
	dialog.name = "Dialog"
	dialog.min_size = Vector2i(460, 160)
	var column := VBoxContainer.new()
	dialog.add_child(column)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(440, 0)
	column.add_child(_dialog_text)
	column.add_child(_dialog_name)
	dialog.confirmed.connect(_on_dialog_confirmed)
	dialog.register_text_enter(_dialog_name)
	add_child(dialog)


func _refresh() -> void:
	if tuning == null:
		return
	preset_picker.clear()
	var names := presets.names()
	for index: int in names.size():
		preset_picker.add_item(names[index])
		if names[index] == preset_name:
			preset_picker.select(index)
	_copy_menu.clear()
	for name: String in names:
		if name != preset_name:
			_copy_menu.add_item(name)
	var count := tuning.edit_count()
	_edits.text = "Edited · %d" % count
	_edits.visible = count > 0
	var valid := tuning.errors().is_empty()
	_save.disabled = count == 0 or not valid
	_revert.disabled = count == 0
	_undo.disabled = not tuning.can_undo()
	_redo.disabled = not tuning.can_redo()
	var used := _name_of(game_preset.current_path())
	game_label.text = used
	use_button.text = "Use %s in the game" % preset_name
	use_button.disabled = used == preset_name or count > 0 or not valid


func _write_preset() -> void:
	var problem := presets.save(tuning.edited, preset_name)
	if problem.is_empty():
		tuning.mark_saved()
		_set_status("Saved %s." % preset_name)
	else:
		_set_status(problem)


func _write_game_preset() -> void:
	var problem := game_preset.use(presets.path(preset_name))
	_set_status(problem if not problem.is_empty() else "The game now uses %s." % preset_name)
	_refresh()


func _on_preset_menu(id: int) -> void:
	match id:
		0:
			_ask_name(
				"Duplicate %s as" % preset_name,
				"%s copy" % preset_name,
				func(new_name: String) -> String:
					var problem := presets.duplicate_preset(preset_name, new_name)
					if problem.is_empty():
						open_preset(new_name)
					return problem,
			)
		1:
			_ask_name(
				"Rename %s to" % preset_name,
				preset_name,
				func(new_name: String) -> String:
					var used := game_preset.current_path()
					var problem := presets.rename(preset_name, new_name, used)
					if problem.is_empty():
						preset_name = new_name
						_refresh()
					return problem,
			)
		2:
			_ask(
				"Delete %s? Its file is removed from the project." % preset_name,
				func() -> void:
					var problem := presets.delete(preset_name, game_preset.current_path())
					if problem.is_empty():
						preset_name = WorkshopPresets.DEFAULT_NAME
						tuning.load_preset(presets.load_preset(preset_name))
					_set_status(problem if not problem.is_empty() else "Deleted."),
			)


func _on_copy_tab(index: int) -> void:
	var source_name := _copy_menu.get_item_text(index)
	var source := presets.load_preset(source_name)
	var parts := PackedStringArray()
	for tunable: WorkshopTunable in tuning.tunables:
		if not tunable.part.is_empty() and not parts.has(tunable.part):
			parts.append(tunable.part)
	var tab := tunables_panel.get_child(1) as TabContainer
	var current := tab.get_current_tab_control().name.to_lower() if tab != null else ""
	if not parts.has(current):
		_set_status("Open the tab to copy first, then copy it from %s." % source_name)
		return
	tuning.copy_part(source, current)
	_set_status("Copied %s from %s." % [current.capitalize(), source_name])


func _ask(question: String, action: Callable) -> void:
	_dialog_text.text = question
	_dialog_name.visible = false
	_dialog_action = action
	dialog.title = "Workshop"
	dialog.popup_centered()


## Asks for a preset name, then calls [param action] with it; a returned message keeps asking.
func _ask_name(question: String, suggestion: String, action: Callable) -> void:
	_dialog_text.text = question
	_dialog_name.visible = true
	_dialog_name.text = suggestion
	_dialog_action = action
	dialog.title = "Preset name"
	dialog.popup_centered()
	_dialog_name.grab_focus()
	_dialog_name.select_all()


func _on_dialog_confirmed() -> void:
	if not _dialog_name.visible:
		_dialog_action.call()
		return
	var problem: Variant = _dialog_action.call(_dialog_name.text.strip_edges())
	if problem is String and not problem.is_empty():
		_set_status(problem)
	_refresh()


func _confirm_unless_clean(question: String, action: Callable) -> void:
	if tuning.edit_count() == 0:
		action.call()
	else:
		_ask(question, action)
		_refresh()


func _set_status(text: String) -> void:
	status.text = text


func _on_popped_changed(panel: WorkshopDockablePanel) -> void:
	if panel.window != null:
		panel.window.window_input.connect(_on_window_input)
	for split: HSplitContainer in [top_split, bottom_split]:
		split.visible = split.get_children().any(
			func(child: Node) -> bool:
				return child is WorkshopDockablePanel,
		)
	save_layout()


func _restore_layout() -> void:
	var splits := layout.splits()
	top_split.split_offset = splits.get("top", 0)
	bottom_split.split_offset = splits.get("bottom", 0)
	rows_split.split_offset = splits.get("rows", 0)
	var popped := layout.popped()
	for panel: WorkshopDockablePanel in panels():
		if popped.has(panel.number):
			var state: Dictionary = popped[panel.number]
			panel.pop_out(state.rect, state.screen, state.mode)


func _unhandled_key_input(event: InputEvent) -> void:
	_handle_key(event)


func _on_window_input(event: InputEvent) -> void:
	_handle_key(event)


func _handle_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if key.keycode == KEY_Z and key.is_command_or_control_pressed() and key.shift_pressed:
		tuning.redo_edit()
	elif key.keycode == KEY_Z and key.is_command_or_control_pressed():
		tuning.undo_edit()
	elif key.keycode == KEY_Y and key.is_command_or_control_pressed():
		tuning.redo_edit()
	elif key.keycode == KEY_S and key.is_command_or_control_pressed():
		save_preset()
	elif key.keycode == KEY_R and not key.is_command_or_control_pressed():
		restart_requested.emit()
	else:
		key_pressed.emit(key)
		return
	get_viewport().set_input_as_handled()


func _name_of(path: String) -> String:
	return path.get_file().get_basename() if not path.is_empty() else "nothing"


func _exit_tree() -> void:
	save_layout()
