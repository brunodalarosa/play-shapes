class_name TiltShiftTiltInput
extends RefCounted
## One player's immutable active neutral and unwrapped in-plane rotation.

var calibrated: bool = false
var neutral_phase: float = 0.0
var input_radians: float = 0.0
var angle_radians: float = 0.0
var continuity: StringName = &"waiting"
var _profile: TiltShiftMotionTuning
var _generation: String = ""
var _receipt: int = -1
var _event_at: int = -1
var _interrupted: bool = true
var _ambiguous: bool = false
var _cached_angles: Array = []
var _cached_projection: Vector2 = Vector2.ZERO


func _init(selected: TiltShiftMotionTuning) -> void:
	_profile = selected.duplicate() as TiltShiftMotionTuning


func capture_state(channel: MotionInputChannel, now: int) -> StringName:
	if channel == null or channel.subscription_id.is_empty():
		return &"idle"
	var diagnostics := channel.diagnostics
	if diagnostics.is_empty():
		return &"waiting"
	if not diagnostics.secure_context:
		return &"insecure"
	if not diagnostics.orientation_support:
		return &"unsupported"
	if diagnostics.orientation_permission in ["denied", "error", "unavailable"]:
		return StringName(diagnostics.orientation_permission)
	if diagnostics.state != "live":
		return StringName(diagnostics.state)
	if channel.latest.is_empty():
		return &"waiting"
	var sample := channel.latest
	if sample.orientation_age_msec == null:
		return &"absent_orientation"
	if (
		not channel.is_fresh(now)
		or float(sample.orientation_age_msec) + now - channel.received_at
		> MotionInputChannel.STALE_MSEC
	):
		return &"stale_orientation"
	if sample.orientation.has(null):
		return &"partial_orientation"
	if _projection(sample.orientation).length() < _profile.minimum_projection:
		return &"degenerate_orientation"
	return &"live"


func calibrate(channel: MotionInputChannel, now: int) -> bool:
	if capture_state(channel, now) != &"live":
		return false
	neutral_phase = _projection(channel.latest.orientation).angle()
	input_radians = 0.0
	angle_radians = 0.0
	calibrated = true
	_generation = channel.subscription_id
	_receipt = channel.received_at
	_event_at = _orientation_time(channel)
	_interrupted = false
	_ambiguous = false
	continuity = &"continuous"
	return true


func update(channel: MotionInputChannel, now: int) -> bool:
	if capture_state(channel, now) != &"live":
		_interrupted = true
		return false
	if not calibrated:
		return false
	if _generation == channel.subscription_id and _receipt == channel.received_at:
		return false
	var event_at := _orientation_time(channel)
	if _generation == channel.subscription_id and event_at <= _event_at:
		_receipt = channel.received_at
		return false
	var resumed := (
		_interrupted or _generation != channel.subscription_id
		or event_at - _event_at > _profile.continuity_gap_msec
	)
	_generation = channel.subscription_id
	_receipt = channel.received_at
	_event_at = event_at
	var phase := _projection(channel.latest.orientation).angle() - neutral_phase
	# The nearest branch preserves neutral and accumulated turns, including after a gap.
	# No sampled orientation can reveal complete turns made between unseen samples.
	var change := wrapf(phase - input_radians, -PI, PI)
	_ambiguous = absf(absf(change) - PI) < 0.000001
	if _ambiguous:
		_interrupted = true
		continuity = &"ambiguous"
		return false
	input_radians += change
	angle_radians = input_radians * _profile.gain
	if not _profile.continuous:
		var maximum := deg_to_rad(_profile.maximum_degrees)
		angle_radians = clampf(angle_radians, -maximum, maximum)
	_interrupted = false
	continuity = &"resumed" if resumed else &"continuous"
	return true


func state(channel: MotionInputChannel, now: int) -> Dictionary:
	var capture := capture_state(channel, now)
	if capture == &"live" and _ambiguous:
		capture = &"ambiguous_turn"
	return {
		"calibrated": calibrated,
		"capture_state": String(capture),
		"usable": capture == &"live",
	}


func _projection(angles: Array) -> Vector2:
	if angles == _cached_angles:
		return _cached_projection
	_cached_angles = angles.duplicate()
	# World up projected into physical screen axes is yaw-independent. UI axes never enter.
	var local_up := MotionOrientation.device_basis(angles).transposed() * Vector3.UP
	_cached_projection = Vector2(local_up.x, local_up.y)
	return _cached_projection


static func _orientation_time(channel: MotionInputChannel) -> int:
	return channel.received_at - int(channel.latest.orientation_age_msec)
