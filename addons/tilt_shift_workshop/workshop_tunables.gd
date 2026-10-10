@tool
extends RefCounted
## Editable controls derive their ranges and documentation from the runtime Resources.


static func editable_properties(resource: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for property: Dictionary in resource.get_property_list():
		if (
			property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
			and property.usage & PROPERTY_USAGE_EDITOR
		):
			if property.type in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_COLOR]:
				result.append(property)
	return result


static func range_values(property: Dictionary) -> Vector3:
	if property.hint == PROPERTY_HINT_RANGE:
		var values := String(property.hint_string).split(",")
		return Vector3(float(values[0]), float(values[1]), float(values[2]))
	return Vector3(-1000000000, 1000000000, 1)


static func help(resource: Resource, key: String) -> String:
	var script := resource.get_script() as Script
	var comments := PackedStringArray()
	for line: String in script.source_code.split("\n"):
		if line.strip_edges().begins_with("##"):
			comments.append(line.strip_edges().trim_prefix("##").strip_edges())
		elif line.contains("var " + key + ":") or line.contains("var " + key + " :="):
			var defaults: Resource = script.new()
			return " ".join(comments) + "\nDefault: " + str(defaults.get(key))
		elif not line.begins_with("@export") and not line.is_empty():
			comments.clear()
	return key.capitalize()
