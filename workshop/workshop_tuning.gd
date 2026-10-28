class_name WorkshopTuning
extends RefCounted
## The preset a workshop edits, in three copies: [member saved] as its file holds it,
## [member edited] with the designer's changes, and [member running], which the game plays.
##
## A change to a live value reaches [member running] at once; any other change waits for
## [method restart], so a phone that predicts with the values it started with never disagrees
## with the host. Each tuning Resource names its live export groups in a
## [code]LIVE_GROUPS[/code] constant.

signal changed
## A live value changed in [member running]; the game should show it now.
signal live_changed(tunable: WorkshopTunable)

const LIVE_GROUPS_CONSTANT := &"LIVE_GROUPS"

var saved: Resource
var edited: Resource
var running: Resource
## The minigame's Default preset, which marks each row's default.
var reference: Resource
var tunables: Array[WorkshopTunable] = []
## Copies of [member edited] before each step, and after each undone one.
var _undo_steps: Array[Resource] = []
var _redo_steps: Array[Resource] = []
## The value the last step set, so dragging a slider is one step.
var _last_key := ""
var _by_key: Dictionary[String, WorkshopTunable] = { }


func _init(preset: Resource, default_preset: Resource) -> void:
	reference = default_preset
	tunables = discover(default_preset)
	for tunable: WorkshopTunable in tunables:
		_by_key[tunable.key()] = tunable
	load_preset(preset)
	running = copy(edited)


## Starts editing [param preset]; the running game keeps its values until a restart.
func load_preset(preset: Resource) -> void:
	saved = copy(preset)
	edited = copy(preset)
	_clear_steps()
	changed.emit()


func tunable(key: String) -> WorkshopTunable:
	return _by_key.get(key)


func value(tunable_to_read: WorkshopTunable) -> Variant:
	return tunable_to_read.read(edited)


func default_value(tunable_to_read: WorkshopTunable) -> Variant:
	return tunable_to_read.read(reference)


## Sets an edited value as one undoable step.
func set_value(tunable_to_set: WorkshopTunable, new_value: Variant) -> void:
	var old_value: Variant = value(tunable_to_set)
	if tunable_to_set.same(old_value, new_value):
		return
	if tunable_to_set.key() != _last_key or not _redo_steps.is_empty():
		_push_step()
		_last_key = tunable_to_set.key()
	_apply(tunable_to_set, new_value)


func undo_edit() -> bool:
	if _undo_steps.is_empty():
		return false
	_redo_steps.append(copy(edited))
	_replace(_undo_steps.pop_back())
	_last_key = ""
	return true


func redo_edit() -> bool:
	if _redo_steps.is_empty():
		return false
	_undo_steps.append(copy(edited))
	_replace(_redo_steps.pop_back())
	_last_key = ""
	return true


func can_undo() -> bool:
	return not _undo_steps.is_empty()


func can_redo() -> bool:
	return not _redo_steps.is_empty()


## How many values differ from the preset's file.
func edit_count() -> int:
	return differences(saved, edited).size()


func is_edited(tunable_to_check: WorkshopTunable) -> bool:
	return not tunable_to_check.same(tunable_to_check.read(saved), value(tunable_to_check))


## Values edited but not yet in the running game.
func pending() -> Array[WorkshopTunable]:
	return differences(running, edited)


func errors() -> PackedStringArray:
	return edited.call(&"validation_errors") if edited.has_method(&"validation_errors") else []


## Makes the edited values the running ones and returns them, for the game to restart with.
func restart() -> Resource:
	running = copy(edited)
	changed.emit()
	return running


## Drops every edit since the last save; the running game keeps its values until a restart.
func revert() -> void:
	edited = copy(saved)
	_clear_steps()
	changed.emit()


## Marks the edited values as saved, after the preset file was written.
func mark_saved() -> void:
	saved = copy(edited)
	changed.emit()


## Copies one part, such as [code]flight[/code], from [param source] into the edited preset.
func copy_part(source: Resource, part: String) -> void:
	var after := copy(edited)
	after.set(part, copy(source.get(part)))
	_push_step()
	_last_key = ""
	_replace(after)


## The tunables whose values differ between [param a] and [param b].
func differences(a: Resource, b: Resource) -> Array[WorkshopTunable]:
	var result: Array[WorkshopTunable] = []
	for each: WorkshopTunable in tunables:
		if not each.same(each.read(a), each.read(b)):
			result.append(each)
	return result


## One line per value that differs between [param a] and [param b], as "Tab · Label: a → b".
func describe_differences(a: Resource, b: Resource) -> PackedStringArray:
	var lines := PackedStringArray()
	for each: WorkshopTunable in differences(a, b):
		lines.append(
			"%s · %s: %s → %s"
			% [each.tab, each.label, each.format(each.read(a)), each.format(each.read(b))]
		)
	return lines


## A deep copy that shares nothing with [param preset], so saving it embeds every part.
static func copy(preset: Resource) -> Resource:
	return preset.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) if preset != null else null


## Every value of [param preset] the Tunables panel shows, tab by tab: the preset's own values
## first, then each part it holds.
static func discover(preset: Resource) -> Array[WorkshopTunable]:
	var result := _discover_in(preset, "", "")
	for property: Dictionary in _script_properties(preset):
		if property.type != TYPE_OBJECT:
			continue
		var part := preset.get(property.name) as Resource
		if part != null and not part is Curve:
			result.append_array(_discover_in(part, property.name, property.name.capitalize()))
	return result


