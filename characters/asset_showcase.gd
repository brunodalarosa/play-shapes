extends Control
## Static art review only: no gameplay, animation controller, or collision nodes.

const CHARACTER: PackedScene = preload("res://characters/shape_character.tscn")
const BACKGROUND: PackedScene = preload("res://characters/background_sample.tscn")
const COLORS: Array[Color] = [Color("ef426f"), Color("25ba84"), Color("704fe4"), Color("f7bb21"), Color("121b30"), Color("f3f5fa")]
const NAMES: Array[String] = ["Coral / neutral", "Mint / raised hands", "Violet / wide stance", "Gold / tilted body", "Ink / lifted for readability", "Pearl / light-color check"]

@onready var grid: GridContainer = %Grid


func _ready() -> void:
	for i: int in COLORS.size():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e8f1f6") if i < 3 else Color("243951")
		style.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel", style)
		grid.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		var title := Label.new()
		title.text = NAMES[i]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_color_override("font_color", Color("243951") if i < 3 else Color.WHITE)
		column.add_child(title)
		var stage := Control.new()
		stage.custom_minimum_size = Vector2(220, 190)
		stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(stage)
		var world := Node2D.new()
		stage.add_child(world)
		world.add_child(BACKGROUND.instantiate())
		var character := CHARACTER.instantiate() as ShapeCharacter
		character.player_color = COLORS[i]
		world.add_child(character)
		_set_review_pose(character, i)
		stage.resized.connect(_layout_stage.bind(stage, world))
		_layout_stage(stage, world)
	resized.connect(_layout_grid)
	_layout_grid()


func _layout_grid() -> void:
	grid.columns = 3 if size.x >= 800 else (2 if size.x >= 540 else 1)


func _layout_stage(stage: Control, world: Node2D) -> void:
	var art_scale: float = minf(stage.size.x / 270.0, stage.size.y / 260.0)
	world.scale = Vector2.ONE * art_scale
	world.position = Vector2(stage.size.x * 0.5, stage.size.y * 0.40)


func _set_review_pose(character: ShapeCharacter, index: int) -> void:
	# Static transform examples prove part independence without selecting a rig.
	if index == 1:
		character.get_node("LeftHand").position = Vector2(-54, -55)
		character.get_node("RightHand").position = Vector2(54, -55)
	elif index == 2:
		character.get_node("LeftFoot").position.x = -36
		character.get_node("RightFoot").position.x = 36
	elif index == 3:
		character.get_node("Body").rotation_degrees = -12
		character.get_node("Body").scale = Vector2(0.56, 0.44)
		character.get_node("RightHand").position = Vector2(53, -26)
