class_name WorkshopPhoneView
extends HBoxContainer
## The real phone page in a phone-shaped frame, signed in as the designer's player.
##
## The page runs in a godot-wry WebView, a native window drawn over the game window and placed
## in its physical pixels; [method _place_page] keeps it over the frame.

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
## A readout the minigame fills, such as how much course the phone shows.
var readout := Label.new()
var web_view: Control
var _frame := AspectRatioContainer.new()
## The phone's body, and its screen inside the bezel, where the page goes.
var _body := Panel.new()
var _screen := Control.new()
var _message := Label.new()
var _session_id := ""
var _token := ""
var _signed_in := false
var _css_width_at_zoom_one := 0.0
var _zoom := 1.0


func _init() -> void:
	name = "PhoneView"
	add_theme_constant_override(&"separation", 16)
	_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.size_flags_stretch_ratio = 1.2
	add_child(_frame)
	_body.theme_type_variation = &"PhoneFrame"
	_frame.add_child(_body)
	WorkshopTheme.fill(_screen, 10)
	_body.add_child(_screen)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(&"separation", 12)
	add_child(column)
	for device: Dictionary in DEVICES:
		device_picker.add_item(device.name)
	device_picker.selected = 1
	device_picker.item_selected.connect(_on_device)
	column.add_child(device_picker)
	var help := Label.new()
	help.text = (
		"The real phone page, served by the workshop and connected as you. "
		+ "Click it or press Space on it to flap."
	)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.theme_type_variation = &"BodyLabel"
	column.add_child(help)
	var card := PanelContainer.new()
	card.theme_type_variation = &"InfoCard"
	column.add_child(card)
	readout.theme_type_variation = &"ReadoutLabel"
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(readout)
	var reload := Button.new()
	reload.text = "Reload page"
	reload.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reload.pressed.connect(
		func() -> void:
			open(url, _session_id, _token),
	)
	column.add_child(reload)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.theme_type_variation = &"HelpLabel"
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


func _fit() -> void:
	_place_page()
	probe()


func _process(_delta: float) -> void:
	# Runs before the WebView's own process, which moves the page when its position changes.
	_place_page()


## Puts the native page over the frame, in the window's physical pixels.
##
## The add-on places the page at the control's screen position, which adds the window's place
## on the screen when subwindows are not embedded and leaves out the stretch when they are, and
## it reads the control's size as physical pixels. So the control goes wherever makes that
## screen position the frame's pixel position in the window, at the frame's pixel size.
func _place_page() -> void:
	if web_view == null or not web_view.is_inside_tree():
		return
	var to_pixels := get_viewport().get_final_transform()
	var wanted := to_pixels * _screen.get_global_transform_with_canvas().origin
	var to_screen := (
		web_view.get_screen_transform()
		* web_view.get_global_transform_with_canvas().affine_inverse()
	)
	var position_for_wanted := to_screen.affine_inverse() * wanted
	if not web_view.global_position.is_equal_approx(position_for_wanted):
		web_view.global_position = position_for_wanted
	var pixel_size := _screen.size * to_pixels.get_scale()
	if not web_view.size.is_equal_approx(pixel_size):
		web_view.size = pixel_size


## Zooms the page so it lays out at the device's CSS width.
func _apply_zoom() -> void:
	if web_view == null or _css_width_at_zoom_one <= 0.0:
		return
	var zoom := _css_width_at_zoom_one / device_size().x
	if absf(zoom - _zoom) > 0.01:
		_zoom = zoom
		web_view.call(&"zoom", zoom)
