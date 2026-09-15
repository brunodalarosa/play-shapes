extends Control
## Visual laboratory only. Keyboard/button input never enters authoritative game state.

const DIRECTIONS: Array[StringName] = [&"up", &"left", &"right", &"down"]

@export var active_presets: ActivePresets = preload("res://Tuning/Active Presets.tres")

@onready var character: ShapeCharacter = %Character
@onready var animator: HybridCharacterAnimator = %HybridAnimator
@onready var readout: Label = %Readout
@onready var auto_preview: CheckButton = %AutoPreview

var charge_state := PoseCharge.new()
var _button_direction: StringName = &""
var _auto_index: int = -1
var _auto_elapsed: float = 0.0

var tuning: SimonSaysTuning:
	get: return active_presets.simon_says

var charge_fill_seconds: float:
	get: return tuning.charge_fill_seconds
var charge_decay_seconds: float:
	get: return tuning.charge_decay_seconds
var auto_hold_seconds: float:
	get: return tuning.auto_hold_seconds
var auto_release_seconds: float:
	get: return tuning.auto_release_seconds

func _ready() -> void:
	charge_state.fill_seconds = charge_fill_seconds
	charge_state.decay_seconds = charge_decay_seconds
	animator.apply_tuning(tuning)
	animator.setup(character, charge_state)
	for direction: StringName in DIRECTIONS:
		var button := get_node(NodePath("%" + direction.capitalize() + "Button")) as Button
		button.button_down.connect(_set_button_direction.bind(direction))
		button.button_up.connect(_clear_button_direction.bind(direction))
	auto_preview.toggled.connect(_reset_auto_preview)
	_reset_auto_preview(auto_preview.button_pressed)

func _process(delta: float) -> void:
	charge_state.fill_seconds = charge_fill_seconds
	charge_state.decay_seconds = charge_decay_seconds
	var requested := _auto_direction(delta) if auto_preview.button_pressed else _manual_direction()
	charge_state.advance(delta, requested)
	var state := "DANCE"
	if not charge_state.direction.is_empty():
		state = "%s / %s" % [charge_state.direction.to_upper(), "SNAPPED + HELD" if charge_state.is_committed() else "CHARGING" if charge_state.held else "UNWINDING"]
	readout.text = "%s\nCharge %.2f" % [state, charge_state.charge]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_A:
		auto_preview.button_pressed = not auto_preview.button_pressed

func _manual_direction() -> StringName:
	if not _button_direction.is_empty():
		return _button_direction
	if Input.is_key_pressed(KEY_UP):
		return &"up"
	if Input.is_key_pressed(KEY_LEFT):
		return &"left"
	if Input.is_key_pressed(KEY_RIGHT):
		return &"right"
	if Input.is_key_pressed(KEY_DOWN):
		return &"down"
	return &""

func _auto_direction(delta: float) -> StringName:
	_auto_elapsed += delta
	if _auto_index < 0:
		if _auto_elapsed >= 2.0:
			_auto_index = 0
			_auto_elapsed = 0.0
		return &""
	var cycle_seconds := charge_fill_seconds + auto_hold_seconds + auto_release_seconds
	if _auto_elapsed >= cycle_seconds:
		_auto_index = (_auto_index + 1) % DIRECTIONS.size()
		_auto_elapsed = 0.0
	if _auto_elapsed < charge_fill_seconds + auto_hold_seconds:
		return DIRECTIONS[_auto_index]
	return &""

func _set_button_direction(direction: StringName) -> void:
	_button_direction = direction

func _clear_button_direction(direction: StringName) -> void:
	if _button_direction == direction:
		_button_direction = &""

func _reset_auto_preview(enabled: bool) -> void:
	_button_direction = &""
	_auto_index = -1
	_auto_elapsed = 0.0
	charge_state.reset()
	if not enabled:
		readout.text = "DANCE\nCharge 0.00"
