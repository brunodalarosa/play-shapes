@tool
extends VBoxContainer

signal preview_requested(profile: TiltShiftTuning, roster: int)
signal preview_stop_requested

const Model := preload("res://addons/tilt_shift_workshop/workshop_model.gd")
const Canvas := preload("res://addons/tilt_shift_workshop/workshop_canvas.gd")
const Graph := preload("res://addons/tilt_shift_workshop/workshop_delivery_graph.gd")

var model := Model.new()
var canvas: Canvas
var graph: Graph
var roster: int = 10
var status: Label
var warnings: RichTextLabel
var errors: RichTextLabel
var preview_status: Label
var _settings: VBoxContainer
var _selection: VBoxContainer
var _file_dialog: FileDialog
var _confirm: ConfirmationDialog
var _notice: AcceptDialog
var _pending: Callable
var _file_kind: String = "profile"
var _saving: bool = false
var _draft_save: bool = false
var _coordinate: Label
var _width_input: SpinBox


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var active: Resource = load("res://Tuning/Active Presets.tres")
	var selected: TiltShiftTuning = active.get("tilt_shift")
	var initial := selected.resource_path if selected != null else ""
	if initial.is_empty():
		initial = "res://minigames/003_tilt_shift/tuning/Default.tres"
	model.load_profile(initial)
	_build()
	model.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var title := Label.new()
	title.text = "Tilt Shift Workshop"
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var menu := MenuButton.new()
	menu.text = "Content files"
	toolbar.add_child(menu)
	var popup := menu.get_popup()
	for kind: String in ["profile", "layout", "basket", "physics"]:
		popup.add_item("Load %s…" % kind)
	for kind: String in ["profile", "layout", "basket", "physics"]:
		popup.add_item("Save usable %s…" % kind)
	for kind: String in ["profile", "layout", "basket", "physics"]:
		popup.add_item("Save draft %s…" % kind)
	popup.add_separator()
	popup.add_item("Apply saved profile to Active Presets", 12)
	popup.id_pressed.connect(_file_action)
	_button(
		toolbar,
		"Undo",
		func() -> void:
			model.undo()
			_rebuild_settings(),
	)
	_button(
		toolbar,
		"Redo",
		func() -> void:
			model.redo()
			_rebuild_settings(),
	)
	_button(
		toolbar,
		"Reload",
		func() -> void:
			_guard_discard(
				func() -> void:
					model.load_profile(model.source_path)
					_rebuild_settings(),
			),
	)
	var mode := OptionButton.new()
	mode.add_item("Edit paddles")
	mode.add_item("Edit baskets")
	toolbar.add_child(mode)
	mode.item_selected.connect(
		func(index: int) -> void:
			canvas.mode = "paddle" if index == 0 else "basket"
			canvas.selected = -1
			_rebuild_settings()
			canvas.queue_redraw(),
	)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var visual := VBoxContainer.new()
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(visual)
	canvas = Canvas.new()
	canvas.setup(model)
	canvas.selection_changed.connect(
		func(_kind: String, _index: int) -> void:
			_rebuild_selection(),
	)
	visual.add_child(canvas)
	graph = Graph.new()
	graph.setup(model)
	visual.add_child(graph)
	var preview := HFlowContainer.new()
	visual.add_child(preview)
	_button(preview, "Start / restart physics", _start_preview)
	_button(
		preview,
		"Stop preview",
		func() -> void:
			preview_stop_requested.emit(),
	)
	var roster_choice := OptionButton.new()
	for count: int in [2, 4, 6, 8, 10]:
		roster_choice.add_item("%d designers" % count, count)
	roster_choice.select(4)
	preview.add_child(roster_choice)
	roster_choice.item_selected.connect(
		func(index: int) -> void:
			roster = roster_choice.get_item_id(index),
	)
	preview_status = Label.new()
	preview_status.text = (
		"Preview uses the numbered round map and gameplay physics. " + "Unsaved content is copied."
	)
	preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visual.add_child(preview_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 370
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	_settings = VBoxContainer.new()
	_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_settings)
	_rebuild_settings()
	var reports := HBoxContainer.new()
	reports.custom_minimum_size.y = 140
	add_child(reports)
	warnings = _report(reports)
	errors = _report(reports)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.tres ; Tilt Shift Resources"])
	_file_dialog.file_selected.connect(_file_selected)
	add_child(_file_dialog)
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(
		func() -> void:
			if _pending.is_valid():
				_pending.call()
			_pending = Callable(),
	)
	_confirm.canceled.connect(
		func() -> void:
			_pending = Callable(),
	)
	add_child(_confirm)
	_notice = AcceptDialog.new()
	add_child(_notice)


