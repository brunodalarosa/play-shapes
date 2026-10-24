class_name TiltShift3DPaddleVisual
extends Node3D
## How one paddle looks, as a child of its physical body so it turns with it: the body in the
## player's colour, a cream gap ring and the team outline around its front outline, and the
## player's face on its front. The automatic paddle is grey with a darker outline and no face.
## A squash scales this node along the thickness only; the collider never changes.

var body_mesh: MeshInstance3D
var gap_mesh: MeshInstance3D
var outline_mesh: MeshInstance3D
var face: ShapeFace3D
var player_color := Color.WHITE
var team := 0
var _body_material := StandardMaterial3D.new()
var _outline_material := StandardMaterial3D.new()


## Builds the meshes for [param paddle]'s size. [param color] is the body's colour; it is
## ignored for the automatic paddle.
func configure(
	paddle: TiltShift3DPaddleBody,
	look: TiltShift3DPresentationTuning,
	color: Color,
) -> void:
	team = paddle.team
	var neutral := team == TiltShift3DTypes.Team.TRASH
	var length := paddle.size.x
	var thickness := paddle.size.y
	var depth := paddle.size.z
	var radius := paddle.corner_radius
	var gap := 0.0 if neutral else thickness * look.gap_ratio
	var outline := thickness * look.outline_ratio

	body_mesh = _mesh(RoundedBar.mesh(length, thickness, depth, radius), _body_material)
	_body_material.roughness = 0.65
	# The rings sit a little behind the body's front and back faces, so only their edges show
	# around the outline.
	if gap > 0.0:
		var gap_material := StandardMaterial3D.new()
		gap_material.albedo_color = look.gap_color
		gap_material.roughness = 0.8
		var ring := RoundedBar.mesh(
			length + gap * 2.0,
			thickness + gap * 2.0,
			depth * 0.94,
			radius + gap,
		)
		gap_mesh = _mesh(ring, gap_material)
	_outline_material.albedo_color = look.outline_color(team)
	_outline_material.roughness = 0.7
	var reach := gap + outline
	var rim := RoundedBar.mesh(
		length + reach * 2.0,
		thickness + reach * 2.0,
		depth * 0.88,
		radius + reach,
	)
	outline_mesh = _mesh(rim, _outline_material)
	if neutral:
		set_color(look.neutral_body_color)
		return
	set_color(color)
	face = ShapeFace3D.new()
	face.name = "Face"
	face.height = thickness * look.face_height_ratio
	face.position = Vector3(0.0, 0.0, depth * 0.5 + 0.004)
	add_child(face)


## Repaints the body, for a paddle whose owner changes between rounds.
func set_color(color: Color) -> void:
	player_color = color
	_body_material.albedo_color = color


## Squashes the paddle along its thickness to [param factor] of its height, 1 for none.
func set_squash(factor: float) -> void:
	scale = Vector3(1.0, clampf(factor, 0.1, 2.0), 1.0)


func outline_color() -> Color:
	return _outline_material.albedo_color


func _mesh(mesh: ArrayMesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
