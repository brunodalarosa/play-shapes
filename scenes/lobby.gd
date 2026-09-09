extends Control

@onready var address_picker: OptionButton = %AddressPicker
@onready var qr: QRCodeRect = %JoinQR
@onready var join_address: Label = %JoinAddress

func _ready() -> void:
	SessionHost.connection_count_changed.connect(_show_count)
	address_picker.item_selected.connect(_select_address)
	%Refresh.pressed.connect(_refresh_addresses)
	%Copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(join_address.text))
	_refresh_addresses()

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

func _show_count(count: int) -> void:
	%Connections.text = "%d browser connection%s" % [count, "" if count == 1 else "s"]
