extends Control
## Production animation vocabulary preview. It supplies semantics, never game outcomes.

const CHARACTER_SCENE := preload("res://characters/shape_character.tscn")
const ANIMATOR_SCRIPT := preload("res://characters/hybrid_character_animator.gd")
const COLORS: Array[Color] = [Color("f45b7a"), Color("5b8def"), Color("4ecb8d"), Color("f6c453"), Color("9c72e8"), Color("ef7f45"), Color("55c7d9"), Color("e867b5"), Color("89b34c"), Color("7f91a8"), Color("d76464")]

@export var active_presets: ActivePresets = preload("res://Tuning/Active Presets.tres")
@onready var world: Node2D = %World
@onready var style_picker: OptionButton = %StylePicker
@onready var status: Label = %Status

var characters: Array[ShapeCharacter] = []
var animators: Array[HybridCharacterAnimator] = []
var _direction_index := 0
var _charge := 0.0
var _held := false


func _ready() -> void:
	for style: StringName in HybridCharacterAnimator.DANCE_STYLES:
		style_picker.add_item(String(style).capitalize())
	style_picker.item_selected.connect(_select_style)
	%ChargeButton.pressed.connect(_toggle_charge)
	%LeadFlowButton.pressed.connect(_lead_flow)
	%LifeLossButton.pressed.connect(_reaction.bind(&"life_loss"))
	%SurvivedButton.pressed.connect(_reaction.bind(&"survived"))
	%EliminateButton.pressed.connect(_toggle_elimination)
	%HappyButton.pressed.connect(_result.bind(&"happy"))
	%MoodyButton.pressed.connect(_result.bind(&"moody"))
	%ResetButton.pressed.connect(_reset_states)
	for index: int in 11:
		var character := CHARACTER_SCENE.instantiate() as ShapeCharacter
		character.player_color = COLORS[index]
		world.add_child(character)
		characters.append(character)
		var animator := ANIMATOR_SCRIPT.new() as HybridCharacterAnimator
		world.add_child(animator)
		animator.apply_tuning(active_presets.simon_says)
		animator.setup(character, index == 0, maxi(index - 1, 0), 10)
		animators.append(animator)
	_responsive_layout()
	get_viewport().size_changed.connect(_responsive_layout)
	_select_style(0)


func _process(delta: float) -> void:
	if _held:
		_charge = minf(_charge + delta / active_presets.simon_says.charge_fill_seconds, 1.0)
	for animator: HybridCharacterAnimator in animators:
		animator.set_pose_state(HybridCharacterAnimator.DIRECTIONS[_direction_index], _charge, _held)
	status.text = "%s · %s · charge %.2f · 1 lead + 10 evenly phased players" % [style_picker.get_item_text(style_picker.selected), HybridCharacterAnimator.DIRECTIONS[_direction_index].to_upper(), _charge]


func _select_style(index: int) -> void:
	for animator: HybridCharacterAnimator in animators:
		animator.set_dance_style(HybridCharacterAnimator.DANCE_STYLES[index])


func _toggle_charge() -> void:
	if _held and is_equal_approx(_charge, 1.0):
		_held = false
		_charge = 0.0
		_direction_index = (_direction_index + 1) % HybridCharacterAnimator.DIRECTIONS.size()
	else:
		_held = true
		_charge = 0.0


func _reaction(kind: StringName) -> void:
	for animator: HybridCharacterAnimator in animators: animator.play_reaction(kind)


func _lead_flow() -> void:
	animators[0].play_lead_pose_flow(HybridCharacterAnimator.DIRECTIONS[_direction_index])
	_direction_index = (_direction_index + 1) % HybridCharacterAnimator.DIRECTIONS.size()


func _toggle_elimination() -> void:
	var eliminated: bool = not animators.back().semantic_state().eliminated
	for index: int in range(6, animators.size()): animators[index].set_eliminated(eliminated)


func _result(mood: StringName) -> void:
	for animator: HybridCharacterAnimator in animators: animator.set_result_mood(mood)


func _reset_states() -> void:
	_held = false
	_charge = 0.0
	for animator: HybridCharacterAnimator in animators:
		animator.set_eliminated(false)
		animator.set_result_mood(&"none")
		animator.set_dance_active(true)


func _responsive_layout() -> void:
	var size := get_viewport_rect().size
	world.position = Vector2(size.x * 0.5, 0.0)
	characters[0].position = Vector2(0, size.y * 0.33)
	characters[0].scale = Vector2.ONE * clampf(size.y / 720.0, 0.8, 1.25)
	var span := minf(size.x * 0.84, 1060.0)
	for player_index: int in 10:
		characters[player_index + 1].position = Vector2(-span * 0.5 + span * (float(player_index) + 0.5) / 10.0, size.y * 0.72)
		characters[player_index + 1].scale = Vector2.ONE * clampf(size.x / 1500.0, 0.52, 0.8)
