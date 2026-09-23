extends Control

@onready var address_picker: OptionButton = %AddressPicker
@onready var qr: QRCodeRect = %JoinQR
@onready var join_address: Label = %JoinAddress
@onready var roster: GridContainer = %PlayerRoster
@onready var minigame_selector: OptionButton = %MinigameSelector
@onready var start_button: Button = %StartMinigame
@onready var start_help: Label = %StartHelp

const MINIGAMES := [
	{"id": &"flash_pose", "name": "Flash? Pose!"},
	{"id": &"bubbles", "name": "Bubbles and Jellyfishes"},
]

func _ready() -> void:
	SessionHost.set_accepting_new_players(true)
	SessionHost.players_changed.connect(_show_players)
	address_picker.item_selected.connect(_select_address)
	for minigame: Dictionary in MINIGAMES:
		minigame_selector.add_item(String(minigame.name))
		minigame_selector.set_item_metadata(minigame_selector.item_count - 1, minigame.id)
	minigame_selector.item_selected.connect(_on_minigame_selected)
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
	# A second column above ten players keeps the full 20-player lobby readable
	# at the shorter supported 16:9 height without making the page scroll.
	roster.columns = 2 if players.size() > 10 else 1
	%PlayerCount.text = "%d / %d players" % [players.size(), SessionHost.settings.max_players]
	%EmptyRoster.visible = players.is_empty()
	for player: Dictionary in players:
		var row := Label.new()
		row.text = "%d. %s — %s" % [player.seat, player.name,
			"Connected" if player.state == "connected" else "Reconnecting"]
		row.custom_minimum_size.y = 27.0
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 20 if players.size() > 10 else 18)
		roster.add_child(row)
	_update_start_state()

func _on_minigame_selected(_index: int) -> void:
	_update_start_state()

func _selected_minigame_id() -> StringName:
	if minigame_selector.selected < 0:
		return SessionHost.MINIGAME_FLASH_POSE
	return StringName(minigame_selector.get_item_metadata(minigame_selector.selected))

func _update_start_state() -> void:
	var minigame_id := _selected_minigame_id()
	var availability := SessionHost.minigame_availability(minigame_id)
	start_button.disabled = not bool(availability.available)
	start_help.text = str(availability.reason) if not bool(availability.available) \
		else "Starts %s for the registered players above." % SessionHost.minigame_display_name(minigame_id)

func _start_minigame() -> void:
	var minigame_id := _selected_minigame_id()
	var result := SessionHost.prepare_minigame_launch(minigame_id)
	if not bool(result.accepted):
		start_help.text = str(result.reason)
		return
	start_button.disabled = true
	var error := get_tree().change_scene_to_file(SessionHost.minigame_scene_path(minigame_id))
	if error != OK:
		SessionHost.clear_minigame_launch(minigame_id)
		SessionHost.set_accepting_new_players(true)
		start_help.text = "Could not open %s (error %d)." % [SessionHost.minigame_display_name(minigame_id), error]
		_update_start_state()
