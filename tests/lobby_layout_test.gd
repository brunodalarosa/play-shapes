extends TestScript
## The lobby controls sit in one padded top-right panel at both 16:9 host sizes, and the
## billboard carries the live join QR.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]
const MIN_PADDING := 24.0
const SIGN_TOP_RIGHT := Vector3(3.7, 4.6, 0.0)
const CONTROLS: Array[String] = [
	"AddressPicker",
	"Refresh",
	"Copy",
	"JoinAddress",
	"Instructions",
	"MinigameSelector",
	"StartMinigame",
	"StartHelp",
]


func _run() -> void:
	for size: Vector2i in SIZES:
		if not await _check_size(size):
			return


func _check_size(size: Vector2i) -> bool:
	var viewport := SubViewport.new()
	viewport.size = size
	root.add_child(viewport)
	var lobby := load("res://scenes/lobby.tscn").instantiate() as Control
	viewport.add_child(lobby)
	await process_frame
	await process_frame
	var canvas := Rect2(Vector2.ZERO, Vector2(size))
	var panel := lobby.get_node("%ControlPanel") as Control
	var area := panel.get_global_rect()
	if not check(
		canvas.encloses(area) and canvas.end.x - area.end.x >= MIN_PADDING
		and area.position.y >= MIN_PADDING and area.position.x > canvas.size.x * 0.5
		and area.end.y < canvas.size.y * 0.6,
		"The control panel sits in the top-right corner, clear of the edges at %s" % size,
	):
		return false
	for name: String in CONTROLS:
		var control := lobby.get_node("%" + name) as Control
		if not check(
			area.grow(1.0).encloses(control.get_global_rect()),
			"%s is inside the control panel at %s" % [name, size],
		):
			return false
	if not check(
		lobby.find_child("PlayerRoster", true, false) == null
		and lobby.find_child("PlayerSection", true, false) == null,
		"No old roster panel remains",
	):
		return false

	var world: LobbyPlaygroundWorld = lobby.world
	var camera := world.camera
	# The board's top edge in the model, above its own origin.
	var billboard_top := camera.unproject_position(world.billboard.to_global(Vector3.UP * 11.0))
	var roof := world.surface_named("Cafe").world_bounds()
	var roof_end := camera.unproject_position(LobbyPlaygroundWorld.to_world(roof.end))
	# The logo sign's top corner nearest the panel.
	var sign_corner := camera.unproject_position(world.logo_sign.to_global(SIGN_TOP_RIGHT))
	var covers_landmark := (
		area.has_point(billboard_top) or area.has_point(roof_end) or area.has_point(sign_corner)
	)
	if not check(
		billboard_top.y > 0.0 and sign_corner.y > 0.0 and not covers_landmark,
		"The panel leaves the billboard, the café roof and its logo sign in view at %s" % size,
	):
		return false

	var picker := lobby.get_node("%AddressPicker") as OptionButton
	var instructions := lobby.get_node("%Instructions") as Label
	var join_address := lobby.get_node("%JoinAddress") as Label
	if picker.item_count > 0:
		var offers_scan := instructions.text.contains("scan")
		if not check(offers_scan, "Join instructions match the billboard QR"):
			return false
		if not check(
			world.billboard.is_showing_qr()
			and world.billboard.qr.data == join_address.text.to_utf8_buffer(),
			"The displayed join URL supplies the billboard's live QR",
		):
			return false
		if not check(
			not (lobby.get_node("%Copy") as Button).disabled,
			"Detected LAN address keeps copy available",
		):
			return false
		var selected_address := picker.get_item_text(picker.selected)
		(lobby.get_node("%Refresh") as Button).pressed.emit()
		if not check(
			picker.get_item_text(picker.selected) == selected_address
			and join_address.text.contains(selected_address),
			"Refreshing keeps the selected reachable address",
		):
			return false
	elif not check(
		(lobby.get_node("%Copy") as Button).disabled
		and instructions.text.contains("refresh") and not world.billboard.is_showing_qr(),
		"No LAN address disables copy, hides the QR and explains refresh",
	):
		return false
	if not check(
		(lobby.get_node("%StartMinigame") as Button).disabled,
		"Start is disabled before players join",
	):
		return false
	viewport.queue_free()
	await process_frame
	return true
