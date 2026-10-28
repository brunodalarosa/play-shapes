class_name WorkshopTheme
extends RefCounted
## The workshop window's look, in Material Design 3's dark scheme
## (decision 0055): its colour roles, type scale, shapes and state layers, built as one Godot
## Theme. Controls take the default look of their kind; the named variations below cover the
## workshop's own parts, such as panel headers, chips and readouts.

## Colour roles of the dark scheme, from a blue seed.
const PRIMARY := Color("#adc6ff")
const ON_PRIMARY := Color("#002e69")
const PRIMARY_CONTAINER := Color("#2a4a85")
const ON_PRIMARY_CONTAINER := Color("#d8e2ff")
const SECONDARY_CONTAINER := Color("#3f4759")
const ON_SECONDARY_CONTAINER := Color("#dbe2f9")
const ERROR := Color("#ffb4ab")
const ERROR_CONTAINER := Color("#93000a")
const ON_ERROR_CONTAINER := Color("#ffdad6")
## An extended colour role, harmonized amber, for unsaved edits and values waiting for a restart.
const CAUTION := Color("#ffb95c")
const CAUTION_CONTAINER := Color("#5c4100")
const ON_CAUTION_CONTAINER := Color("#ffddb3")
const SURFACE := Color("#111318")
const SURFACE_CONTAINER_LOWEST := Color("#0c0e13")
const SURFACE_CONTAINER_LOW := Color("#191c20")
const SURFACE_CONTAINER := Color("#1d2024")
const SURFACE_CONTAINER_HIGH := Color("#282a2f")
const SURFACE_CONTAINER_HIGHEST := Color("#33353a")
const ON_SURFACE := Color("#e2e2e9")
const ON_SURFACE_VARIANT := Color("#c4c6d0")
const OUTLINE := Color("#8e9099")
const OUTLINE_VARIANT := Color("#44474f")
const INVERSE_SURFACE := Color("#e2e2e9")
const INVERSE_ON_SURFACE := Color("#2e3036")

## State layer opacities over a role's colour.
const HOVER_LAYER := 0.08
const PRESSED_LAYER := 0.12
const DISABLED_CONTAINER := 0.12
const DISABLED_CONTENT := 0.38

## Shape scale, in pixels at the 1920 × 1080 canvas.
const SHAPE_EXTRA_SMALL := 4
const SHAPE_SMALL := 8
const SHAPE_MEDIUM := 12
const SHAPE_LARGE := 16
const SHAPE_EXTRA_LARGE := 28
const SHAPE_FULL := 999

## Type scale sizes.
const TITLE_LARGE := 22
const TITLE_MEDIUM := 17
const BODY_LARGE := 16
const BODY_MEDIUM := 15
const LABEL_LARGE := 15
const LABEL_MEDIUM := 13
const LABEL_SMALL := 12

const ROBOTO := preload("res://workshop/fonts/Roboto.ttf")
const ROBOTO_MONO := preload("res://workshop/fonts/RobotoMono.ttf")

static var _theme: Theme


## The shared theme, built once.
static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Roboto at [param weight], 400 for body text and 500 for labels and titles.
static func font(weight := 400, mono := false, tracking := 0) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = ROBOTO_MONO if mono else ROBOTO
	variation.variation_opentype = {
		TextServerManager.get_primary_interface().name_to_tag("wght"): weight
	}
	variation.spacing_glyph = tracking
	return variation


## [param color] with a state layer of [param layer] on top, as Material draws hover and press.
static func layered(color: Color, layer_color: Color, layer: float) -> Color:
	return color.lerp(Color(layer_color, 1.0), layer)


## Makes [param control] fill its parent, [param margin] pixels in from every edge.
static func fill(control: Control, margin: float) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin


static func box(
	color: Color,
	radius := SHAPE_SMALL,
	padding := Vector2(0, 0),
	border := Color.TRANSPARENT,
	border_width := 0,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.corner_detail = 8
	style.content_margin_left = padding.x
	style.content_margin_right = padding.x
	style.content_margin_top = padding.y
	style.content_margin_bottom = padding.y
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	style.anti_aliasing = true
	return style


static func _build() -> Theme:
	var theme_built := Theme.new()
	theme_built.default_font = font(400)
	theme_built.default_font_size = BODY_LARGE
	_labels(theme_built)
	_buttons(theme_built)
	_fields(theme_built)
	_selection(theme_built)
	_containers(theme_built)
	_menus(theme_built)
	_workshop_parts(theme_built)
	return theme_built


static func _labels(t: Theme) -> void:
	t.set_color(&"font_color", &"Label", ON_SURFACE)
	_variation(t, &"TitleLabel", &"Label", font(500), TITLE_LARGE, ON_SURFACE)
	_variation(t, &"BodyLabel", &"Label", font(400), BODY_MEDIUM, ON_SURFACE_VARIANT)
	_variation(t, &"HelpLabel", &"Label", font(400), LABEL_MEDIUM, ON_SURFACE_VARIANT)
	_variation(t, &"SectionLabel", &"Label", font(600, false, 1), LABEL_SMALL, ON_SURFACE_VARIANT)
	_variation(t, &"PanelTitle", &"Label", font(600, false, 2), LABEL_MEDIUM, ON_SURFACE)
	_variation(t, &"ReadoutLabel", &"Label", font(500, true), LABEL_MEDIUM, ON_SURFACE)
	t.set_color(&"font_outline_color", &"ReadoutLabel", Color(0, 0, 0, 0.6))
	t.set_constant(&"outline_size", &"ReadoutLabel", 3)
	_variation(t, &"PanelNumber", &"Label", font(700), LABEL_SMALL, ON_PRIMARY_CONTAINER)
	t.set_stylebox(&"normal", &"PanelNumber", box(PRIMARY_CONTAINER, 6, Vector2(7, 1)))
	_variation(t, &"CautionChip", &"Label", font(600, false, 1), LABEL_SMALL, ON_CAUTION_CONTAINER)
	t.set_stylebox(&"normal", &"CautionChip", box(CAUTION_CONTAINER, SHAPE_SMALL, Vector2(10, 3)))
	_variation(t, &"QuietChip", &"Label", font(500), LABEL_MEDIUM, ON_SURFACE)
	var quiet := box(Color.TRANSPARENT, SHAPE_SMALL, Vector2(10, 4), OUTLINE_VARIANT, 1)
	t.set_stylebox(&"normal", &"QuietChip", quiet)


static func _buttons(t: Theme) -> void:
	# The default button is Material's tonal button.
	_button(t, &"Button", SECONDARY_CONTAINER, ON_SECONDARY_CONTAINER, SHAPE_FULL)
	_button(t, &"FilledButton", PRIMARY, ON_PRIMARY, SHAPE_FULL)
	t.set_type_variation(&"FilledButton", &"Button")
	_button(t, &"TextButton", Color(PRIMARY, 0.0), PRIMARY, SHAPE_FULL)
	t.set_type_variation(&"TextButton", &"Button")
	# Filter chips: outlined, filled with the secondary container while selected.
	_button(t, &"ChipButton", Color(SURFACE_CONTAINER, 0.0), ON_SURFACE_VARIANT, SHAPE_SMALL)
	t.set_type_variation(&"ChipButton", &"Button")
	var chip := t.get_stylebox(&"normal", &"ChipButton") as StyleBoxFlat
	chip.border_color = OUTLINE_VARIANT
	chip.set_border_width_all(1)
	var selected := box(SECONDARY_CONTAINER, SHAPE_SMALL, Vector2(14, 6))
	t.set_stylebox(&"pressed", &"ChipButton", selected)
	t.set_stylebox(&"hover_pressed", &"ChipButton", selected)
	t.set_color(&"font_pressed_color", &"ChipButton", ON_SECONDARY_CONTAINER)
	t.set_color(&"font_hover_pressed_color", &"ChipButton", ON_SECONDARY_CONTAINER)
	for kind: StringName in [&"Button", &"FilledButton", &"TextButton", &"ChipButton"]:
		t.set_font(&"font", kind, font(500))
		t.set_font_size(&"font_size", kind, LABEL_LARGE)


static func _button(t: Theme, kind: StringName, fill: Color, content: Color, radius: int) -> void:
	var padding := Vector2(18, 7) if radius == SHAPE_FULL else Vector2(14, 6)
	var normal := box(fill, radius, padding)
	var hover := box(layered(fill, content, HOVER_LAYER), radius, padding)
	var pressed := box(layered(fill, content, PRESSED_LAYER), radius, padding)
	if fill.a == 0.0:
		hover.bg_color = Color(content, HOVER_LAYER)
		pressed.bg_color = Color(content, PRESSED_LAYER)
	var disabled := box(Color(ON_SURFACE, DISABLED_CONTAINER), radius, padding)
	if fill.a == 0.0:
		disabled.bg_color = Color.TRANSPARENT
	var focus := box(Color.TRANSPARENT, radius, padding, PRIMARY, 2)
	focus.draw_center = false
	t.set_stylebox(&"normal", kind, normal)
	t.set_stylebox(&"hover", kind, hover)
	t.set_stylebox(&"pressed", kind, pressed)
	t.set_stylebox(&"hover_pressed", kind, pressed)
	t.set_stylebox(&"disabled", kind, disabled)
	t.set_stylebox(&"focus", kind, focus)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		t.set_color(state, kind, content)
	t.set_color(&"font_pressed_color", kind, content)
	t.set_color(&"font_hover_pressed_color", kind, content)
	t.set_color(&"font_disabled_color", kind, Color(ON_SURFACE, DISABLED_CONTENT))
	t.set_color(&"icon_normal_color", kind, content)
	t.set_constant(&"h_separation", kind, 8)


static func _fields(t: Theme) -> void:
	# Filled fields without the underline, on the highest container.
	var field := box(SURFACE_CONTAINER_HIGHEST, SHAPE_SMALL, Vector2(12, 6))
	var focused := box(SURFACE_CONTAINER_HIGHEST, SHAPE_SMALL, Vector2(12, 6), PRIMARY, 2)
	focused.draw_center = false
	for kind: StringName in [&"LineEdit", &"NumberEdit"]:
		t.set_stylebox(&"normal", kind, field)
		t.set_stylebox(&"focus", kind, focused)
		t.set_stylebox(&"read_only", kind, box(SURFACE_CONTAINER_HIGH, SHAPE_SMALL, Vector2(12, 6)))
		t.set_color(&"font_color", kind, ON_SURFACE)
		t.set_color(&"font_placeholder_color", kind, Color(ON_SURFACE_VARIANT, 0.7))
		t.set_color(&"caret_color", kind, PRIMARY)
		t.set_color(&"selection_color", kind, Color(PRIMARY, 0.35))
		t.set_color(&"clear_button_color", kind, ON_SURFACE_VARIANT)
	t.set_type_variation(&"NumberEdit", &"LineEdit")
	t.set_font(&"font", &"NumberEdit", font(500, true))
	t.set_font_size(&"font_size", &"NumberEdit", BODY_MEDIUM)
	t.set_icon(&"updown", &"SpinBox", _icon(_UPDOWN_SVG, ON_SURFACE_VARIANT))

	# The outlined menu field of Material's exposed dropdown.
	var menu := box(Color.TRANSPARENT, SHAPE_SMALL, Vector2(14, 6), OUTLINE, 1)
	var menu_hover := box(
		Color(ON_SURFACE, HOVER_LAYER),
		SHAPE_SMALL,
		Vector2(14, 6),
		ON_SURFACE,
		1,
	)
	var menu_focus := box(Color.TRANSPARENT, SHAPE_SMALL, Vector2(14, 6), PRIMARY, 2)
	menu_focus.draw_center = false
	t.set_stylebox(&"normal", &"OptionButton", menu)
	t.set_stylebox(&"hover", &"OptionButton", menu_hover)
	t.set_stylebox(&"pressed", &"OptionButton", menu_hover)
	t.set_stylebox(&"focus", &"OptionButton", menu_focus)
	t.set_stylebox(
		&"disabled",
		&"OptionButton",
		box(Color.TRANSPARENT, SHAPE_SMALL, Vector2(14, 6), OUTLINE_VARIANT, 1),
	)
	for state: StringName in [
		&"font_color",
		&"font_hover_color",
		&"font_pressed_color",
		&"font_focus_color",
	]:
		t.set_color(state, &"OptionButton", ON_SURFACE)
	t.set_icon(&"arrow", &"OptionButton", _icon(_ARROW_SVG, ON_SURFACE_VARIANT))
	t.set_constant(&"arrow_margin", &"OptionButton", 10)
	var arrow_menu := t.get_icon(&"arrow", &"OptionButton")
	t.set_icon(&"arrow", &"MenuButton", arrow_menu)
	_button(t, &"MenuButton", Color(ON_SURFACE, 0.0), ON_SURFACE_VARIANT, SHAPE_FULL)


static func _selection(t: Theme) -> void:
	# Slider: a thin inactive track, the active part and a round handle in the primary colour.
	var track := box(SECONDARY_CONTAINER, 3, Vector2(0, 3))
	var active := box(PRIMARY, 3, Vector2(0, 3))
	for kind: StringName in [&"HSlider"]:
		t.set_stylebox(&"slider", kind, track)
		t.set_stylebox(&"grabber_area", kind, active)
		t.set_stylebox(&"grabber_area_highlight", kind, active)
		t.set_icon(&"grabber", kind, _icon(_HANDLE_SVG, PRIMARY))
		t.set_icon(&"grabber_highlight", kind, _icon(_HANDLE_SVG, ON_PRIMARY_CONTAINER))
		t.set_icon(
			&"grabber_disabled",
			kind,
			_icon(_HANDLE_SVG, Color(ON_SURFACE, DISABLED_CONTENT)),
		)

	for kind: StringName in [&"CheckBox", &"CheckButton"]:
		_button(t, kind, Color(ON_SURFACE, 0.0), ON_SURFACE, SHAPE_FULL)
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
			var style := t.get_stylebox(state, kind) as StyleBoxFlat
			style.content_margin_left = 6
			style.content_margin_right = 10
		t.set_font(&"font", kind, font(500))
		t.set_font_size(&"font_size", kind, LABEL_LARGE)
	t.set_icon(&"checked", &"CheckBox", _icon(_CHECKED_SVG, PRIMARY))
	t.set_icon(&"unchecked", &"CheckBox", _icon(_UNCHECKED_SVG, ON_SURFACE_VARIANT))
	t.set_icon(
		&"checked_disabled",
		&"CheckBox",
		_icon(_CHECKED_SVG, Color(ON_SURFACE, DISABLED_CONTENT)),
	)
	t.set_icon(
		&"unchecked_disabled",
		&"CheckBox",
		_icon(_UNCHECKED_SVG, Color(ON_SURFACE, DISABLED_CONTENT)),
	)
	t.set_icon(&"checked", &"CheckButton", _icon(_SWITCH_ON_SVG, PRIMARY, ON_PRIMARY))
	t.set_icon(
		&"unchecked",
		&"CheckButton",
		_icon(_SWITCH_OFF_SVG, OUTLINE, SURFACE_CONTAINER_HIGHEST),
	)

	# Primary tabs: the selected one marked by a primary indicator under its label.
	var selected := box(Color.TRANSPARENT, 0, Vector2(20, 9))
	selected.border_color = PRIMARY
	selected.border_width_bottom = 3
	var unselected := box(Color.TRANSPARENT, 0, Vector2(20, 9))
	unselected.border_color = OUTLINE_VARIANT
	unselected.border_width_bottom = 1
	var hovered := box(Color(ON_SURFACE, HOVER_LAYER), 0, Vector2(20, 9))
	hovered.border_color = OUTLINE_VARIANT
	hovered.border_width_bottom = 1
	for kind: StringName in [&"TabContainer", &"TabBar"]:
		t.set_stylebox(&"tab_selected", kind, selected)
		t.set_stylebox(&"tab_unselected", kind, unselected)
		t.set_stylebox(&"tab_hovered", kind, hovered)
		t.set_stylebox(&"tab_focus", kind, StyleBoxEmpty.new())
		t.set_color(&"font_selected_color", kind, PRIMARY)
		t.set_color(&"font_unselected_color", kind, ON_SURFACE_VARIANT)
		t.set_color(&"font_hovered_color", kind, ON_SURFACE)
		t.set_font(&"font", kind, font(500))
		t.set_font_size(&"font_size", kind, LABEL_LARGE)
	t.set_stylebox(&"panel", &"TabContainer", StyleBoxEmpty.new())
	t.set_stylebox(&"tabbar_background", &"TabContainer", StyleBoxEmpty.new())


static func _containers(t: Theme) -> void:
	t.set_stylebox(&"panel", &"Panel", box(SURFACE_CONTAINER, SHAPE_MEDIUM))
	t.set_stylebox(&"panel", &"PanelContainer", box(SURFACE_CONTAINER, SHAPE_MEDIUM))
	for kind: StringName in [&"HSplitContainer", &"VSplitContainer", &"SplitContainer"]:
		t.set_constant(&"separation", kind, 10)
		t.set_constant(&"minimum_grab_thickness", kind, 10)
		t.set_icon(&"grabber", kind, _icon(_GRIP_SVG, OUTLINE_VARIANT))
		t.set_icon(&"h_grabber", kind, _icon(_GRIP_SVG, OUTLINE_VARIANT))
		t.set_icon(&"v_grabber", kind, _icon(_GRIP_H_SVG, OUTLINE_VARIANT))
		t.set_stylebox(&"split_bar_background", kind, StyleBoxEmpty.new())
	for kind: StringName in [&"HBoxContainer", &"VBoxContainer", &"HFlowContainer"]:
		t.set_constant(&"separation", kind, 8)
	t.set_constant(&"v_separation", &"HFlowContainer", 8)
	t.set_constant(&"h_separation", &"HFlowContainer", 8)

	var thumb := box(Color(ON_SURFACE_VARIANT, 0.35), SHAPE_FULL)
	thumb.content_margin_left = 4
	thumb.content_margin_right = 4
	var thumb_hover := box(Color(ON_SURFACE_VARIANT, 0.6), SHAPE_FULL)
	for kind: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", kind, box(Color.TRANSPARENT, SHAPE_FULL, Vector2(4, 4)))
		t.set_stylebox(&"grabber", kind, thumb)
		t.set_stylebox(&"grabber_highlight", kind, thumb_hover)
		t.set_stylebox(&"grabber_pressed", kind, thumb_hover)

	# Dialogs: the extra large shape on the high container.
	var dialog := box(SURFACE_CONTAINER_HIGH, SHAPE_EXTRA_LARGE, Vector2(24, 20))
	for kind: StringName in [&"AcceptDialog", &"ConfirmationDialog"]:
		t.set_stylebox(&"panel", kind, dialog)
		t.set_constant(&"buttons_separation", kind, 8)
	t.set_stylebox(
		&"panel",
		&"TooltipPanel",
		box(INVERSE_SURFACE, SHAPE_EXTRA_SMALL, Vector2(8, 5)),
	)
	t.set_color(&"font_color", &"TooltipLabel", INVERSE_ON_SURFACE)
	t.set_font(&"font", &"TooltipLabel", font(400))
	t.set_font_size(&"font_size", &"TooltipLabel", LABEL_MEDIUM)


static func _menus(t: Theme) -> void:
	var menu := box(SURFACE_CONTAINER, SHAPE_SMALL, Vector2(0, 8))
	menu.shadow_color = Color(0, 0, 0, 0.35)
	menu.shadow_size = 6
	t.set_stylebox(&"panel", &"PopupMenu", menu)
	t.set_stylebox(&"hover", &"PopupMenu", box(Color(ON_SURFACE, HOVER_LAYER), 0, Vector2(12, 4)))
	t.set_color(&"font_color", &"PopupMenu", ON_SURFACE)
	t.set_color(&"font_hover_color", &"PopupMenu", ON_SURFACE)
	t.set_color(&"font_disabled_color", &"PopupMenu", Color(ON_SURFACE, DISABLED_CONTENT))
	t.set_font(&"font", &"PopupMenu", font(400))
	t.set_font_size(&"font_size", &"PopupMenu", BODY_MEDIUM)
	t.set_constant(&"v_separation", &"PopupMenu", 12)
	t.set_constant(&"item_start_padding", &"PopupMenu", 14)
	t.set_constant(&"item_end_padding", &"PopupMenu", 14)
	t.set_icon(&"radio_checked", &"PopupMenu", _icon(_CHECK_MARK_SVG, PRIMARY))
	t.set_icon(&"radio_unchecked", &"PopupMenu", _icon(_EMPTY_SVG, PRIMARY))
	t.set_icon(&"submenu", &"PopupMenu", _icon(_ARROW_RIGHT_SVG, ON_SURFACE_VARIANT))


## The workshop's own parts.
static func _workshop_parts(t: Theme) -> void:
	t.set_type_variation(&"WorkshopBackground", &"PanelContainer")
	t.set_stylebox(&"panel", &"WorkshopBackground", box(SURFACE, 0, Vector2(10, 8)))
	t.set_type_variation(&"TopBar", &"PanelContainer")
	t.set_stylebox(&"panel", &"TopBar", box(SURFACE_CONTAINER_LOW, SHAPE_MEDIUM, Vector2(14, 8)))
	t.set_type_variation(&"WorkshopPanel", &"PanelContainer")
	t.set_stylebox(
		&"panel",
		&"WorkshopPanel",
		box(SURFACE_CONTAINER_LOW, SHAPE_MEDIUM, Vector2(0, 0), OUTLINE_VARIANT, 1),
	)
	t.set_type_variation(&"PanelHeader", &"PanelContainer")
	var header := box(SURFACE_CONTAINER, 0, Vector2(12, 6))
	header.corner_radius_top_left = SHAPE_MEDIUM
	header.corner_radius_top_right = SHAPE_MEDIUM
	header.border_color = OUTLINE_VARIANT
	header.border_width_bottom = 1
	t.set_stylebox(&"panel", &"PanelHeader", header)
	t.set_type_variation(&"PanelBody", &"MarginContainer")
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		t.set_constant(side, &"PanelBody", 12)
	t.set_type_variation(&"Readouts", &"PanelContainer")
	t.set_stylebox(
		&"panel",
		&"Readouts",
		box(Color(SURFACE_CONTAINER_LOWEST, 0.72), SHAPE_SMALL, Vector2(12, 8)),
	)
	t.set_type_variation(&"InfoCard", &"PanelContainer")
	t.set_stylebox(
		&"panel",
		&"InfoCard",
		box(SURFACE_CONTAINER_HIGH, SHAPE_MEDIUM, Vector2(14, 10)),
	)
	t.set_type_variation(&"CautionBar", &"PanelContainer")
	t.set_stylebox(&"panel", &"CautionBar", box(CAUTION_CONTAINER, SHAPE_SMALL, Vector2(12, 6)))
	_variation(t, &"CautionLabel", &"Label", font(500), LABEL_LARGE, ON_CAUTION_CONTAINER)
	t.set_type_variation(&"ErrorBar", &"PanelContainer")
	t.set_stylebox(&"panel", &"ErrorBar", box(ERROR_CONTAINER, SHAPE_SMALL, Vector2(12, 6)))
	_variation(t, &"ErrorLabel", &"Label", font(500), LABEL_LARGE, ON_ERROR_CONTAINER)
	t.set_type_variation(&"PhoneFrame", &"Panel")
	var phone := box(SURFACE_CONTAINER_LOWEST, SHAPE_EXTRA_LARGE, Vector2.ZERO, Color("#3a3d44"), 8)
	t.set_stylebox(&"panel", &"PhoneFrame", phone)
	t.set_type_variation(&"TunableRow", &"HBoxContainer")
	t.set_constant(&"separation", &"TunableRow", 12)
	t.set_type_variation(&"CourseStrip", &"Control")


static func _variation(
	t: Theme,
	variation: StringName,
	base: StringName,
	variation_font: Font,
	size: int,
	color: Color,
) -> void:
	t.set_type_variation(variation, base)
	t.set_font(&"font", variation, variation_font)
	t.set_font_size(&"font_size", variation, size)
	t.set_color(&"font_color", variation, color)


## An icon drawn from [param svg], whose [code]{fill}[/code] and [code]{mark}[/code] take
## [param color] and [param mark], sized for the window's stretch.
static func _icon(svg: String, color: Color, mark := Color.TRANSPARENT) -> ImageTexture:
	var source := svg.replace("{fill}", "#" + color.to_html(false))
	source = source.replace("{fill_alpha}", str(color.a))
	source = source.replace("{mark}", "#" + mark.to_html(false))
	var image := Image.new()
	image.load_svg_from_string(source, 2.0)
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(image.get_size() / 2)
	return texture


const _HANDLE_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">'
	+ '<circle cx="10" cy="10" r="8" fill="{fill}" fill-opacity="{fill_alpha}"/></svg>'
)
const _CHECKED_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22">'
	+ '<rect x="3" y="3" width="16" height="16" rx="3" fill="{fill}" fill-opacity="{fill_alpha}"/>'
	+ '<path d="M6.5 11.2l3 3 6-6.4" stroke="#002e69" stroke-width="2.2" fill="none"/></svg>'
)
const _UNCHECKED_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22">'
	+ '<rect x="4" y="4" width="14" height="14" rx="2.5" fill="none" stroke="{fill}"'
	+ ' stroke-opacity="{fill_alpha}" stroke-width="2"/></svg>'
)
const _SWITCH_ON_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="44" height="26">'
	+ '<rect x="1" y="1" width="42" height="24" rx="12" fill="{fill}"/>'
	+ '<circle cx="31" cy="13" r="8" fill="{mark}"/></svg>'
)
const _SWITCH_OFF_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="44" height="26">'
	+ '<rect x="2" y="2" width="40" height="22" rx="11" fill="{mark}"'
	+ ' stroke="{fill}" stroke-width="2"/>' + '<circle cx="13" cy="13" r="6" fill="{fill}"/></svg>'
)
const _ARROW_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
	+ '<path d="M4 6l4 4 4-4z" fill="{fill}"/></svg>'
)
const _ARROW_RIGHT_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
	+ '<path d="M6 4l4 4-4 4z" fill="{fill}"/></svg>'
)
const _UPDOWN_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="24">'
	+ '<path d="M4 10l4-4 4 4z M4 14l4 4 4-4z" fill="{fill}"/></svg>'
)
const _CHECK_MARK_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
	+ '<path d="M3 8.5l3 3 7-7" stroke="{fill}" stroke-width="2" fill="none"/></svg>'
)
const _EMPTY_SVG := '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"></svg>'
const _GRIP_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="4" height="32">'
	+ '<rect width="4" height="32" rx="2" fill="{fill}"/></svg>'
)
const _GRIP_H_SVG := (
	'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="4">'
	+ '<rect width="32" height="4" rx="2" fill="{fill}"/></svg>'
)
