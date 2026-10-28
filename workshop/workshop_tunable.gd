class_name WorkshopTunable
extends RefCounted
## One value of a minigame preset the Tunables panel shows as a row: a number, a switch, or one
## end of a difficulty curve. Found by [method WorkshopTuning.discover].

enum Kind {
	NUMBER,
	WHOLE,
	SWITCH,
	CURVE_POINT,
}

## The preset property holding the part, such as [code]flight[/code]; empty for the preset itself.
var part := ""
var property := ""
## The curve point this row edits, for [constant CURVE_POINT].
var point := 0
var kind := Kind.NUMBER
## The tab the row sits in, named after the part, and the export group inside it.
var tab := ""
var group := ""
var label := ""
var help := ""
var minimum := 0.0
var maximum := 1.0
var step := 0.01
var unit := ""
## Applies while the game runs; otherwise waits for a restart.
var live := false


## A stable key, such as [code]course/gap_height:1[/code].
func key() -> String:
	var name := property if part.is_empty() else "%s/%s" % [part, property]
	return name if kind != Kind.CURVE_POINT else "%s:%d" % [name, point]


## The value in [param preset], a Resource of the minigame's tuning class.
func read(preset: Resource) -> Variant:
	var owner := holder(preset)
	if owner == null:
		return null
	var value: Variant = owner.get(property)
	if kind == Kind.CURVE_POINT:
		var curve := value as Curve
		if curve == null or point >= curve.point_count:
			return null
		return curve.get_point_position(point).y
	return value


func write(preset: Resource, value: Variant) -> void:
	var owner := holder(preset)
	if owner == null:
		return
	if kind == Kind.CURVE_POINT:
		var curve := owner.get(property) as Curve
		if curve != null and point < curve.point_count:
			if value > curve.max_value:
				curve.max_value = value
			curve.set_point_value(point, value)
		return
	owner.set(property, value)


## The Resource that holds the value: the preset or one of its parts.
func holder(preset: Resource) -> Resource:
	if preset == null or part.is_empty():
		return preset
	return preset.get(part) as Resource


func same(a: Variant, b: Variant) -> bool:
	if a is float or b is float:
		return a != null and b != null and is_equal_approx(float(a), float(b))
	return a == b


## The value as the row shows it, with its unit.
func format(value: Variant) -> String:
	if value == null:
		return "-"
	match kind:
		Kind.SWITCH:
			return "On" if value else "Off"
		Kind.WHOLE:
			return "%d%s" % [value, unit_suffix()]
	var decimals := 0 if step >= 1.0 else clampi(ceili(-log(step) / log(10.0) - 0.0001), 0, 4)
	return "%s%s" % [String.num(float(value), decimals), unit_suffix()]


func unit_suffix() -> String:
	return "" if unit.is_empty() else " %s" % unit
