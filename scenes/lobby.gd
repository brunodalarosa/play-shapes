extends Control

@onready var address_picker: OptionButton = %AddressPicker
@onready var qr: QRCodeRect = %JoinQR
@onready var join_address: Label = %JoinAddress
@onready var minigame_selector: OptionButton = %MinigameSelector
@onready var start_button: Button = %StartMinigame
@onready var start_help: Label = %StartHelp
@onready var world: LobbyPlaygroundWorld = $World

const MINIGAMES := [{ "id": &"bubbles", "name": "Bubbles and Jellyfishes" }]


func _ready() -> void:
	SessionHost.set_accepting_new_players(true)
	SessionHost.players_changed.connect(_on_players_changed)
	SessionHost.register_lobby_controller(world)
	world.reconcile(SessionHost.players())
	_style_controls()
	address_picker.item_selected.connect(_select_address)
	for minigame: Dictionary in MINIGAMES:
		minigame_selector.add_item(String(minigame.name))
		minigame_selector.set_item_metadata(minigame_selector.item_count - 1, minigame.id)
	minigame_selector.item_selected.connect(_on_minigame_selected)
	%Refresh.pressed.connect(_refresh_addresses)
	%Copy.pressed.connect(
		func() -> void:
			DisplayServer.clipboard_set(join_address.text),
	)
	start_button.pressed.connect(_start_minigame)
	_refresh_addresses()
	_update_start_state()


func _exit_tree() -> void:
	SessionHost.unregister_lobby_controller(world)
	SessionHost.set_accepting_new_players(false)


func _refresh_addresses() -> void:
	var previous := address_picker.get_item_text(address_picker.selected) if address_picker.selected >= 0 else ""
	address_picker.clear()
	var addresses := SessionHost.addresses()
	for address: String in addresses:
		address_picker.add_item(address)
	if addresses.is_empty():
		qr.hide()
		%JoinQRBackground.hide()
		%Copy.disabled = true
		%Instructions.text = "Connect this PC to your local network, then refresh."
		join_address.text = "No LAN address. Connect to Wi-Fi and refresh."
		return
	var selected := maxi(addresses.find(previous), 0)
	address_picker.select(selected)
	_select_address(selected)


func _select_address(index: int) -> void:
	join_address.text = SessionHost.join_url(address_picker.get_item_text(index))
	qr.data = join_address.text.to_utf8_buffer()
	qr.update()
	qr.show()
	%JoinQRBackground.show()
	%Instructions.text = "Connect your phone to the same network, then scan."
	%Copy.disabled = false


func _on_players_changed(players: Array[Dictionary]) -> void:
	world.reconcile(players)
	_update_start_state()


func _on_minigame_selected(_index: int) -> void:
	_update_start_state()


func _selected_minigame_id() -> StringName:
	if minigame_selector.selected < 0:
		return SessionHost.MINIGAME_BUBBLES
	return StringName(minigame_selector.get_item_metadata(minigame_selector.selected))


func _update_start_state() -> void:
	var minigame_id := _selected_minigame_id()
	var availability := SessionHost.minigame_availability(minigame_id)
	start_button.disabled = not bool(availability.available)
	start_help.text = str(availability.reason) if not bool(availability.available) \
			else "Ready to start %s." % SessionHost.minigame_display_name(minigame_id)


func _style_controls() -> void:
	var board_normal := _rounded_style(Color("#075c52"), Color("#95dcc2"), 12)
	var board_hover := _rounded_style(Color("#108875"), Color("#e1ffec"), 12)
	var board_disabled := _rounded_style(Color("#53736b"), Color("#869e91"), 12)
	for control: BaseButton in [%AddressPicker, %Refresh, %Copy]:
		_style_button(control, board_normal, board_hover, board_disabled, 17)
	var selector_normal := _rounded_style(Color("#1c344f"), Color("#8baabd"), 14)
	var selector_hover := _rounded_style(Color("#294c6a"), Color("#bedde5"), 14)
	_style_button(minigame_selector, selector_normal, selector_hover, selector_normal, 22)
	var start_normal := _rounded_style(Color("#009d7c"), Color("#b2e9ba"), 20)
	var start_hover := _rounded_style(Color("#13b48f"), Color("#e2ffe4"), 20)
	var start_disabled := _rounded_style(Color("#66817a"), Color("#9caf9e"), 20)
	_style_button(start_button, start_normal, start_hover, start_disabled, 21)


func _style_button(
	button: BaseButton,
	normal: StyleBoxFlat,
	hover: StyleBoxFlat,
	disabled: StyleBoxFlat,
	font_size: int,
) -> void:
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#f0f5f0"))
	button.add_theme_font_size_override("font_size", font_size)


func _rounded_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _start_minigame() -> void:
	var minigame_id := _selected_minigame_id()
	var result := SessionHost.begin_pre_minigame(minigame_id)
	if not bool(result.accepted):
		start_help.text = str(result.reason)
		return
	world.clear_all_input()
	start_button.disabled = true
	var error := get_tree().change_scene_to_file("res://scenes/pre_minigame_screen.tscn")
	if error != OK:
		SessionHost.cancel_pre_minigame()
		SessionHost.set_accepting_new_players(true)
		start_help.text = "Could not open %s (error %d)." % [
			SessionHost.minigame_display_name(minigame_id),
			error,
		]
		_update_start_state()
