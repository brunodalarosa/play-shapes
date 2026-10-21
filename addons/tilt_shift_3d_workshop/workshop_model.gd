@tool
extends RefCounted
## Edits own deep copies. Only explicit saves can change content on disk.

signal changed

const CONTENT := "res://minigames/005_3d_tilt_shift/tuning/"
const DRAFTS := "res://scratch/tilt_shift_3d_workshop/"
## Anchors this close to the center line, in widths, belong to neither side.
const CENTER_TOLERANCE := 0.0001

var profile: TiltShift3DTuning
var baskets: Array[TiltShift3DBasketPreset] = []
var basket_index: int = 0
var layouts: Array[TiltShift3DPaddleLayout] = []
var layout_index: int = 0
var source_path: String = ""
var dirty: bool = false
var snap_enabled: bool = true
var position_snap: float = 0.01
var width_snap: float = 0.01
var guide_tolerance: float = 0.005
var force_paddle_symmetry: bool = false
var last_error: String = ""
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _gesture: Dictionary = { }


func load_profile(path: String) -> bool:
	var content := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not content is TiltShift3DTuning:
		last_error = "Select a Tilt Shift 3D profile (.tres)."
		return false
	profile = content.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	layouts.clear()
	if profile.layouts_by_round.is_empty() and profile.paddle_layout != null:
		for index: int in profile.round_count:
			profile.layouts_by_round.append(profile.paddle_layout)
	for layout: TiltShift3DPaddleLayout in profile.layouts_by_round:
		if layout != null and not layouts.has(layout):
			layouts.append(layout)
	layout_index = 0
	if not layouts.is_empty():
		profile.paddle_layout = layouts[0]
	baskets.clear()
	for basket: TiltShift3DBasketPreset in profile.baskets_by_round:
		if basket != null and not baskets.has(basket):
			baskets.append(basket)
	if baskets.is_empty():
		baskets.append(TiltShift3DBasketPreset.new())
	basket_index = 0
	source_path = path
	dirty = false
	_undo.clear()
	_redo.clear()
	_gesture.clear()
	last_error = ""
	changed.emit()
	return true


func select_layout(index: int) -> void:
	if index >= 0 and index < layouts.size():
		layout_index = index
		profile.paddle_layout = layouts[index]
		changed.emit()


func assign_layout_round(index: int, selected: int) -> void:
	begin_edit()
	while profile.layouts_by_round.size() <= index:
		profile.layouts_by_round.append(null)
	profile.layouts_by_round[index] = layouts[selected] if selected >= 0 else null
	end_edit()


func basket() -> TiltShift3DBasketPreset:
	return baskets[basket_index]


func select_basket(index: int) -> void:
	if index >= 0 and index < baskets.size():
		basket_index = index
		changed.emit()


func load_content(path: String, kind: String) -> bool:
	var content := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var matches := (
		(kind == "layout" and content is TiltShift3DPaddleLayout)
		or (kind == "basket" and content is TiltShift3DBasketPreset)
		or (kind == "physics" and content is TiltShift3DPhysicsTuning)
	)
	if not matches:
		last_error = "Select a %s Resource (.tres)." % kind
		return false
	begin_edit()
	var copy: Resource = content.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	match kind:
		"layout":
			layouts.append(copy)
			layout_index = layouts.size() - 1
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
	# The partner is found before the move, while both sides still rank alike.
	var partner := paddle_partner(index) if force_paddle_symmetry else -1
	var paddles := profile.paddle_layout.paddles
	paddles[index].position = point
	if partner >= 0:
		paddles[partner].position = _mirrored(point)
	changed.emit()


## Turning symmetry on corrects the draft at once, taking side A as the reference.
func set_force_paddle_symmetry(enabled: bool) -> void:
	force_paddle_symmetry = enabled
	if not enabled:
		return
	var corrections := _symmetry_corrections()
	if corrections.is_empty():
		return
	begin_edit()
	for partner: int in corrections:
		profile.paddle_layout.paddles[partner].position = corrections[partner]
	end_edit()