func _rebuild_settings() -> void:
	for child: Node in _settings.get_children():
		_settings.remove_child(child)
		child.queue_free()
	_heading(_settings, "Geometry and snapping")
	_toggle(
		_settings,
		"Snap to grid",
		model.snap_enabled,
		func(value: bool) -> void:
			model.snap_enabled = value
			canvas.queue_redraw(),
	)
	_number(_settings, "Position snap (widths)", model, "position_snap", 0.001, 0.1, 0.001, false)
	_number(_settings, "Width snap (widths)", model, "width_snap", 0.001, 0.1, 0.001, false)
	_number(
		_settings,
		"Guide tolerance (widths)",
		model,
		"guide_tolerance",
		0.0001,
		0.05,
		0.0001,
		false,
	)
	_toggle(
		_settings,
		"Show geometry guides",
		canvas.show_guides,
		func(value: bool) -> void:
			canvas.show_guides = value
			canvas.queue_redraw(),
	)
	_toggle(
		_settings,
		"Move reflected basket pair",
		canvas.paired,
		func(value: bool) -> void:
			canvas.paired = value,
	)
	_number(_settings, "Neighbors (widths)", model.profile, "neighbor_distance", 0.01, 2, 0.01)
	_heading(_settings, "Selected object")
	_selection = VBoxContainer.new()
	_settings.add_child(_selection)
	_rebuild_selection()
	_heading(_settings, "Named content and rounds")
	if model.profile.paddle_layout != null:
		_text(_settings, "Layout name", model.profile.paddle_layout, "preset_name")
	var baskets := OptionButton.new()
	for preset: TiltShiftBasketPreset in model.baskets:
		baskets.add_item(preset.preset_name)
	baskets.select(model.basket_index)
	_settings.add_child(baskets)
	baskets.item_selected.connect(
		func(index: int) -> void:
			model.select_basket(index)
			canvas.selected = -1
			_rebuild_settings(),
	)
	_text(_settings, "Basket name", model.basket(), "preset_name")
	var actions := HBoxContainer.new()
	_settings.add_child(actions)
	_button(
		actions,
		"New preset",
		func() -> void:
			model.new_basket_preset()
			canvas.selected = -1
			_rebuild_settings(),
	)
	_button(
		actions,
		"Add opening",
		func() -> void:
			model.add_basket()
			_rebuild_selection(),
	)
	_number(_settings, "Round duration (s)", model.profile, "round_duration_seconds", 1, 300, 0.25)
	var count := _number(_settings, "Rounds per shift", model.profile, "round_count", 1, 24, 1)
	count.value_changed.connect(
		func(_value: float) -> void:
			_rebuild_settings.call_deferred(),
	)
	var mappings := maxi(model.profile.round_count, model.profile.baskets_by_round.size())
	for index: int in mappings:
		var row := HBoxContainer.new()
		_settings.add_child(row)
		var label := Label.new()
		label.text = "Round %d%s" % [
			index + 1,
			" (stale)" if index >= model.profile.round_count else "",
		]
		row.add_child(label)
		var choice := OptionButton.new()
		choice.name = "Round_%d" % (index + 1)
		choice.add_item("Missing", -1)
		for preset_index: int in model.baskets.size():
			choice.add_item(model.baskets[preset_index].preset_name, preset_index)
		if index < model.profile.baskets_by_round.size():
			var found := model.baskets.find(model.profile.baskets_by_round[index])
			choice.select(found + 1)
		row.add_child(choice)
		choice.item_selected.connect(
			func(selected: int) -> void:
				model.assign_round(index, selected - 1),
		)
		if index >= model.profile.round_count:
			_button(
				row,
				"Remove stale",
				func() -> void:
					model.remove_round_mapping(index)
					_rebuild_settings(),
			)
	_build_physics()


