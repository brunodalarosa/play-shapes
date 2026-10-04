extends TestScript
## Structural checks for the FHD reference layout used at both 16:9 host sizes.

const CANVAS := Vector2i(1920, 1080)


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = CANVAS
	root.add_child(viewport)
	var lobby := load("res://scenes/lobby.tscn").instantiate() as Control
	viewport.add_child(lobby)
	await process_frame
	await process_frame
	var panels := lobby.get_node("World/PanelBackings")
	if not check(
		panels.get_node("GreenBoard") is Sprite2D
		and panels.get_node("MinigameCalendar") is Sprite2D
		and panels.get_index() < lobby.get_node("World/CharactersFrontOfPanels").get_index(),
		"Board and calendar are in front of the world and behind future characters",
	):
		return
	if not check(
		lobby.get_node("World/CharactersFrontOfPanels").get_child_count() == 0,
		"Future character layer remains empty",
	):
		return
	if not check(
		lobby.find_child("PlayerRoster", true, false) == null
		and lobby.find_child("PlayerSection", true, false) == null,
		"No old roster panel remains",
	):
		return
	if not check(
		lobby.get_node("World/CharactersFrontOfPanels").z_index
		> lobby.get_node("LiveControls").z_index
		and lobby.get_node("World/Foreground").z_index
		> lobby.get_node("World/CharactersFrontOfPanels").z_index,
		"Characters draw over lobby controls and under the world foreground",
	):
		return
	for name: String in [
		"Logo",
		"JoinQR",
		"JoinAddress",
		"AddressPicker",
		"Refresh",
		"Copy",
		"MinigameSelector",
		"StartMinigame",
		"StartHelp",
	]:
		var control := lobby.get_node("LiveControls/" + name) as Control
		if not check(
			Rect2(Vector2.ZERO, Vector2(CANVAS)).encloses(control.get_global_rect()),
			"%s fits the FHD canvas" % name,
		):
			return
	var picker := lobby.get_node("%AddressPicker") as OptionButton
	var instructions := lobby.get_node_or_null("%Instructions") as Label
	if not check(instructions != null, "Join instructions resolve from the lobby script"):
		return
	if picker.item_count > 0:
		var offers_scan: bool = instructions.text.contains("scan")
		if not check(offers_scan, "Join instructions match the available QR"):
			return
		if not check(
			(lobby.get_node("%JoinQR") as QRCodeRect).data
			== (lobby.get_node("%JoinAddress") as Label).text.to_utf8_buffer(),
			"Displayed join URL supplies the live QR data",
		):
			return
		if not check(
			not (lobby.get_node("%Copy") as Button).disabled,
			"Detected LAN address keeps copy available",
		):
			return
		var selected_address := picker.get_item_text(picker.selected)
		(lobby.get_node("%Refresh") as Button).pressed.emit()
		if not check(
			picker.get_item_text(picker.selected) == selected_address
			and (lobby.get_node("%JoinAddress") as Label).text.contains(selected_address),
			"Refreshing keeps the selected reachable address",
		):
			return
	elif not check(
		(lobby.get_node("%Copy") as Button).disabled and instructions.text.contains("refresh"),
		"No LAN address disables copy and explains refresh",
	):
		return
	if not check(
		(lobby.get_node("%StartMinigame") as Button).disabled,
		"Start is disabled before players join",
	):
		return
	viewport.queue_free()
