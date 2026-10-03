extends SceneTree
## Checks the editor-authored empty world's art, landing geometry, and placement guides.

const WORLD := preload("res://scenes/lobby_playground_world.tscn")
const CANVAS := Vector2(1920, 1080)
const PLATFORM_LAYER := 128
var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := WORLD.instantiate() as Node2D
	root.add_child(world)
	var surfaces := world.get_node("PlatformSurfaces")
	var expected_shelves := { "UpperShelf": 400.0, "LowerShelf": 675.0, "BottomShelf": 945.0 }
	for shelf_name: String in expected_shelves:
		var shelf := surfaces.get_node(shelf_name) as StaticBody2D
		var shape := shelf.get_node("LandingTop") as CollisionShape2D
		_check(
			_top(shape) == expected_shelves[shelf_name],
			"%s landing edge follows its visible wooden top" % shelf_name,
		)
		_check(
			(shape.shape as RectangleShape2D).size.x >= 1700.0,
			"%s leaves broad standing width" % shelf_name,
		)
	_check(
		surfaces.get_child_count() >= 8,
		"Wooden shelves and selected blocks have separate surfaces",
	)
	for body: Node in surfaces.get_children():
		var platform := body as StaticBody2D
		_check(
			platform != null and platform.collision_layer == PLATFORM_LAYER
			and platform.collision_mask == 0,
			"%s uses the reserved platform layer" % body.name,
		)
		_check(
			platform is PlatformSurface
			and platform.drop_rule
			== (
				PlatformSurface.DropRule.CLOSED
				if body.name == "BottomShelf"
				else PlatformSurface.DropRule.OPEN
			),
			"%s exposes its independent authored drop rule" % body.name,
		)
		_check(
			platform.get_child_count() == 1,
			"%s has one inspectable landing surface" % body.name,
		)
		var shape := platform.get_child(0) as CollisionShape2D
		_check(
			shape.one_way_collision and shape.shape is RectangleShape2D,
			"%s is a one-way top rectangle" % body.name,
		)
		var rect := Rect2(
			shape.global_position - (shape.shape as RectangleShape2D).size / 2.0,
			(shape.shape as RectangleShape2D).size,
		)
		_check(
			rect.position.x >= 0.0 and rect.end.x <= CANVAS.x
			and rect.position.y >= 0.0 and rect.end.y <= CANVAS.y,
			"%s fits the reference canvas" % body.name,
		)
	var blocks := world.get_node("BuildingBlocks")
	for body: Node in surfaces.get_children():
		if expected_shelves.has(body.name):
			continue
		var sprite := blocks.get_node(String(body.name)) as Sprite2D
		var shape := body.get_node("LandingTop") as CollisionShape2D
		var visible_width := sprite.texture.get_width() * sprite.scale.x
		_check(
			absf(_top(shape) - sprite.position.y) <= 4.0
			and (shape.shape as RectangleShape2D).size.x <= visible_width
			and absf(shape.position.x - (sprite.position.x + visible_width / 2.0)) <= 3.0,
			"%s landing rectangle follows its rendered block top" % body.name,
		)
	for asset_name: String in ["RoomBackground", "WoodenShelves", "Foreground"]:
		var sprite := world.get_node(asset_name) as Sprite2D
		_check(
			sprite.texture != null and sprite.texture.get_size() == CANVAS,
			"%s is an imported FHD layer" % asset_name,
		)
	_check(
		world.get_node("WoodenShelves").get_index() < world.get_node("RearDecorations").get_index()
		and world.get_node("PanelBackings").get_index()
		< world.get_node("CharactersFrontOfPanels").get_index()
		and world.get_node("CharactersFrontOfPanels").get_index()
		< world.get_node("Foreground").get_index(),
		"Decorations, panels, future characters, and foreground have distinct draw order",
	)
	for panel_name: String in ["GreenBoard", "MinigameCalendar"]:
		var panel := world.get_node("PanelBackings/" + panel_name) as Sprite2D
		_check(
			panel.texture != null and panel.texture.get_width() > 500,
			"%s has its own blank runtime art" % panel_name,
		)
	for decoration: Node in world.get_node("RearDecorations").get_children():
		_check(
			decoration is Sprite2D and (decoration as Sprite2D).texture != null,
			"%s is a decorative sprite without collision" % decoration.name,
		)
	var board_space := Rect2(650, 185, 620, 365)
	var calendar_space := Rect2(650, 550, 620, 250)
	for group: Node in [world.get_node("RearDecorations"), blocks]:
		for item: Node in group.get_children():
			var sprite := item as Sprite2D
			var rect := Rect2(sprite.position, sprite.texture.get_size() * sprite.scale)
			_check(
				not rect.intersects(board_space) and not rect.intersects(calendar_space),
				"%s leaves the future QR board and calendar regions clear" % item.name,
			)
	var anchors := world.get_node("FutureCharacterAnchors")
	_check(anchors.get_child_count() == 10, "Ten non-interactive placement guides are available")
	for anchor: Node in anchors.get_children():
		_check(
			anchor is Marker2D and anchor.position.x > 100.0 and anchor.position.x < 1820.0,
			"%s is a usable editor-only guide" % anchor.name,
		)
	world.queue_free()
	if _failures == 0:
		print("Lobby playground world geometry checks passed")
	quit(1 if _failures > 0 else 0)


func _top(shape: CollisionShape2D) -> float:
	return shape.position.y - (shape.shape as RectangleShape2D).size.y / 2.0


func _check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		_failures += 1