## Names each anchor by its side of the center line, A left and B right, and its rank from
## the floor, so A0 is the lowest anchor on the left. Anchors on the line itself are C.
## Entries are empty for missing paddles.
func paddle_labels() -> PackedStringArray:
	var paddles := profile.paddle_layout.paddles
	var half := profile.paddle_layout.arena_size.x * 0.5
	var sides := { "A": [], "B": [], "C": [] }
	for index: int in paddles.size():
		var paddle := paddles[index]
		if paddle == null:
			continue
		var offset := paddle.position.x - half
		var letter := "C" if absf(offset) <= CENTER_TOLERANCE else ("A" if offset < 0.0 else "B")
		sides[letter].append(index)
	var labels := PackedStringArray()
	labels.resize(paddles.size())
	for letter: String in sides:
		var members: Array = sides[letter]
		members.sort_custom(
			func(first: int, second: int) -> bool:
				var one := paddles[first].position
				var two := paddles[second].position
				if one.y != two.y:
					return one.y > two.y
				if one.x != two.x:
					return one.x < two.x
				return first < second,
		)
		for rank: int in members.size():
			labels[members[rank]] = "%s%d" % [letter, rank]
	return labels


## The anchor of equal rank on the other side, or -1 for a center or unmatched anchor.
func paddle_partner(index: int) -> int:
	var labels := paddle_labels()
	var label := labels[index]
	if label.is_empty() or label.begins_with("C"):
		return -1
	var opposite := ("B" if label.begins_with("A") else "A") + label.substr(1)
	return labels.find(opposite)


func _mirrored(point: Vector2) -> Vector2:
	return Vector2(profile.paddle_layout.arena_size.x - point.x, point.y)


func _symmetry_corrections() -> Dictionary:
	var paddles := profile.paddle_layout.paddles
	var labels := paddle_labels()
	var corrections := { }
	for index: int in paddles.size():
		if not labels[index].begins_with("A"):
			continue
		var partner := labels.find("B" + labels[index].substr(1))
		if partner < 0:
			continue
		var target := _mirrored(paddles[index].position)
		if not paddles[partner].position.is_equal_approx(target):
			corrections[partner] = target
	return corrections


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
				<= TiltShift3DBasketPreset.REFLECTION_TOLERANCE:
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
	if index < profile.baskets_by_round.size():
		profile.baskets_by_round.remove_at(index)
	if index < profile.layouts_by_round.size():
		profile.layouts_by_round.remove_at(index)
	end_edit()


func add_basket() -> void:
	begin_edit()
	var opening := TiltShift3DBasketOpening.new()
	opening.basket_id = "opening_%d" % Time.get_ticks_usec()
	basket().openings.append(opening)
	end_edit()


func remove_basket(index: int) -> void:
	begin_edit()
	basket().openings.remove_at(index)
	end_edit()


func new_basket_preset() -> void:
	begin_edit()
	var preset := TiltShift3DBasketPreset.new()
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
	if saved is TiltShift3DTuning and not saved.layouts_by_round.is_empty():
		saved.paddle_layout = saved.layouts_by_round[0]
	error = ResourceSaver.save(saved, normalized)
	if error != OK:
		last_error = error_string(error)
	elif kind == "profile":
		source_path = normalized
		dirty = false
	changed.emit()
	return error


func _capture() -> Dictionary:
	var copy: TiltShift3DTuning = profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var library: Array[TiltShift3DBasketPreset] = []
	for preset: TiltShift3DBasketPreset in baskets:
		var mapped := profile.baskets_by_round.find(preset)
		library.append(
			(
				copy.baskets_by_round[mapped]
				if mapped >= 0
				else preset.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			)
		)
	var layout_library: Array[TiltShift3DPaddleLayout] = []
	for layout: TiltShift3DPaddleLayout in layouts:
		var mapped := profile.layouts_by_round.find(layout)
		var item: TiltShift3DPaddleLayout = copy.layouts_by_round[mapped] if mapped >= 0 \
				else layout.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		layout_library.append(item)
	return {
		"profile": copy,
		"baskets": library,
		"index": basket_index,
		"layouts": layout_library,
		"layout_index": layout_index,
	}


func _restore(state: Dictionary) -> void:
	profile = state.profile
	baskets.assign(state.baskets)
	basket_index = state.index
	layouts.assign(state.layouts)
	layout_index = state.layout_index
	if not layouts.is_empty():
		profile.paddle_layout = layouts[layout_index]
	dirty = true
	_gesture.clear()
	last_error = ""
	changed.emit()
