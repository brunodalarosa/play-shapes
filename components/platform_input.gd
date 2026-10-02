class_name PlatformInput
extends RefCounted
## Validates phone snapshots using the browser's generated tuning, never its grounding.

const SETTINGS_PATH := "res://web/public/platform_input_settings.json"
static var _settings: Dictionary = {}


static func settings() -> Dictionary:
	if _settings.is_empty():
		_settings = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		assert(_settings.get("version") == 1 and _settings.get("axisConvention") == "x-right-y-up")
	return _settings


static func classify(axes: Vector2, previous: String) -> String:
	return classify_axes(axes.x, axes.y, previous)


static func classify_axes(x: float, y: float, previous: String) -> String:
	var tuning := settings()
	var magnitude := sqrt(x * x + y * y)
	if magnitude <= float(tuning.deadZone) or (previous == "neutral" \
			and magnitude < float(tuning.deadZone) + float(tuning.deadZoneHysteresis)):
		return "neutral"
	var candidate := "look_up" if y > 0.0 else "crouch"
	var angle := rad_to_deg(atan2(absf(x), absf(y)))
	var limit := float(tuning.verticalExitDegrees if previous == candidate else tuning.verticalEnterDegrees)
	return candidate if angle <= limit else "move"


static func validate(message: Dictionary, action: String = "") -> Dictionary:
	for key: String in ["horizontal", "vertical"]:
		var value: Variant = message.get(key)
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)) or absf(float(value)) > 1.0:
			return {"accepted": false, "code": "invalid_movement"}
	# Validate JSON doubles before narrowing to Godot's float32 Vector2. Otherwise
	# valid phone input just above the radial dead zone can round back into neutral.
	var x := float(message.horizontal)
	var y := float(message.vertical)
	# Permit floating-point roundoff at the unit-circle boundary, not square diagonals.
	if x * x + y * y > 1.000001:
		return {"accepted": false, "code": "invalid_movement"}
	var hint: Variant = message.get("stance")
	if typeof(hint) != TYPE_STRING or hint not in ["neutral", "move", "look_up", "crouch"]:
		return {"accepted": false, "code": "invalid_stance"}
	# Seed with the reported hint to retain radial/angular hysteresis when intermediate
	# samples were coalesced. Reconstruct it; it cannot grant an out-of-sector stance.
	if (hint == "neutral" and (x != 0.0 or y != 0.0)) or classify_axes(x, y, hint) != hint:
		return {"accepted": false, "code": "invalid_stance"}
	if not action.is_empty() and (message.get("action") != action or (action == "fall") != (hint == "crouch")):
		return {"accepted": false, "code": "invalid_action"}
	return {"accepted": true, "axes": Vector2(x, y), "stance": hint}