func _rebuild_selection() -> void:
	_coordinate = null
	_width_input = null
	for child: Node in _selection.get_children():
		_selection.remove_child(child)
		child.queue_free()
	var index := canvas.selected
	if index < 0:
		_heading(_selection, "Click an object on the canvas, then drag it.")
		return
	if canvas.mode == "paddle":
		if index >= model.profile.paddle_layout.paddles.size():
			return
		var paddle := model.profile.paddle_layout.paddles[index]
		_heading(_selection, paddle.paddle_id)
		var category := OptionButton.new()
		category.add_item("Orange")
		category.add_item("Blue")
		category.select(paddle.team)
		_selection.add_child(category)
		category.item_selected.connect(
			func(team: int) -> void:
				model.begin_edit()
				paddle.team = team
				model.end_edit(),
		)
		var coordinate := Label.new()
		_coordinate = coordinate
		coordinate.text = "x %.4f / y %.4f widths" % [paddle.position.x, paddle.position.y]
		_selection.add_child(coordinate)
		return
	if index >= model.basket().openings.size():
		return
	var opening := model.basket().openings[index]
	_heading(_selection, opening.basket_id)
	var category := OptionButton.new()
	for label: String in ["Orange", "Blue", "Trash"]:
		category.add_item(label)
	category.select(opening.team)
	_selection.add_child(category)
	category.item_selected.connect(
		func(team: int) -> void:
			model.begin_edit()
			opening.team = team
			model.end_edit(),
	)
	var row := HBoxContainer.new()
	_selection.add_child(row)
	var label := Label.new()
	label.text = "Paired width (widths)"
	row.add_child(label)
	var width := SpinBox.new()
	_width_input = width
	width.min_value = 0.001
	width.max_value = 1.0
	width.step = model.width_snap
	width.value = opening.width
	row.add_child(width)
	width.value_changed.connect(
		func(value: float) -> void:
			model.begin_edit()
			model.resize_basket(index, value)
			model.end_edit()
			_refresh(),
	)
	_button(
		_selection,
		"Remove opening (draft edit)",
		func() -> void:
			model.remove_basket(index)
			canvas.selected = -1
			_rebuild_selection(),
	)


func _build_physics() -> void:
	_heading(_settings, "Delivery and contact settings")
	var physics := model.profile.physics
	if physics == null:
		_heading(_settings, "Load a physics Resource to edit this draft.")
		return
	_number(_settings, "Total balls / round", physics, "ball_count", 0, 1000, 1)
	_toggle(
		_settings,
		"Use position seed",
		physics.use_position_seed,
		func(value: bool) -> void:
			model.begin_edit()
			physics.use_position_seed = value
			model.end_edit(),
	)
	_number(_settings, "Position seed", physics, "position_seed", -1000000000, 1000000000, 1)
	for field: Array in [
		["Spawn half width", "spawn_half_width", 0, 0.49, 0.01],
		["Ball radius", "ball_radius", 0.003, 0.02, 0.001],
		["Paddle length", "paddle_length", 0.02, 0.2, 0.005],
		["Paddle thickness", "paddle_thickness", 0.006, 0.03, 0.001],
		["Gravity (widths/s²)", "gravity", 0, 2, 0.05],
		["Entry speed (widths/s)", "entry_speed", 0, 1, 0.05],
		["Rotation (degrees/s)", "rotation_speed_degrees", 1, 180, 1],
		["Ball friction (low: sliding)", "ball_friction", 0, 1, 0.05],
		["Paddle friction (low: sliding)", "paddle_friction", 0, 1, 0.05],
		["Ball bounce (high: rebound)", "ball_bounce", 0, 1, 0.05],
		["Paddle bounce (high: rebound)", "paddle_bounce", 0, 1, 0.05],
	]:
		_number(_settings, field[0], physics, field[1], field[2], field[3], field[4])
	_heading(_settings, "Curve: progress 0–1 / relative intensity ≥0")
	for index: int in physics.delivery_curve.size():
		var row := HBoxContainer.new()
		_settings.add_child(row)
		for axis: int in 2:
			var point := SpinBox.new()
			point.min_value = 0
			point.max_value = 1 if axis == 0 else 100
			point.step = 0.01 if axis == 0 else 0.1
			point.value = physics.delivery_curve[index][axis]
			row.add_child(point)
			point.value_changed.connect(
				func(value: float) -> void:
					model.begin_edit()
					var changed := physics.delivery_curve[index]
					changed[axis] = value
					physics.delivery_curve[index] = changed
					model.end_edit(),
			)
		_button(
			row,
			"Remove",
			func() -> void:
				model.begin_edit()
				physics.delivery_curve.remove_at(index)
				model.end_edit()
				_rebuild_settings(),
		)
	_button(
		_settings,
		"Add curve point",
		func() -> void:
			model.begin_edit()
			physics.delivery_curve.append(Vector2(0.5, 1))
			physics.delivery_curve.sort()
			model.end_edit()
			_rebuild_settings(),
	)


