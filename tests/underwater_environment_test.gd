extends TestScript
## The underwater environment component: it builds its seabed and air-bubble columns, keeps the
## haze beyond the gameplay plane, and pushes every exported look value to its materials.

const SCENE: PackedScene = preload(
	"res://components/underwater_environment/underwater_environment.tscn"
)


func _run() -> void:
	var water := SCENE.instantiate() as UnderwaterEnvironment
	root.add_child(water)
	await process_frame

	var seabed := water.get_node("Seabed") as MeshInstance3D
	check(seabed.mesh != null and seabed.mesh.get_faces().size() > 0, "The seabed is built")
	check(
		water.get_node("AirBubbles").get_child_count() == water.air_columns.size(),
		"One air-bubble column stands at each configured position",
	)
	var settings := water.environment()
	check(settings.fog_enabled, "The haze is on")
	check(settings.fog_depth_begin > 20.15, "The haze begins beyond the gameplay plane")

	water.top_colour = Color(1.0, 0.0, 0.0)
	water.ray_strength = 0.0
	var backdrop := (water.get_node("Backdrop") as MeshInstance3D).material_override
	check(
		(backdrop as ShaderMaterial).get_shader_parameter(&"top_colour") == Color(1.0, 0.0, 0.0),
		"The water colours reach the backdrop",
	)
	check(not (water.get_node("Rays") as Node3D).visible, "Zero ray strength hides the rays")
	water.air_bubble_rate = 0.0
	var column := water.get_node("AirBubbles").get_child(0) as CPUParticles3D
	check(not column.emitting, "Zero air-bubble rate stops the columns")

	var kelp := water.prop_material(Color("26a69a"), 0.3, 2.0)
	check(
		kelp.get_shader_parameter(&"sway") == 0.3
		and kelp.get_shader_parameter(&"tint") == Color("26a69a"),
		"A prop material carries its tint and sway",
	)
