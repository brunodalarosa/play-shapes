@tool
class_name ShapeCharacter
extends Node2D
## Six independent sprite pivots used by the Milestone 1 detached-sprite animator.
## Keep the root's modulate white: use player_color to leave the face untouched.

const TINT_SHADER: Shader = preload("res://characters/player_tint.gdshader")
const COLORED_PARTS: Array[NodePath] = [^"Body", ^"LeftHand", ^"RightHand", ^"LeftFoot", ^"RightFoot"]

@export var player_color: Color = Color("598df2"):
	set(value):
		player_color = value
		if is_node_ready():
			_update_tint()

var body_shape: StringName = CharacterSelection.FALLBACK_SHAPE:
	set(value):
		body_shape = CharacterSelection.normalize_shape(value)
		if is_node_ready():
			_update_body_texture()

var _tint_material: ShaderMaterial


func _ready() -> void:
	# One material per character, shared only by its five colored parts.
	# Changing one player's color therefore cannot recolor another instance.
	_tint_material = ShaderMaterial.new()
	_tint_material.shader = TINT_SHADER
	for path: NodePath in COLORED_PARTS:
		var part := get_node(path) as Sprite2D
		part.material = _tint_material
	_update_body_texture()
	_update_tint()


func apply_selection(selection: Dictionary) -> void:
	var resolved := CharacterSelection.resolve_selection(
		selection.get("character_shape"),
		selection.get("character_color")
	)
	body_shape = StringName(resolved.character_shape)
	player_color = Color(String(resolved.character_color))


func _update_body_texture() -> void:
	(get_node(^"Body") as Sprite2D).texture = CharacterSelection.body_texture_for(body_shape)


func _update_tint() -> void:
	_tint_material.set_shader_parameter("player_color", player_color)
