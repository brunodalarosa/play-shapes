class_name TiltShift3DExpressionDriver
extends RefCounted
## Decides every player paddle's face from what the arena and the rules report. During play a
## paddle turning fast gets dizzy and a hit startles it, dizzy above startled above the play
## face; the countdown, round end and shift results set a face for whole teams. Faces never
## feed back into physics. Time is in seconds, passed in.

const STARTLED := 1
const DIZZY := 2

var tuning: TiltShift3DExpressionTuning
## The paddles' expression stacks by paddle ID; the automatic paddle has none.
var stacks: Dictionary[String, ShapeFaceExpressions] = { }
var _owners: Dictionary[String, String] = { }
var _fast_since: Dictionary[String, float] = { }
var _hit_at: Dictionary[String, float] = { }
var _playing := false


func _init(selected: TiltShift3DExpressionTuning) -> void:
	tuning = selected


## Replaces the paddles: each entry of [param owners] maps a player paddle's ID to its owner.
func set_paddles(owners: Dictionary[String, String]) -> void:
	var previous := stacks
	stacks = { }
	_owners = owners.duplicate()
	for paddle_id: String in owners:
		var stack: ShapeFaceExpressions = previous.get(paddle_id)
		if stack == null:
			stack = ShapeFaceExpressions.new()
			stack.blink_interval = Vector2(tuning.blink_interval_min, tuning.blink_interval_max)
			stack.blink_seconds = tuning.blink_seconds
			stack.base_face = tuning.play_face
		stacks[paddle_id] = stack
	_fast_since.clear()
	_hit_at.clear()


## Follows the round's phase. [param teams] maps each paddle ID to its owner's team.
func set_moment(state: TiltShift3DState.Snapshot, teams: Dictionary[String, int]) -> void:
	_playing = state.phase == &"active"
	var faces := PackedStringArray([tuning.play_face, tuning.play_face])
	match state.phase:
		&"countdown", &"start":
			faces = PackedStringArray([tuning.countdown_face, tuning.countdown_face])
		&"between_rounds":
			faces = _standing(
				state.scores,
				tuning.leading_face,
				tuning.trailing_face,
				tuning.tied_face,
			)
		&"finished":
			faces = _standing(
				state.scores,
				tuning.winning_face,
				tuning.losing_face,
				tuning.draw_face,
			)
	for paddle_id: String in stacks:
		var stack := stacks[paddle_id]
		stack.base_face = faces[clampi(teams.get(paddle_id, 0), 0, 1)]
		if not _playing:
			stack.clear_all()
	if not _playing:
		_fast_since.clear()
		_hit_at.clear()


## Updates dizziness from each paddle's applied turning speed, in radians per second.
func update(speeds: Dictionary[String, float], now: float) -> void:
	if not _playing:
		return
	var threshold := deg_to_rad(tuning.dizzy_degrees_per_second)
	for paddle_id: String in speeds:
		if not stacks.has(paddle_id):
			continue
		if speeds[paddle_id] < threshold:
			_fast_since.erase(paddle_id)
			continue
		var since: float = _fast_since.get(paddle_id, now)
		_fast_since[paddle_id] = since
		if now - since >= tuning.dizzy_onset_seconds:
			stacks[paddle_id].show(tuning.dizzy_face, tuning.dizzy_hold_seconds, DIZZY, now)


## A ball hit [param paddle_id] closing at [param speed] arena widths per second.
func hit(paddle_id: String, speed: float, now: float) -> void:
	if not _playing or not stacks.has(paddle_id) or speed < tuning.startled_minimum_speed:
		return
	stacks[paddle_id].show(tuning.startled_face, tuning.startled_seconds, STARTLED, now)
	_hit_at[paddle_id] = now


## The paddle's height factor at [param now]: squashed on a hit, springing back to one.
func squash(paddle_id: String, now: float) -> float:
	if not _hit_at.has(paddle_id):
		return 1.0
	var progress := (now - _hit_at[paddle_id]) / maxf(tuning.squash_recovery_seconds, 0.001)
	if progress >= 1.0:
		_hit_at.erase(paddle_id)
		return 1.0
	# Eases back with a small overshoot, like a spring settling.
	var remaining := 1.0 - progress
	return 1.0 - tuning.squash_amount * remaining * remaining * cos(progress * PI * 1.5)


## The face [param paddle_id] shows at [param now], before blinking.
func face_for(paddle_id: String, now: float) -> String:
	var stack: ShapeFaceExpressions = stacks.get(paddle_id)
	return "" if stack == null else stack.face_at(now)


## The strongest face across [param player_id]'s paddles at [param now]: the highest-priority
## expression any of them shows, or their shared moment face.
func face_for_player(player_id: String, now: float) -> String:
	var best := ""
	var best_priority := -2
	for paddle_id: String in _owners:
		if _owners[paddle_id] != player_id:
			continue
		var stack := stacks[paddle_id]
		var priority := stack.active_priority(now)
		if priority > best_priority:
			best_priority = priority
			best = stack.face_at(now)
	return best


func _standing(
	scores: Array[int],
	ahead: String,
	behind: String,
	level: String,
) -> PackedStringArray:
	if scores.size() < 2 or scores[0] == scores[1]:
		return PackedStringArray([level, level])
	return PackedStringArray([ahead, behind] if scores[0] > scores[1] else [behind, ahead])
