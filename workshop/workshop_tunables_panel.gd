class_name WorkshopTunablesPanel
extends VBoxContainer
## The Tunables panel: one tab per part of the preset, its values grouped by export group, a
## filter, the selected value's help, and what waits for a restart or blocks saving.

signal restart_requested

var tuning: WorkshopTuning
var _filter := LineEdit.new()
var _tabs := TabContainer.new()
var _help := Label.new()
var _pending := Label.new()
var _restart := Button.new()
var _errors := Label.new()
var _rows: Array[WorkshopTunableRow] = []
var _headers: Dictionary[Label, Array] = { }
var _selected: WorkshopTunableRow


func _init(workshop_tuning: WorkshopTuning) -> void:
	tuning = workshop_tuning
	name = "Tunables"
	_filter.placeholder_text = "Filter values"
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(_apply_filter)
	add_child(_filter)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	_build_tabs()

	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(0, 54)
	_help.modulate = Color(1, 1, 1, 0.8)
	add_child(_help)
	var waiting := HBoxContainer.new()
	add_child(waiting)
	_pending.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pending.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	waiting.add_child(_pending)
	_restart.text = "Restart (R)"
	_restart.pressed.connect(restart_requested.emit)
	waiting.add_child(_restart)
	_errors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_errors.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4))
	add_child(_errors)
	tuning.changed.connect(refresh)
	refresh()


func rows() -> Array[WorkshopTunableRow]:
	return _rows


func row(key: String) -> WorkshopTunableRow:
	for each: WorkshopTunableRow in _rows:
		if each.tunable.key() == key:
			return each
	return null


## Shows every value as the edited preset holds it.
func refresh() -> void:
	for each: WorkshopTunableRow in _rows:
		var tunable := each.tunable
		each.show_value(
			tuning.value(tunable),
			tuning.is_edited(tunable),
			tuning.default_value(tunable),
		)
	var waiting := tuning.pending()
	_pending.text = (
		""
		if waiting.is_empty()
		else "Waiting for a restart: %s" % ", ".join(waiting.map(_short_name))
	)
	_restart.disabled = waiting.is_empty()
	_errors.text = "\n".join(tuning.errors())


func _build_tabs() -> void:
	var lists: Dictionary[String, VBoxContainer] = { }
	var groups: Dictionary[String, String] = { }
	for tunable: WorkshopTunable in tuning.tunables:
		if not lists.has(tunable.tab):
			var scroll := ScrollContainer.new()
			scroll.name = tunable.tab
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_tabs.add_child(scroll)
			var list := VBoxContainer.new()
			list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(list)
			lists[tunable.tab] = list
		var list := lists[tunable.tab]
		if groups.get(tunable.tab, "") != tunable.group:
			groups[tunable.tab] = tunable.group
			var header := Label.new()
			header.text = tunable.group + ("  · live" if tunable.live else "")
			header.add_theme_font_size_override(&"font_size", 13)
			header.modulate = Color(0.75, 0.85, 1.0)
			list.add_child(header)
			_headers[header] = []
		var row_control := WorkshopTunableRow.new(tunable)
		row_control.edited.connect(_on_edited)
		row_control.selected.connect(_select)
		list.add_child(row_control)
		_rows.append(row_control)
		_headers[_headers.keys().back()].append(row_control)


func _on_edited(tunable: WorkshopTunable, value: Variant) -> void:
	tuning.set_value(tunable, value)


func _select(row_control: WorkshopTunableRow) -> void:
	_selected = row_control
	var tunable := row_control.tunable
	var range_text := (
		""
		if tunable.kind == WorkshopTunable.Kind.SWITCH
		else "  Range %s to %s."
		% [tunable.format(tunable.minimum), tunable.format(tunable.maximum)]
	)
	var when := "Applies live." if tunable.live else "Applies on restart."
	_help.text = "%s: %s\nDefault %s.%s %s" % [
		tunable.label,
		tunable.help,
		tunable.format(tuning.default_value(tunable)),
		range_text,
		when,
	]


func _apply_filter(text: String) -> void:
	var needle := text.strip_edges().to_lower()
	for header: Label in _headers:
		var any := false
		for row_control: WorkshopTunableRow in _headers[header]:
			var shown := needle.is_empty() or row_control.tunable.label.to_lower().contains(needle)
			row_control.visible = shown
			any = any or shown
		header.visible = any


func _short_name(tunable: WorkshopTunable) -> String:
	return "%s · %s" % [tunable.tab, tunable.label]
