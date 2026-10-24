extends TestScript
## Checks the plaza's landing tiers, the 2D surfaces built from them, camera framing and the
## billboard display.

const WORLD := preload("res://scenes/lobby_playground_world.tscn")
const PLATFORM_LAYER := 128
const PPU := LobbyPlaygroundWorld.PIXELS_PER_UNIT
## Approved tiers in character heights: the ground, three chair seats, two tabletops, the roof.
const EXPECTED := {
	"GroundLanding": 0.0,
	"ChairLeft": 1.15,
	"ChairMiddle": 1.15,
	"ChairRight": 1.15,
	"TableLeft": 3.3,
	"TableRight": 3.3,
	"Cafe": 6.5,
}
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]


func _run() -> void:
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	root.add_child(world)
	await process_frame

	var landings := world.landings()
	check(landings.size() == EXPECTED.size(), "The plaza has the ground and exactly six landings")
	for surface_name: String in EXPECTED:
		var surface := world.surface_named(surface_name)
		if not check(surface != null, "%s has a built platform surface" % surface_name):
			continue
		var bounds := surface.world_bounds()
		check(
			absf(bounds.position.y + float(EXPECTED[surface_name]) * PPU) < 0.5,
			"%s lands at %.2f character heights" % [surface_name, EXPECTED[surface_name]],
		)
		check(
			surface.collision_layer == PLATFORM_LAYER and surface.collision_mask == 0,
			"%s uses the reserved platform layer" % surface_name,
		)
		var shape := surface.get_node("LandingTop") as CollisionShape2D
		check(shape.one_way_collision, "%s is a one-way landing" % surface_name)
		var closed := surface_name == "GroundLanding"
		check(
			surface.drop_rule
			== (PlatformSurface.DropRule.CLOSED if closed else PlatformSurface.DropRule.OPEN),
			"%s %s FALL" % [surface_name, "rejects" if closed else "permits"],
		)

	var roof := world.surface_named("Cafe").world_bounds()
	var table := world.surface_named("TableLeft").world_bounds()
	var seat := world.surface_named("ChairLeft").world_bounds()
	check(
		roof.size.x >= 6.0 * PPU and table.size.x >= 3.0 * PPU and seat.size.x >= 1.2 * PPU,
		"Every landing is wider than a character",
	)
	check(
		roof.end.x < table.position.x and roof.end.x < seat.position.x,
		"The roof ends before the furniture, leaving a jump corridor beside the café",
	)

	check(world.get_node("SpawnPoints").get_child_count() == 10, "Ten spawn points are available")
	var ground := world.surface_named("GroundLanding").world_bounds()
	for seat_index: int in range(1, 11):
		var spawn := world.spawn_point(seat_index)
		check(
			spawn.y == 0.0 and spawn.x > ground.position.x and spawn.x < ground.end.x,
			"Spawn point %d stands on the plaza ground" % seat_index,
		)

	var display := world.billboard.find_child("Display", true, false) as MeshInstance3D
	check(
		display != null and display.material_override is StandardMaterial3D
		and (display.material_override as StandardMaterial3D).albedo_texture != null,
		"The billboard display shows its runtime screen",
	)
	world.billboard.show_join_url("http://192.168.0.2:8080")
	await process_frame
	var screen_size := Vector2(world.billboard.get_node("Screen").size)
	check(
		world.billboard.qr.size.x >= screen_size.x * 0.9
		and world.billboard.qr.size.y >= screen_size.y * 0.9,
		"The join QR fills the billboard display",
	)

	var sign_bounds := _sign_bounds(world)
	var roof_span := world.get_node("Plaza/Cafe/Landing") as PlazaLanding
	var roof_top := roof_span.global_position.y
	check(
		absf(sign_bounds.position.y - roof_top) < 0.05
		and sign_bounds.get_center().x > roof_span.plane_span().position.x
		and sign_bounds.get_center().x < roof_span.plane_span().end.x,
		"The logo sign stands on the café roof",
	)
	check(
		sign_bounds.end.z < 0.0
		and world.logo_sign.find_children("*", "CollisionObject3D").is_empty(),
		"The logo sign is scenery behind the character plane",
	)

	for size: Vector2i in SIZES:
		_check_framing(size)

	world.queue_free()
	await process_frame


## Every landing's ends, and a character standing on each, must be on screen.
func _check_framing(size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = size
	root.add_child(viewport)
	var world := WORLD.instantiate() as LobbyPlaygroundWorld
	viewport.add_child(world)
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	for landing: PlazaLanding in world.landings():
		var span := landing.plane_span()
		if landing.name == &"GroundLanding":
			# The ground runs past the side walls, which keep characters in view instead.
			var ground := world.surface_named("GroundLanding").world_bounds()
			var walls := world.get_node("Simulation/PlatformSurfaces")
			check(
				ground.position.x < (walls.get_node("LeftWall") as Node2D).position.x
				and ground.end.x > (walls.get_node("RightWall") as Node2D).position.x,
				"The ground reaches both side walls at %s" % size,
			)
			continue
		for x: float in [span.position.x, span.end.x]:
			for height: float in [0.0, 1.0]:
				var point := world.camera.unproject_position(
					Vector3(x, span.position.y + height, 0.0)
				)
				check(
					screen.has_point(point),
					"%s at %s keeps its %s visible"
					% [
						landing.get_parent().name,
						size,
						"edge" if height == 0.0 else "standing character",
					],
				)
	var sign_bounds := _sign_bounds(world)
	var sign_on_screen := true
	for corner: int in 8:
		var point := world.camera.unproject_position(sign_bounds.get_endpoint(corner))
		sign_on_screen = sign_on_screen and screen.has_point(point)
	check(sign_on_screen, "The whole logo sign is on screen at %s" % size)
	viewport.queue_free()


func _sign_bounds(world: LobbyPlaygroundWorld) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in world.logo_sign.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
