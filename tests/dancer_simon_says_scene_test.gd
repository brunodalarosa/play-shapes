extends SceneTree
## Focused structural checks for the editor-authored Flash? Pose! stage.

const STAGE_SCENE: PackedScene = preload("res://minigames/dancer_simon_says.tscn")
const EXPECTED_ENVIRONMENT_TEXTURES: Array[String] = [
	"res://assets/runtime/shape_characters/environment/tree_small.png",
	"res://assets/runtime/shape_characters/environment/floor_left.png",
	"res://assets/runtime/shape_characters/environment/floor_center.png",
	"res://assets/runtime/shape_characters/environment/floor_right.png",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := STAGE_SCENE.instantiate() as Control
	root.add_child(stage)
	await process_frame
	if not _check(stage != null, "Stage instantiates with its typed script"):
		return
	if not _check(stage.scene_file_path == "res://minigames/dancer_simon_says.tscn", "Reserved scene path stays stable"):
		return
	var lead := stage.call("lead_slot") as Control
	var seats: Array = stage.call("player_slots") as Array
	var stage_art := stage.get_node(^"StageArt") as Control
	var lead_platform := stage_art.get_node(^"LeadPlatformCenter") as Control
	var player_platform := stage_art.get_node(^"PlayerPlatformCenter") as Control
	if not _check(lead.name == &"LeadSlot" and lead.is_in_group(&"flash_pose_lead_slot"), "One named lead slot is available"):
		return
	if not _check(lead_platform.anchor_bottom - lead_platform.anchor_top <= 0.15, "Lead tiles keep a shallow non-stretched profile"):
		return
	if not _check(player_platform.anchor_bottom - player_platform.anchor_top <= 0.15, "Player tiles keep a shallow non-stretched profile"):
		return
	if not _check(lead.anchor_top < lead_platform.anchor_top, "Lead feet are authored above the platform surface"):
		return
	if not _check(seats.size() == 10, "Exactly ten persistent player seats are available"):
		return
	var seen_anchors: Dictionary = {}
	for index: int in seats.size():
		var seat := seats[index] as Control
		var expected_name := "Seat%02d" % (index + 1)
		if not _check(seat.name == expected_name, "%s has a stable name" % expected_name):
			return
		if not _check(seat.is_in_group(&"flash_pose_player_seat"), "%s is discoverable as a player seat" % expected_name):
			return
		if not _check(is_equal_approx(seat.anchor_left, seat.anchor_right) and is_equal_approx(seat.anchor_top, seat.anchor_bottom), "%s is an editor-authored screen-relative point" % expected_name):
			return
		if not _check(seat.anchor_left >= 0.079 and seat.anchor_left <= 0.921, "%s stays inside the authored lower safe area" % expected_name):
			return
		if not _check(seat.anchor_top < player_platform.anchor_top, "%s places the character feet above the player platform" % expected_name):
			return
		if not _check(not seen_anchors.has(seat.anchor_left), "%s has a unique placement" % expected_name):
			return
		if not _check(seat.get_node_or_null(^"AnchorMarker") is Marker2D, "%s keeps an editor marker" % expected_name):
			return
		if not _check(seat.get_node_or_null(^"PreviewCharacter") is ShapeCharacter, "%s previews the production character scene" % expected_name):
			return
		seen_anchors[seat.anchor_left] = true
	stage.set("preview_player_count", 2)
	await process_frame
	for index: int in seats.size():
		var preview := seats[index].get_node(^"PreviewCharacter") as CanvasItem
		if not _check(preview.visible == (index < 2), "Two-player preview changes visibility without removing seats"):
			return
	if not _check((seats[0] as Control).anchor_left < 0.5 and (seats[1] as Control).anchor_left > 0.5, "Two-player preview is centered around the lead"):
		return
	if not _check((stage.call("player_slots") as Array).size() == 10, "Preview count never changes the stable seat structure"):
		return
	var seen_textures: Dictionary = {}
	for node: Node in stage.get_node(^"StageArt").get_children():
		if node is TextureRect and (node as TextureRect).texture != null:
			seen_textures[(node as TextureRect).texture.resource_path] = true
	for path: String in EXPECTED_ENVIRONMENT_TEXTURES:
		if not _check(seen_textures.has(path), "Stage references selected environment asset %s" % path):
			return
	stage.queue_free()
	await process_frame
	print("Dancer Simon Says scene checks passed: stable lead, ten seats, 2-player preview, and curated environment references")
	quit(0)


func _check(condition: bool, description: String) -> bool:
	if not condition:
		push_error(description)
		quit(1)
	return condition
