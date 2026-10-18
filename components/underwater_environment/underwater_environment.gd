class_name UnderwaterEnvironment
extends Node3D
## A reusable underwater setting behind a vertical gameplay plane at depth zero: the water
## backdrop and surface band, god rays, a faceted seabed with caustics, depth haze and rising air
## bubbles. Every look value is exported; nothing here touches gameplay.

const PROP_SHADER: Shader = preload(
	"res://components/underwater_environment/underwater_prop.gdshader"
)

@export_group("Water")
## Water colour at the top of the screen.
@export var top_colour := Color("54d1fa"):
	set(value):
		top_colour = value
		_apply()
## Water colour at the bottom of the screen.
@export var bottom_colour := Color("08459a"):
	set(value):
		bottom_colour = value
		_apply()
## Share of the screen height the bright surface band covers.
@export_range(0.0, 0.5, 0.01) var surface_height: float = 0.16:
	set(value):
		surface_height = value
		_apply()
## Brightness of the surface band.
@export_range(0.0, 1.0, 0.01) var surface_strength: float = 0.75:
	set(value):
		surface_strength = value
		_apply()

@export_group("Light")
## Brightness of the god rays. Zero hides them.
@export_range(0.0, 1.0, 0.01) var ray_strength: float = 0.22:
	set(value):
		ray_strength = value
		_apply()
## Drift speed of the god rays.
@export_range(0.0, 2.0, 0.01) var ray_speed: float = 0.25:
	set(value):
		ray_speed = value
		_apply()
## Brightness of the caustic shimmer on the seabed and on props using the prop material.
@export_range(0.0, 1.0, 0.01) var caustic_strength: float = 0.25:
	set(value):
		caustic_strength = value
		_apply()

@export_group("Haze")
## Haze colour; distant scenery fades toward it.
@export var haze_colour := Color("185eac"):
	set(value):
		haze_colour = value
		_apply()
## Camera distance where the haze begins. Keep it beyond the gameplay plane.
@export var haze_begin: float = 24.0:
	set(value):
		haze_begin = value
		_apply()
## Camera distance where scenery has fully faded into the haze.
@export var haze_end: float = 72.0:
	set(value):
		haze_end = value
		_apply()

@export_group("Seabed")
## Seabed colour before haze.
@export var seabed_colour := Color("4d79a6"):
	set(value):
		seabed_colour = value
		_apply()
## Height of the seabed surface, in world units.
@export var seabed_height: float = -8.0
## Nearest edge of the seabed, behind the plane.
@export var seabed_near: float = -6.0
## Farthest edge of the seabed.
@export var seabed_far: float = -56.0
## Width of the seabed strip.
@export var seabed_width: float = 160.0
## Height variation of the facets.
@export var seabed_roughness: float = 0.55

@export_group("Air bubbles")
## Rising air bubbles per second in each column. Zero stops them.
@export_range(0.0, 10.0, 0.1) var air_bubble_rate: float = 1.4:
	set(value):
		air_bubble_rate = value
		_apply_air_bubbles()
## Horizontal positions of the air-bubble columns.
@export var air_columns := PackedFloat32Array([-8.4, -3.1, 2.6, 7.9])
## Depth of the air-bubble columns, behind the plane.
@export var air_depth: float = -3.0

@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _backdrop: MeshInstance3D = $Backdrop
@onready var _rays: MeshInstance3D = $Rays
@onready var _seabed: MeshInstance3D = $Seabed
@onready var _air: Node3D = $AirBubbles


func _ready() -> void:
	_seabed.mesh = _build_seabed()
	_seabed.material_override = prop_material(seabed_colour)
	_build_air_columns()
	_apply()


## A material for scenery in this setting: a flat [param colour], optional sway at the top of
## the model, and the shared caustic shimmer.
func prop_material(colour: Color, sway := 0.0, sway_height := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PROP_SHADER
	material.set_shader_parameter(&"tint", colour)
	material.set_shader_parameter(&"sway", sway)
	material.set_shader_parameter(&"sway_height", sway_height)
	material.set_shader_parameter(&"caustic_strength", caustic_strength)
	return material


func environment() -> Environment:
	return _world_environment.environment


func _apply() -> void:
	if not is_node_ready():
		return
	var water := _backdrop.material_override as ShaderMaterial
	water.set_shader_parameter(&"top_colour", top_colour)
	water.set_shader_parameter(&"bottom_colour", bottom_colour)
	water.set_shader_parameter(&"surface_height", surface_height)
	water.set_shader_parameter(&"surface_strength", surface_strength)
	var rays := _rays.material_override as ShaderMaterial
	rays.set_shader_parameter(&"strength", ray_strength)
	rays.set_shader_parameter(&"speed", ray_speed)
	_rays.visible = ray_strength > 0.0
	var seabed := _seabed.material_override as ShaderMaterial
	if seabed != null:
		seabed.set_shader_parameter(&"tint", seabed_colour)
		seabed.set_shader_parameter(&"caustic_strength", caustic_strength)
	var settings := environment()
	settings.fog_enabled = haze_end > haze_begin
	settings.fog_mode = Environment.FOG_MODE_DEPTH
	settings.fog_light_color = haze_colour
	settings.fog_depth_begin = haze_begin
	settings.fog_depth_end = haze_end
	settings.fog_depth_curve = 1.0
	settings.fog_density = 1.0
	settings.fog_sky_affect = 0.0
	_apply_air_bubbles()


func _apply_air_bubbles() -> void:
	if not is_node_ready():
		return
	for column: CPUParticles3D in _air.get_children():
		column.emitting = air_bubble_rate > 0.0
		if air_bubble_rate > 0.0:
			column.amount = maxi(1, ceili(air_bubble_rate * column.lifetime))
			# Columns start already full rather than growing up from the seabed.
			column.preprocess = column.lifetime
			column.restart()


## A strip of flat-shaded facets with seeded heights, so the seabed looks the same every run.
func _build_seabed() -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 4004
	var columns := 56
	var rows := 14
	var heights: Array[PackedFloat32Array] = []
	for row: int in rows + 1:
		var line := PackedFloat32Array()
		for column: int in columns + 1:
			line.append(random.randf_range(-seabed_roughness, seabed_roughness))
		heights.append(line)
	var corner_offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for row: int in rows:
		for column: int in columns:
			var corners: Array[Vector3] = []
			for offset: Vector2i in corner_offsets:
				var x := lerpf(
					-seabed_width * 0.5,
					seabed_width * 0.5,
					float(column + offset.x) / columns,
				)
				var z := lerpf(seabed_near, seabed_far, float(row + offset.y) / rows)
				var y := seabed_height + heights[row + offset.y][column + offset.x]
				corners.append(Vector3(x, y, z))
			for index: int in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(corners[index])
	surface.generate_normals()
	return surface.commit()


func _build_air_columns() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.9, 0.98, 1.0, 0.55)
	material.disable_fog = true
	mesh.material = material
	for x: float in air_columns:
		var column := CPUParticles3D.new()
		column.position = Vector3(x, seabed_height + 0.5, air_depth)
		column.mesh = mesh
		column.lifetime = 7.0
		column.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		column.emission_box_extents = Vector3(0.25, 0.1, 0.25)
		column.direction = Vector3.UP
		column.spread = 4.0
		column.gravity = Vector3(0.0, 0.25, 0.0)
		column.initial_velocity_min = 1.2
		column.initial_velocity_max = 1.9
		column.scale_amount_min = 0.5
		column.scale_amount_max = 1.4
		column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_air.add_child(column)
