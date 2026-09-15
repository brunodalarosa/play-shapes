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

var _tint_material: ShaderMaterial


func _ready() -> void:
	# One material per character, shared only by its five colored parts.
	# Changing one player's color therefore cannot recolor another instance.
	_tint_material = ShaderMaterial.new()
	_tint_material.shader = TINT_SHADER
	for path: NodePath in COLORED_PARTS:
		var part := get_node(path) as Sprite2D
		part.material = _tint_material
	_update_tint()


func _update_tint() -> void:
	_tint_material.set_shader_parameter("player_color", player_color)
