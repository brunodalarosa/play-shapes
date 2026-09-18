extends Control

@onready var address_picker: OptionButton = %AddressPicker
@onready var qr: QRCodeRect = %JoinQR
@onready var join_address: Label = %JoinAddress
@onready var roster: VBoxContainer = %PlayerRoster
@onready var start_button: Button = %StartMinigame
@onready var start_help: Label = %StartHelp

func _ready() -> void:
	SessionHost.set_accepting_new_players(true)
	SessionHost.players_changed.connect(_show_players)
	address_picker.item_selected.connect(_select_address)
	%Refresh.pressed.connect(_refresh_addresses)
	%Copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(join_address.text))
	start_button.pressed.connect(_start_minigame)
	_refresh_addresses()
	_show_players(SessionHost.players())

func _exit_tree() -> void:
	SessionHost.set_accepting_new_players(false)

func _refresh_addresses() -> void:
	var previous := address_picker.get_item_text(address_picker.selected) if address_picker.selected >= 0 else ""
	address_picker.clear()
	var addresses := SessionHost.addresses()
	for address: String in addresses:
		address_picker.add_item(address)
	if addresses.is_empty():
		qr.hide()
		%Copy.disabled = true
		join_address.text = "No LAN IPv4 address found. Connect to Wi-Fi and refresh."
		return
	var selected := maxi(addresses.find(previous), 0)
	address_picker.select(selected)
	_select_address(selected)

func _select_address(index: int) -> void:
	join_address.text = SessionHost.join_url(address_picker.get_item_text(index))
	qr.data = join_address.text.to_utf8_buffer()
	qr.update()
	qr.show()
	%Copy.disabled = false

func _show_players(players: Array[Dictionary]) -> void:
	for child: Node in roster.get_children():
		child.queue_free()
	%PlayerCount.text = "%d / %d players" % [players.size(), SessionHost.settings.max_players]
	%EmptyRoster.visible = players.is_empty()
	for player: Dictionary in players:
		var row := Label.new()
		row.text = "%d. %s — %s" % [player.seat, player.name,
			"Connected" if player.state == "connected" else "Reconnecting"]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 18)
		roster.add_child(row)
	var availability := SessionHost.flash_pose_availability(false)
	start_button.disabled = not bool(availability.available)
	start_help.text = str(availability.reason) if not bool(availability.available) \
		else "Starts Flash? Pose! for the registered players above."

func _start_minigame() -> void:
	var result := SessionHost.prepare_flash_pose_launch(false)
	if not bool(result.accepted):
		start_help.text = str(result.reason)
		return
	start_button.disabled = true
	get_tree().change_scene_to_file(SessionHost.FLASH_POSE_SCENE_PATH)
