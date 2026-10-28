class_name WorkshopDockablePanel
extends PanelContainer
## One named workshop panel: a title bar with room for the panel's own controls and a button
## that pops it out into its own window, which docks it again when closed.

signal popped_changed(panel: WorkshopDockablePanel)

var number := 0
var title := ""
## Why this panel cannot pop out, or empty when it can.
var pop_out_blocked := ""
var window: Window
## Where popped-out windows live, outside the panels so a panel can move into one.
var window_host: Node
## Holds the panel's own controls on the right of its title.
var title_bar: HBoxContainer
var content: MarginContainer
var _pop_button: Button
var _dock_parent: Node
var _dock_index := 0


func _init(panel_number: int, panel_title: String) -> void:
	number = panel_number
	title = panel_title
	name = panel_title.to_pascal_case()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(160, 120)

	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var label := Label.new()
	label.text = "%d  %s" % [number, title]
	label.add_theme_font_size_override(&"font_size", 15)
	bar.add_child(label)
	title_bar = HBoxContainer.new()
	title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(title_bar)
	_pop_button = Button.new()
	_pop_button.flat = true
	_pop_button.pressed.connect(toggle_pop_out)
	bar.add_child(_pop_button)
	content = MarginContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	_refresh_button()


## Puts [param control] in the panel body.
func set_body(control: Control) -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(control)


func is_popped_out() -> bool:
	return window != null


func toggle_pop_out() -> void:
	if is_popped_out():
		dock()
	else:
		pop_out()


## Moves the panel into its own window at [param rect], or near where it sat.
func pop_out(rect := Rect2i(), screen := -1, mode := Window.MODE_WINDOWED) -> void:
	if is_popped_out() or not pop_out_blocked.is_empty():
		return
	_dock_parent = get_parent()
	_dock_index = get_index()
	var from := Rect2i(Vector2i(get_screen_position()), Vector2i(size))
	window = Window.new()
	window.title = "%d %s" % [number, title]
	window.wrap_controls = false
	window.min_size = Vector2i(320, 240)
	window.close_requested.connect(dock)
	window.size = rect.size if rect.has_area() else from.size
	_dock_parent.remove_child(self)
	window.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_host.add_child(window)
	if screen >= 0 and screen < DisplayServer.get_screen_count():
		window.current_screen = screen
	window.position = rect.position if rect.has_area() else from.position
	window.mode = mode
	window.show()
	_refresh_button()
	popped_changed.emit(self)


## Brings a popped-out panel back to its place in the workshop window.
func dock() -> void:
	if not is_popped_out():
		return
	var old_window := window
	window = null
	old_window.remove_child(self)
	_dock_parent.add_child(self)
	_dock_parent.move_child(self, mini(_dock_index, _dock_parent.get_child_count() - 1))
	old_window.queue_free()
	_refresh_button()
	popped_changed.emit(self)


## The popped-out window's rect, screen and mode, for the layout to remember.
func window_state() -> Dictionary:
	if not is_popped_out():
		return { }
	return {
		"rect": Rect2i(window.position, window.size),
		"screen": window.current_screen,
		"mode": window.mode,
	}


func _refresh_button() -> void:
	_pop_button.text = "Dock" if is_popped_out() else "Pop out"
	_pop_button.disabled = not is_popped_out() and not pop_out_blocked.is_empty()
	_pop_button.tooltip_text = (
		pop_out_blocked
		if _pop_button.disabled
		else "Back into the workshop window"
		if is_popped_out()
		else "Into its own window"
	)
