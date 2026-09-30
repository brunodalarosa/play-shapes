class_name MotionInputChannel
extends RefCounted
## One authenticated, bounded live subscription. Host receipt time owns freshness.

signal changed

const MAX_SEND_HZ := 30
const STALE_MSEC := 1000
var target_player_id := ""
var subscription_id := ""
var latest: Dictionary = {}
var diagnostics: Dictionary = {}
var received_at := -1
var sample_count := 0
var first_received_at := -1
var _last_sequence := -1
var _last_status_at := -1000

func begin(player_id: String) -> void:
	target_player_id = player_id
	reconnect()

func reconnect() -> void:
	subscription_id = Crypto.new().generate_random_bytes(12).hex_encode()
	latest.clear()
	diagnostics.clear()
	received_at = -1
	first_received_at = -1
	sample_count = 0
	_last_sequence = -1
	_last_status_at = -1000
	changed.emit()

func end() -> void:
	target_player_id = ""
	subscription_id = ""
	latest.clear()
	diagnostics.clear()
	received_at = -1
	changed.emit()

func subscription() -> Dictionary:
	return {"type": "motion_lab", "subscription_id": subscription_id, "send_hz": MAX_SEND_HZ, "stale_msec": STALE_MSEC}

func is_fresh(now: int) -> bool:
	return received_at >= 0 and now - received_at <= STALE_MSEC and diagnostics.get("state") == "live"

func handle(player: Dictionary, message: Dictionary, now: int) -> bool:
	if target_player_id.is_empty() or player.get("player_id") != target_player_id or message.get("subscription_id") != subscription_id or message.has("player_id"):
		return false
	if message.get("type") == "motion_status":
		if now - _last_status_at < 200 or not _valid_diagnostics(message.get("diagnostics")):
			return false
		_last_status_at = now
		diagnostics = message.diagnostics.duplicate(true)
		if diagnostics.state != "live":
			latest.clear()
			received_at = -1
		changed.emit()
		return true
	if message.get("type") != "motion_sample" or not _number(message.get("sequence"), 1e12) or message.sequence != floor(message.sequence) or message.sequence <= _last_sequence:
		return false
	if received_at >= 0 and now - received_at < int(1000.0 / MAX_SEND_HZ):
		return false
	var sample: Variant = message.get("sample")
	if not sample is Dictionary or not _valid_sample(sample):
		return false
	_last_sequence = int(message.sequence)
	latest = sample.duplicate(true)
	received_at = now
	if first_received_at < 0:
		first_received_at = now
	sample_count += 1
	changed.emit()
	return true

static func _number(value: Variant, limit: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= limit

static func _axes(value: Variant, limit: float) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for item: Variant in value:
		if item != null and not _number(item, limit):
			return false
	return true

static func _valid_sample(sample: Dictionary) -> bool:
	if sample.size() != 11:
		return false
	for field: String in ["orientation", "rotation_rate", "acceleration", "acceleration_gravity"]:
		if not _axes(sample.get(field), 1e6):
			return false
	for field: String in ["interval_msec", "orientation_age_msec", "motion_age_msec"]:
		if sample.get(field) != null and (not _number(sample.get(field), 1e9) or sample[field] < 0):
			return false
	for field: String in ["orientation_hz", "motion_hz"]:
		if not _number(sample.get(field), 10000) or sample[field] < 0:
			return false
	return sample.get("absolute") is bool and _number(sample.get("screen_angle"), 360)

static func _valid_diagnostics(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 10:
		return false
	for field: String in ["secure_context", "motion_support", "orientation_support"]:
		if not value.get(field) is bool:
			return false
	for field: String in ["motion_permission", "orientation_permission"]:
		if value.get(field) not in ["unknown", "granted", "denied", "unavailable", "error"]:
			return false
	if value.get("state") not in ["idle", "insecure", "unsupported", "requesting", "denied", "error", "waiting", "live", "stale", "suspended"]:
		return false
	if value.get("page_protocol") not in ["http:", "https:"] or value.get("websocket_protocol") not in ["ws:", "wss:"] or value.get("websocket_status") not in ["open", "closed"]:
		return false
	return value.get("hostname") is String and ControllerNetworkConfig.valid_host(value.hostname)
