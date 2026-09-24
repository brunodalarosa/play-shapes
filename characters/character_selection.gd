class_name CharacterSelection
extends RefCounted
## Canonical player-selected body shapes and lobby colors.

const SHAPES: Array[StringName] = [&"square", &"circle", &"squircle", &"rhombus"]
const COLORS: Array[Dictionary] = [
	{"id": "red", "name": "Red", "hex": "#E53935"},
	{"id": "orange", "name": "Orange", "hex": "#F57C00"},
	{"id": "golden_yellow", "name": "Golden Yellow", "hex": "#FBC02D"},
	{"id": "green", "name": "Green", "hex": "#43A047"},
	{"id": "cyan", "name": "Cyan", "hex": "#00ACC1"},
	{"id": "blue", "name": "Blue", "hex": "#1E88E5"},
	{"id": "indigo", "name": "Indigo", "hex": "#3949AB"},
	{"id": "purple", "name": "Purple", "hex": "#8E24AA"},
	{"id": "pink", "name": "Pink", "hex": "#EC407A"},
	{"id": "brown", "name": "Brown", "hex": "#8D6E63"},
]
const FALLBACK_SHAPE: StringName = &"circle"
const FALLBACK_COLOR := "#598DF2" # Existing unselected-player blue.
const BODY_TEXTURES: Dictionary = {
	&"square": preload("res://assets/runtime/shape_characters/bodies/square.png"),
	&"circle": preload("res://assets/runtime/shape_characters/bodies/circle.png"),
	&"squircle": preload("res://assets/runtime/shape_characters/bodies/squircle.png"),
	&"rhombus": preload("res://assets/runtime/shape_characters/bodies/rhombus.png"),
}


static func default_selection() -> Dictionary:
	return {
		"accepted": true,
		"character_shape": String(FALLBACK_SHAPE),
		"character_color": FALLBACK_COLOR,
	}


static func validate_selection(raw_shape: Variant, raw_color: Variant) -> Dictionary:
	if typeof(raw_shape) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return _rejected("Choose a character shape")
	var shape := StringName(String(raw_shape).to_lower())
	if not SHAPES.has(shape):
		return _rejected("Choose an available character shape")
	if not raw_color is String:
		return _rejected("Choose a character color")
	var requested_color := String(raw_color).strip_edges().to_upper()
	if not requested_color.begins_with("#"):
		requested_color = "#" + requested_color
	for option: Dictionary in COLORS:
		if requested_color == String(option.hex):
			return {
				"accepted": true,
				"character_shape": String(shape),
				"character_color": String(option.hex),
			}
	return _rejected("Choose one of the available character colors")


static func resolve_selection(raw_shape: Variant, raw_color: Variant) -> Dictionary:
	var result := validate_selection(raw_shape, raw_color)
	if result.accepted:
		return result
	return default_selection()


static func for_player(player: Dictionary) -> Dictionary:
	return resolve_selection(
		player.get("character_shape"),
		player.get("character_color")
	)


static func normalize_shape(raw_shape: Variant) -> StringName:
	if typeof(raw_shape) in [TYPE_STRING, TYPE_STRING_NAME]:
		var shape := StringName(String(raw_shape).to_lower())
		if SHAPES.has(shape):
			return shape
	return FALLBACK_SHAPE


static func body_texture_for(raw_shape: Variant) -> Texture2D:
	return BODY_TEXTURES[normalize_shape(raw_shape)] as Texture2D


static func _rejected(message: String) -> Dictionary:
	return {"accepted": false, "code": &"invalid_character_selection", "message": message}
