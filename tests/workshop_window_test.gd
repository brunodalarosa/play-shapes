extends TestScript
## The workshop window: editing through a Tunables row, saving with a second question over
## Default, using a preset in the game, popping a panel out and back, and the layout it keeps.

const FOLDER := "res://test-results/workshop/window_presets"
const ACTIVE_COPY := "res://test-results/workshop/window_active_presets.tres"
const SOURCE := "res://minigames/006_flappy_race/tuning/Default.tres"
const WORKSHOP_ID := "workshop_window_test"


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(FOLDER.path_join(file))
	var presets := WorkshopPresets.new(FOLDER)
	presets.save(WorkshopTuning.copy(load(SOURCE)), "Default")
	var text := FileAccess.get_file_as_string(WorkshopGamePreset.ACTIVE_PRESETS_PATH)
	var file := FileAccess.open(ACTIVE_COPY, FileAccess.WRITE)
	file.store_string(text.replace(SOURCE, presets.path("Default")))
	file.close()
	WorkshopLayout.new(WORKSHOP_ID).clear()

	var window := _open(presets)
	await process_frame
	_check_editing(window)
	_check_saving(window, presets)
	await _check_layout(window, presets)


func _open(presets: WorkshopPresets) -> WorkshopWindow:
	var window := WorkshopWindow.new()
	root.add_child(window)
	window.setup(WORKSHOP_ID, presets, "flappy_race", "", ACTIVE_COPY)
	return window


func _check_editing(window: WorkshopWindow) -> void:
	check(window.preset_name == "Default", "The window opens the preset the game uses")
	var row := window.tunables_panel.row("flight/gravity")
	check(row != null, "Every value has a row")
	row.edited.emit(row.tunable, 80.0)
	check(window.tuning.edited.flight.gravity == 80.0, "A row edits the preset")
	check(window._edits.text == "Edited · 1", "The top bar counts the edit")
	check(window.use_button.disabled, "An unsaved preset cannot be used in the game")


func _check_saving(window: WorkshopWindow, presets: WorkshopPresets) -> void:
	window.save_preset()
	check(window.dialog.visible, "Saving over Default asks first")
	window.dialog.hide()
	check(presets.load_preset("Default").flight.gravity == 75.0, "Nothing is saved before")
	check(window.save_preset_as("Heavy").is_empty(), "Save as makes a new preset")
	check(window.preset_name == "Heavy", "And edits it")
	check(presets.load_preset("Heavy").flight.gravity == 80.0, "With the edit")
	check(not window._edits.visible, "It has no unsaved edits")

	window.use_in_game()
	check(window.dialog.visible, "Using a preset in the game asks first")
	check(window._dialog_text.text.contains("Flight · Gravity: 75.0 m/s² → 80.0 m/s²"), "Lists it")
	window.dialog.hide()
	window._write_game_preset()
	var game := WorkshopGamePreset.new("flappy_race", ACTIVE_COPY)
	check(game.current_path() == presets.path("Heavy"), "The game now uses it")
	check(window.game_label.text == "Heavy", "And the top bar says so")


func _check_layout(window: WorkshopWindow, presets: WorkshopPresets) -> void:
	window.flow.pop_out(Rect2i(40, 50, 500, 400))
	check(window.flow.is_popped_out(), "A panel pops out")
	check(window.flow.get_parent() == window.flow.window, "Into its own window")
	window.top_split.split_offset = 120
	window.save_layout()
	window.queue_free()
	await process_frame

	var again := _open(presets)
	await process_frame
	await process_frame
	check(again.flow.is_popped_out(), "A popped-out panel is remembered")
	check(again.top_split.split_offset == 120, "So is a grip")
	again.flow.window.close_requested.emit()
	check(not again.flow.is_popped_out(), "Closing its window docks it")
	check(again.flow.get_parent() == again.bottom_split, "In its place")
	again.reset_layout()
	check(again.top_split.split_offset == 0, "Reset layout restores the grips")
	check(WorkshopLayout.new(WORKSHOP_ID).popped().is_empty(), "And forgets popped panels")
