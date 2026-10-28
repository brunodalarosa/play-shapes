class_name WorkshopTunableRow
extends HBoxContainer
## One value in the Tunables panel: an edited dot, its label, a slider with its default marked
## and the number with its unit.

signal edited(tunable: WorkshopTunable, value: Variant)
signal selected(row: WorkshopTunableRow)

const DOT := "●"
const TICK_COLOR := Color(1.0, 0.8, 0.3)

var tunable: WorkshopTunable
var _dot := Label.new()
var _label := Label.new()
var _slider: HSlider
var _tick: ColorRect
var _number: SpinBox
var _switch: CheckButton
var _default_ratio := -1.0


func _init(row_tunable: WorkshopTunable) -> void:
	tunable = row_tunable
	name = row_tunable.key().validate_node_name()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_dot.text = DOT
	_dot.custom_minimum_size = Vector2(14, 0)
	_dot.add_theme_color_override(&"font_color", TICK_COLOR)
	add_child(_dot)
	_label.text = tunable.label
	_label.custom_minimum_size = Vector2(210, 0)
	_label.clip_text = true
	_label.tooltip_text = tunable.help
	_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_label.gui_input.connect(_on_label_input)
	add_child(_label)

	if tunable.kind == WorkshopTunable.Kind.SWITCH:
		_switch = CheckButton.new()
		_switch.toggled.connect(_on_switch)
		_switch.focus_entered.connect(selected.emit.bind(self))
		add_child(_switch)
		return

	_slider = HSlider.new()
	_tick = ColorRect.new()
	_number = SpinBox.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.custom_minimum_size = Vector2(120, 0)
	_slider.focus_entered.connect(selected.emit.bind(self))
	_tick.color = TICK_COLOR
	_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slider.add_child(_tick)
	_slider.resized.connect(_place_tick)
	add_child(_slider)
	_number.custom_minimum_size = Vector2(130, 0)
	_number.suffix = tunable.unit
	_number.select_all_on_focus = true
	_number.get_line_edit().focus_entered.connect(selected.emit.bind(self))
	add_child(_number)
	for range_control: Range in [_slider, _number]:
		range_control.min_value = tunable.minimum
		range_control.max_value = tunable.maximum
		range_control.step = 1.0 if tunable.kind == WorkshopTunable.Kind.WHOLE else tunable.step
		range_control.allow_greater = range_control == _number
		range_control.allow_lesser = range_control == _number
		range_control.value_changed.connect(_on_range)


## Shows [param value], whether it differs from the saved preset, and the default's place.
func show_value(value: Variant, is_edited: bool, default_value: Variant) -> void:
	_dot.modulate.a = 1.0 if is_edited else 0.0
	if value == null:
		return
	if tunable.kind == WorkshopTunable.Kind.SWITCH:
		_switch.set_pressed_no_signal(value)
		return
	_slider.set_value_no_signal(value)
	_number.set_value_no_signal(value)
	var span := tunable.maximum - tunable.minimum
	_default_ratio = (
		-1.0
		if default_value == null or span <= 0.0
		else clampf((float(default_value) - tunable.minimum) / span, 0.0, 1.0)
	)
	_place_tick()


func _place_tick() -> void:
	if _tick == null:
		return
	_tick.visible = _default_ratio >= 0.0
	var grabber := 8.0
	var x := grabber + _default_ratio * maxf(_slider.size.x - grabber * 2.0, 0.0)
	_tick.position = Vector2(x - 1.0, 0.0)
	_tick.size = Vector2(2.0, _slider.size.y)


func _on_range(value: float) -> void:
	edited.emit(tunable, int(value) if tunable.kind == WorkshopTunable.Kind.WHOLE else value)


func _on_switch(on: bool) -> void:
	edited.emit(tunable, on)


func _on_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		selected.emit(self)
