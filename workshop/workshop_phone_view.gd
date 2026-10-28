class_name WorkshopPhoneView
extends VBoxContainer
## The real phone page in a phone-shaped frame, signed in as the designer's player.
##
## The page runs in a godot-wry WebView, a native window drawn over the game window. That
## add-on places it by the control's screen position but takes the control's size as physical
## pixels, so the frame scales it by the window's stretch itself.

signal page_message(message: Dictionary)

## Device sizes worth checking, in CSS pixels, portrait.
const DEVICES: Array[Dictionary] = [
	{ "name": "Small phone 360 × 740", "size": Vector2(360, 740) },
	{ "name": "Phone 393 × 852", "size": Vector2(393, 852) },
	{ "name": "Large phone 430 × 932", "size": Vector2(430, 932) },
	{ "name": "Wide phone 412 × 915", "size": Vector2(412, 915) },
]
const WEB_VIEW_CLASS := &"WebView"
const STORAGE_SESSION := "play-shapes.session-id"
const STORAGE_TOKEN := "play-shapes.reconnect-token"

var url := ""
var device_picker := OptionButton.new()
## The title bar readout a minigame fills, such as how much course the phone shows.
var readout := Label.new()
var web_view: Control
var _frame := AspectRatioContainer.new()
var _screen := Panel.new()
var _message := Label.new()
var _session_id := ""
var _token := ""
var _signed_in := false
var _css_width_at_zoom_one := 0.0
var _zoom := 1.0


func _init() -> void:
	name = "PhoneView"
	var bar := HBoxContainer.new()
	add_child(bar)
	for device: Dictionary in DEVICES:
		device_picker.add_item(device.name)
	device_picker.selected = 1
	device_picker.item_selected.connect(_on_device)
	bar.add_child(device_picker)
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.modulate = Color(1, 1, 1, 0.75)
	bar.add_child(readout)
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_frame)
	_frame.add_child(_screen)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_screen.add_child(_message)
	_screen.resized.connect(_fit)
	_on_device(device_picker.selected)


## The device size the frame shows, in CSS pixels.
func device_size() -> Vector2:
	return DEVICES[device_picker.selected].size


## Opens the page at [param page_url], signed in with the registry's [param session_id] and
## [param reconnect_token]. Without the add-on or a display, shows why instead.
func open(page_url: String, session_id: String, reconnect_token: String) -> void:
	url = page_url
	_session_id = session_id
	_token = reconnect_token
	_signed_in = false
	if web_view != null:
		web_view.call(&"load_url", url)
		return
	if DisplayServer.get_name() == "headless" or not ClassDB.class_exists(WEB_VIEW_CLASS):
		_message.text = "The phone view needs the godot-wry add-on and a display.\n%s" % url
		return

	_message.text = ""
	web_view = ClassDB.instantiate(WEB_VIEW_CLASS)
	web_view.set(&"full_window_size", false)
	web_view.set(&"url", url)
	web_view.set(&"data_directory", "user://workshops/phone_view")
	web_view.set(&"forward_input_events", false)
	web_view.set(&"zoom_hotkeys", false)
	web_view.connect(&"page_load_finished", _on_page_loaded)
	web_view.connect(&"ipc_message", _on_ipc)
	_screen.add_child(web_view)
	_fit.call_deferred()


## Runs [param script] in the page.
func run(script: String) -> void:
	if web_view != null:
		web_view.call(&"eval", script)


## Asks the page for its size and text; the answer comes back through [signal page_message].
func probe() -> void:
	run(
		"window.ipc.postMessage(JSON.stringify({type: 'workshop_probe',"
		+ " width: innerWidth, height: innerHeight,"
		+ " text: document.body.innerText.slice(0, 400)}))"
	)


func _on_page_loaded(_loaded_url: String) -> void:
	if _signed_in:
		probe()
		return
	# The page resumes the player stored for this origin, so store the designer's and reload.
	_signed_in = true
	run(
		"localStorage.setItem(%s, %s); localStorage.setItem(%s, %s); location.reload();"
		% [
			JSON.stringify(STORAGE_SESSION),
			JSON.stringify(_session_id),
			JSON.stringify(STORAGE_TOKEN),
			JSON.stringify(_token),
		]
	)


func _on_ipc(text: String) -> void:
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary:
		return
	if message.get("type") == "workshop_probe" and float(message.get("width", 0.0)) > 0.0:
		_css_width_at_zoom_one = float(message.width) * _zoom
		_apply_zoom()
	page_message.emit(message)


func _on_device(index: int) -> void:
	var device: Vector2 = DEVICES[index].size
	_frame.ratio = device.x / device.y
	_apply_zoom()
	probe()


## Sizes the native page to the frame in physical pixels.
func _fit() -> void:
	if web_view == null:
		return
	var stretch := get_viewport().get_final_transform().get_scale()
	web_view.position = Vector2.ZERO
	web_view.size = _screen.size * stretch
	probe()


## Zooms the page so it lays out at the device's CSS width.
func _apply_zoom() -> void:
	if web_view == null or _css_width_at_zoom_one <= 0.0:
		return
	var zoom := _css_width_at_zoom_one / device_size().x
	if absf(zoom - _zoom) > 0.01:
		_zoom = zoom
		web_view.call(&"zoom", zoom)