func _refresh() -> void:
	if not is_instance_valid(status):
		return
	if is_instance_valid(_coordinate) and canvas.selected >= 0 \
			and canvas.selected < model.profile.paddle_layout.paddles.size():
		var point := model.profile.paddle_layout.paddles[canvas.selected].position
		_coordinate.text = "x %.4f / y %.4f widths" % [point.x, point.y]
	if is_instance_valid(_width_input) and canvas.selected >= 0 \
			and canvas.selected < model.basket().openings.size():
		_width_input.set_value_no_signal(model.basket().openings[canvas.selected].width)
	status.text = "%s%s • %s" % [
		"Unsaved edits • " if model.dirty else "Saved • ",
		model.source_path,
		model.basket().preset_name,
	]
	var issues := model.profile.validation_errors()
	var selected_errors := model.basket().validation_errors()
	if not selected_errors.is_empty() and not model.profile.baskets_by_round.has(model.basket()):
		issues.append_array(selected_errors)
	if not model.last_error.is_empty():
		issues.append(model.last_error)
	errors.text = "PRESET ERRORS — prevent usable save / launch\n" + "\n".join(issues)
	if issues.is_empty():
		errors.text += "Valid geometry and mappings. Fairness still needs owner play."
	var report := PackedStringArray(["GUIDE WARNINGS — never move objects"])
	if not canvas.diagnostics.is_empty():
		report.append_array(canvas.diagnostics.warnings)
		report.append(
			"%d neighbor pairs; %d clear vertical corridors."
			% [canvas.diagnostics.neighbors.size(), canvas.diagnostics.corridors.size()]
		)
		for clearance: Dictionary in canvas.diagnostics.clearances:
			if clearance.has("wall"):
				report.append(
					"%s swept wall clearance: %.4f widths" % [clearance.id, clearance.wall]
				)
			elif clearance.gap < 0.0:
				report.append(
					"%s / %s swept gap: %.4f widths"
					% [clearance.id, clearance.other, clearance.gap]
				)
	var first := graph.schedule[0] / 1000.0 if not graph.schedule.is_empty() else 0.0
	var last := graph.schedule[-1] / 1000.0 if not graph.schedule.is_empty() else 0.0
	report.append(
		"Scheduled %d balls, first %.3f s / last %.3f s." % [graph.schedule.size(), first, last]
	)
	warnings.text = "\n".join(report)


func _file_action(id: int) -> void:
	if id == 12:
		_apply_active()
		return
	var kinds := ["profile", "layout", "basket", "physics"]
	_file_kind = kinds[id % 4]
	_saving = id >= 4
	_draft_save = id >= 8
	var open := func() -> void:
		_file_dialog.file_mode = (
			FileDialog.FILE_MODE_SAVE_FILE if _saving else FileDialog.FILE_MODE_OPEN_FILE
		)
		var prefix := "Save draft " if _draft_save else "Save usable "
		_file_dialog.title = prefix + _file_kind if _saving else "Load " + _file_kind
		_file_dialog.current_dir = ProjectSettings.globalize_path(
			Model.DRAFTS if _draft_save else Model.CONTENT
		)
		_file_dialog.current_file = "Workshop.tres" if _saving else ""
		_file_dialog.popup_centered_ratio(0.7)
	if not _saving and _file_kind != "basket":
		_guard_discard(open)
	else:
		open.call()


