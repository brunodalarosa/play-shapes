class_name BubbleShell3D
extends Node3D
## A translucent bubble around whatever floats inside it: a shader sphere with a bright rim,
## an iridescent sheen and a highlight, which stretches toward a direction, bursts into droplets
## and re-forms. Presentation only; its owner decides radius, stretch and when it pops.

const SHELL_SHADER: Shader = preload("res://components/bubble_shell/bubble_shell.gdshader")
## The smallest share of its radius a re-forming bubble starts from.
const REFORM_START := 0.08

## Bubble radius in world units.
@export var radius: float = 0.5:
	set(value):
		radius = maxf(0.01, value)
		_apply_scale()
## Rim colour; alpha scales the rim's opacity.
@export var tint := Color(0.72, 0.9, 1.0):
	set(value):
		tint = value
		_set_shader(&"tint", value)
## How far the rim drifts through iridescent hues.
@export_range(0.0, 1.0, 0.01) var iridescence: float = 0.45:
	set(value):
		iridescence = value
		_set_shader(&"iridescence", value)
## Brightness of the highlight.
@export_range(0.0, 1.0, 0.01) var highlight: float = 0.85:
	set(value):
		highlight = value
		_set_shader(&"highlight", value)
## Droplets thrown by a pop.
@export_range(0, 64, 1) var droplet_count: int = 22
## How long the droplets fly, in seconds.
@export_range(0.1, 2.0, 0.05) var droplet_seconds: float = 0.45
## Draw order among transparent objects; above the contents keeps the rim over them.
@export var render_priority: int = 1:
	set(value):
		render_priority = value
		if _material != null:
			_material.render_priority = value

## Pull toward a plane direction, scaled by its amount (0 to about 0.25). Only the leading half
## of the shell stretches, and the collider it stands for never moves.
var stretch := Vector2.ZERO:
	set(value):
		stretch = value.limit_length(0.5)
		_set_shader(&"stretch", Vector3(stretch.x, stretch.y, 0.0))

var _shell: MeshInstance3D
var _material: ShaderMaterial
var _droplets: CPUParticles3D
var _reform_scale := 1.0
var _reform_tween: Tween
var _popped := false


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHELL_SHADER
	_material.render_priority = render_priority
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 40
	sphere.rings = 20
	_shell = MeshInstance3D.new()
	_shell.name = "Shell"
	_shell.mesh = sphere
	_shell.material_override = _material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_droplets = _make_droplets()
	add_child(_droplets)
	_set_shader(&"tint", tint)
	_set_shader(&"iridescence", iridescence)
	_set_shader(&"highlight", highlight)
	_apply_scale()


## Bursts the shell into droplets and hides it until [method reform].
func pop() -> void:
	if _reform_tween != null:
		_reform_tween.kill()
	_popped = true
	_shell.visible = false
	_droplets.amount = maxi(1, droplet_count)
	_droplets.lifetime = droplet_seconds
	_droplets.emission_sphere_radius = radius
	# Bigger bubbles throw bigger droplets, within a range that stays readable.
	var size := clampf(radius / 0.8, 0.7, 1.8)
	_droplets.scale_amount_min = 0.7 * size
	_droplets.scale_amount_max = 1.4 * size
	_droplets.restart()
	_droplets.emitting = droplet_count > 0


## Grows a new shell from a small bubble to full size over [param seconds].
func reform(seconds: float) -> void:
	if _reform_tween != null:
		_reform_tween.kill()
	_popped = false
	_shell.visible = true
	_reform_scale = REFORM_START
	_apply_scale()
	if not is_inside_tree() or seconds <= 0.0:
		_reform_scale = 1.0
		_apply_scale()
		return
	_reform_tween = create_tween()
	var grow := _reform_tween.tween_method(_set_reform_scale, REFORM_START, 1.0, seconds)
	grow.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_popped() -> bool:
	return _popped


func is_reforming() -> bool:
	return _reform_tween != null and _reform_tween.is_running()


func is_bursting() -> bool:
	return _droplets.emitting


## The radius the shell is drawn at now, including a re-form in progress.
func shown_radius() -> float:
	return 0.0 if _popped else radius * _reform_scale


func _set_reform_scale(value: float) -> void:
	_reform_scale = value
	_apply_scale()


func _apply_scale() -> void:
	if _shell != null:
		_shell.scale = Vector3.ONE * radius * _reform_scale


func _set_shader(parameter: StringName, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(parameter, value)


func _make_droplets() -> CPUParticles3D:
	var droplets := CPUParticles3D.new()
	droplets.name = "Droplets"
	droplets.emitting = false
	droplets.one_shot = true
	droplets.explosiveness = 1.0
	droplets.local_coords = false
	droplets.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	droplets.direction = Vector3.UP
	droplets.spread = 180.0
	droplets.initial_velocity_min = 0.4
	droplets.initial_velocity_max = 1.2
	droplets.radial_accel_min = 3.0
	droplets.radial_accel_max = 6.0
	droplets.damping_min = 2.0
	droplets.damping_max = 4.0
	droplets.gravity = Vector3(0.0, 0.6, 0.0)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	droplets.scale_amount_curve = shrink
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.92, 0.98, 1.0, 0.85)
	mesh.material = material
	droplets.mesh = mesh
	droplets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return droplets
