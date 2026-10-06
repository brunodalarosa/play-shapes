@tool
extends RefCounted
## Edits own deep copies. Only explicit saves can change content on disk.

signal changed

const CONTENT := "res://minigames/003_tilt_shift/tuning/"
const DRAFTS := "res://scratch/tilt_shift_workshop/"

var profile: TiltShiftTuning
var baskets: Array[TiltShiftBasketPreset] = []
var basket_index: int = 0
var source_path: String = ""
var dirty: bool = false
var snap_enabled: bool = true
var position_snap: float = 0.01
var width_snap: float = 0.01
var guide_tolerance: float = 0.005
var last_error: String = ""
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _gesture: Dictionary = { }


func load_profile(path: String) -> bool:
	var content := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not content is TiltShiftTuning:
		last_error = "Select a Tilt Shift profile (.tres)."
		return false
	profile = content.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	baskets.clear()
	for basket: TiltShiftBasketPreset in profile.baskets_by_round:
		if basket != null and not baskets.has(basket):
			baskets.append(basket)
	if baskets.is_empty():
		baskets.append(TiltShiftBasketPreset.new())
	basket_index = 0
	source_path = path
	dirty = false
	_undo.clear()
	_redo.clear()
	_gesture.clear()
	last_error = ""
	changed.emit()
	return true


func basket() -> TiltShiftBasketPreset:
	return baskets[basket_index]


func select_basket(index: int) -> void:
	if index >= 0 and index < baskets.size():
		basket_index = index
		changed.emit()


func load_content(path: String, kind: String) -> bool:
	var content := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var matches := (
		(kind == "layout" and content is TiltShiftPaddleLayout)
		or (kind == "basket" and content is TiltShiftBasketPreset)
		or (kind == "physics" and content is TiltShiftPhysicsTuning)
	)
	if not matches:
		last_error = "Select a %s Resource (.tres)." % kind
		return false
	begin_edit()
	var copy: Resource = content.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	match kind:
		"layout":
			profile.paddle_layout = copy
		"physics":
			profile.physics = copy
		"basket":
			baskets.append(copy)
			basket_index = baskets.size() - 1
	end_edit()
	return true


func begin_edit() -> void:
	if _gesture.is_empty():
		_gesture = _capture()
		last_error = ""


func end_edit() -> void:
	if _gesture.is_empty():
		return
	_undo.append(_gesture)
	if _undo.size() > 100:
		_undo.pop_front()
	_gesture = { }
	_redo.clear()
	dirty = true
	changed.emit()


func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_capture())
	_restore(_undo.pop_back())


func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_capture())
	_restore(_redo.pop_back())


func snap(value: float, step: float) -> float:
	return snappedf(value, step) if snap_enabled and step > 0.0 else value


func move_paddle(index: int, position: Vector2) -> void:
	var point := Vector2(snap(position.x, position_snap), snap(position.y, position_snap))
	profile.paddle_layout.paddles[index].position = point
	changed.emit()


func reflected_index(index: int) -> int:
	var selected := basket()
	var opening := selected.openings[index]
	var reflected_team: int = 1 - opening.team if opening.team != 2 else 2
	var found := -1
	for other: int in selected.openings.size():
		var candidate := selected.openings[other]
		if candidate == null or candidate.team != reflected_team:
			continue
		if absf(candidate.center - (selected.arena_width - opening.center)) \
				<= TiltShiftBasketPreset.REFLECTION_TOLERANCE:
			if found >= 0:
				return -1
			found = other
	return found


func move_basket(index: int, center: float, paired: bool = true) -> bool:
	var other := reflected_index(index)
	if paired and other < 0:
		last_error = "No unique reflected partner. Use single-opening draft editing to repair."
		return false
	var selected := basket()
	var next := snap(center, position_snap)
	if paired and other == index:
		next = selected.arena_width * 0.5
	selected.openings[index].center = next
	if paired and other != index:
		selected.openings[other].center = selected.arena_width - next
	changed.emit()
	return true


func resize_basket(index: int, width: float) -> bool:
	var other := reflected_index(index)
	if basket().openings[index].team != 2 and other < 0:
		last_error = "Repair the unique reflected team partner before editing pair width."
		return false
	var next := snap(width, width_snap)
	basket().openings[index].width = next
	if other >= 0:
		basket().openings[other].width = next
	changed.emit()
	return true


func assign_round(index: int, preset_index: int) -> void:
	begin_edit()
	while profile.baskets_by_round.size() <= index:
		profile.baskets_by_round.append(null)
	profile.baskets_by_round[index] = baskets[preset_index] if preset_index >= 0 else null
	end_edit()


func remove_round_mapping(index: int) -> void:
	begin_edit()
	profile.baskets_by_round.remove_at(index)
	end_edit()


func add_basket() -> void:
	begin_edit()
	var opening := TiltShiftBasketOpening.new()
	opening.basket_id = "opening_%d" % Time.get_ticks_usec()
	basket().openings.append(opening)
	end_edit()


func remove_basket(index: int) -> void:
	begin_edit()
	basket().openings.remove_at(index)
	end_edit()


func new_basket_preset() -> void:
	begin_edit()
	var preset := TiltShiftBasketPreset.new()
	preset.arena_width = profile.paddle_layout.arena_size.x
	baskets.append(preset)
	basket_index = baskets.size() - 1
	end_edit()


func resource_for(kind: String) -> Resource:
	match kind:
		"layout":
			return profile.paddle_layout
		"basket":
			return basket()
		"physics":
			return profile.physics
	return profile


func save_content(path: String, kind: String, draft: bool = false) -> Error:
	last_error = ""
	var normalized := path.simplify_path()
	var root := DRAFTS if draft else CONTENT
	if not normalized.begins_with(root) or normalized.get_extension() != "tres":
		last_error = "Save %s files below %s." % ["draft" if draft else "usable", root]
		return ERR_INVALID_PARAMETER
	var resource := resource_for(kind)
	if resource == null:
		last_error = "Choose content before saving."
		return ERR_INVALID_DATA
	if not draft:
		var errors: PackedStringArray = resource.validation_errors()
		if not errors.is_empty():
			last_error = "\n".join(errors)
			return ERR_INVALID_DATA
	var directory := ProjectSettings.globalize_path(normalized.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		last_error = error_string(error)
		return error
	# Deep duplication clears external resource paths and preserves repeated references.
	var saved: Resource = resource.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	error = ResourceSaver.save(saved, normalized)
	if error != OK:
		last_error = error_string(error)
	elif kind == "profile":
		source_path = normalized
		dirty = false
	changed.emit()
	return error


func _capture() -> Dictionary:
	var copy: TiltShiftTuning = profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var library: Array[TiltShiftBasketPreset] = []
	for preset: TiltShiftBasketPreset in baskets:
		var mapped := profile.baskets_by_round.find(preset)
		library.append(
			(
				copy.baskets_by_round[mapped]
				if mapped >= 0
				else preset.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			)
		)
	return { "profile": copy, "baskets": library, "index": basket_index }


func _restore(state: Dictionary) -> void:
	profile = state.profile
	baskets.assign(state.baskets)
	basket_index = state.index
	dirty = true
	_gesture.clear()
	last_error = ""
	changed.emit()