static func _discover_in(holder: Resource, part: String, tab: String) -> Array[WorkshopTunable]:
	var result: Array[WorkshopTunable] = []
	var live_groups: Array = []
	var script := holder.get_script() as Script
	if script != null:
		live_groups = script.get_script_constant_map().get(LIVE_GROUPS_CONSTANT, [])
	var help := _help_comments(script)
	var group := ""
	for property: Dictionary in holder.get_property_list():
		# Each class starts a category; groups before the script's belong to Resource itself.
		if property.usage & PROPERTY_USAGE_CATEGORY:
			group = ""
			continue
		if property.usage & PROPERTY_USAGE_GROUP:
			group = property.name
			continue
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if property.usage & PROPERTY_USAGE_EDITOR == 0:
			continue

		var base := WorkshopTunable.new()
		base.part = part
		base.property = property.name
		base.group = group if not group.is_empty() else "General"
		base.label = _sentence_case(property.name)
		base.help = help.get(property.name, "")
		base.live = StringName(group) in live_groups
		match property.type:
			TYPE_FLOAT, TYPE_INT:
				base.kind = (
					WorkshopTunable.Kind.WHOLE
					if property.type == TYPE_INT
					else WorkshopTunable.Kind.NUMBER
				)
				_read_range(base, property)
				result.append(base)
			TYPE_BOOL:
				base.kind = WorkshopTunable.Kind.SWITCH
				result.append(base)
			TYPE_OBJECT:
				var curve := holder.get(property.name) as Curve
				if curve != null:
					result.append_array(_curve_points(base, curve))
	# The preset's own values take the name of their first group, such as Race.
	if tab.is_empty():
		tab = result[0].group if not result.is_empty() else "General"
	for each: WorkshopTunable in result:
		each.tab = tab
	return result


## "forward_speed" as "Forward speed", as Material writes labels.
static func _sentence_case(property_name: String) -> String:
	var words := property_name.capitalize()
	return words.left(1) + words.substr(1).to_lower()


static func _read_range(tunable: WorkshopTunable, property: Dictionary) -> void:
	if property.hint != PROPERTY_HINT_RANGE:
		tunable.minimum = 0.0
		tunable.maximum = 100.0
		tunable.step = 1.0 if tunable.kind == WorkshopTunable.Kind.WHOLE else 0.01
		return
	var parts := String(property.hint_string).split(",")
	tunable.minimum = float(parts[0])
	tunable.maximum = float(parts[1]) if parts.size() > 1 else tunable.minimum + 1.0
	tunable.step = float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else 0.01
	for extra: String in parts:
		if extra.begins_with("suffix:"):
			tunable.unit = extra.trim_prefix("suffix:")


## A curve over course progress becomes two rows, its value at the start and at the finish.
static func _curve_points(base: WorkshopTunable, curve: Curve) -> Array[WorkshopTunable]:
	var result: Array[WorkshopTunable] = []
	for point: int in curve.point_count:
		var row := WorkshopTunable.new()
		row.part = base.part
		row.property = base.property
		row.group = base.group
		row.help = base.help
		row.live = base.live
		row.kind = WorkshopTunable.Kind.CURVE_POINT
		row.point = point
		var at := (
			"start"
			if point == 0
			else "finish"
			if point == curve.point_count - 1
			else "point %d" % (point + 1)
		)
		row.label = "%s at %s" % [base.label, at]
		row.minimum = curve.min_value
		row.maximum = curve.max_value
		row.step = 0.05 if curve.max_value > 2.0 else 0.01
		result.append(row)
	return result


static func _script_properties(holder: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for property: Dictionary in holder.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result.append(property)
	return result


## The [code]##[/code] comment above each variable of [param script]. Workshops run from the
## project, so the source is there.
static func _help_comments(script: Script) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = { }
	if script == null or not script.has_source_code():
		return result
	var comment := PackedStringArray()
	var declaration := RegEx.create_from_string("\\bvar\\s+(\\w+)")
	for line: String in script.source_code.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("##"):
			comment.append(stripped.trim_prefix("##").strip_edges())
			continue
		var found := declaration.search(stripped)
		if found != null and not comment.is_empty():
			result[found.get_string(1)] = " ".join(comment)
		if not stripped.begins_with("@export") or found != null:
			comment.clear()
	return result


func _apply(tunable_to_set: WorkshopTunable, new_value: Variant) -> void:
	tunable_to_set.write(edited, new_value)
	if tunable_to_set.live:
		tunable_to_set.write(running, new_value)
		live_changed.emit(tunable_to_set)
	changed.emit()


func _replace(preset: Resource) -> void:
	edited = copy(preset)
	for each: WorkshopTunable in tunables:
		if each.live and not each.same(each.read(running), each.read(edited)):
			each.write(running, each.read(edited))
			live_changed.emit(each)
	changed.emit()


func _push_step() -> void:
	_undo_steps.append(copy(edited))
	_redo_steps.clear()


func _clear_steps() -> void:
	_undo_steps.clear()
	_redo_steps.clear()
	_last_key = ""