func _file_selected(path: String) -> void:
	var local := ProjectSettings.localize_path(path)
	if _saving:
		if model.save_content(local, _file_kind, _draft_save) != OK:
			_show_notice(model.last_error)
		else:
			EditorInterface.get_resource_filesystem().scan()
			_show_notice(
				"Saved %s. Saving a named copy does not apply it to Active Presets." % local
			)
	else:
		var success := (
			model.load_profile(local)
			if _file_kind == "profile"
			else model.load_content(local, _file_kind)
		)
		if not success:
			_show_notice(model.last_error)
		canvas.selected = -1
		_rebuild_settings()
	_refresh()


func _apply_active() -> void:
	if model.dirty or model.source_path.begins_with(Model.DRAFTS):
		_show_notice("Save a usable profile before applying the active selection.")
		return
	if not model.profile.validation_errors().is_empty():
		_show_notice("Repair all preset errors before applying the active selection.")
		return
	var question := "Apply %s to Active Presets? Runtime consumers apply it on next launch."
	_confirm_action(
		question % model.source_path,
		func() -> void:
			var path := "res://Tuning/Active Presets.tres"
			var active: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			var copy: Resource = active.duplicate()
			copy.set(
				"tilt_shift",
				ResourceLoader.load(model.source_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP),
			)
			var result := ResourceSaver.save(copy, path)
			_show_notice("Applied active selection." if result == OK else error_string(result)),
	)


func _start_preview() -> void:
	var issues := model.profile.validation_errors()
	if not issues.is_empty():
		_show_notice("Cannot preview invalid round content:\n" + "\n".join(issues))
		return
	preview_requested.emit(model.profile, roster)


func _guard_discard(action: Callable) -> void:
	if model.dirty:
		_confirm_action("This load replaces unsaved draft edits. Continue?", action)
	else:
		action.call()


func _confirm_action(message: String, action: Callable) -> void:
	_pending = action
	_confirm.dialog_text = message
	_confirm.popup_centered(Vector2i(560, 160))


func _show_notice(message: String) -> void:
	_notice.dialog_text = message
	_notice.popup_centered(Vector2i(640, 200))


func _number(
	parent: Node,
	label: String,
	owner: Object,
	property: String,
	minimum: float,
	maximum: float,
	step: float,
	content: bool = true,
) -> SpinBox:
	var row := VBoxContainer.new()
	parent.add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var value := SpinBox.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.min_value = minimum
	value.max_value = maximum
	value.step = step
	value.value = float(owner.get(property))
	row.add_child(value)
	value.value_changed.connect(
		func(next: float) -> void:
			if content:
				model.begin_edit()
			owner.set(property, int(next) if typeof(owner.get(property)) == TYPE_INT else next)
			if content:
				model.end_edit()
			else:
				model.changed.emit(),
	)
	return value


func _text(parent: Node, label: String, owner: Object, property: String) -> void:
	_heading(parent, label)
	var edit := LineEdit.new()
	edit.text = owner.get(property)
	parent.add_child(edit)
	edit.text_submitted.connect(
		func(value: String) -> void:
			model.begin_edit()
			owner.set(property, value)
			model.end_edit(),
	)
	edit.focus_exited.connect(
		func() -> void:
			if edit.text != owner.get(property):
				model.begin_edit()
				owner.set(property, edit.text)
				model.end_edit(),
	)


func _toggle(parent: Node, label: String, value: bool, callback: Callable) -> void:
	var toggle := CheckBox.new()
	toggle.text = label
	toggle.button_pressed = value
	parent.add_child(toggle)
	toggle.toggled.connect(callback)


func _heading(parent: Node, label: String) -> void:
	var heading := Label.new()
	heading.text = label
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(heading)


func _button(parent: Node, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _report(parent: Node) -> RichTextLabel:
	var report := RichTextLabel.new()
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report.custom_minimum_size = Vector2(300, 140)
	parent.add_child(report)
	return report
