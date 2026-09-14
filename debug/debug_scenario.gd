class_name DebugScenario
extends RefCounted
## Small registration record. Scenario owners only need to add one entry to the catalog.

var id: StringName
var display_name: String
var scene_path: String
var required_feature: String

func _init(
		new_id: StringName,
		new_display_name: String,
		new_scene_path: String,
		new_required_feature: String = ""
) -> void:
	id = new_id
	display_name = new_display_name
	scene_path = new_scene_path
	required_feature = new_required_feature

func availability(features: Dictionary) -> Dictionary:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path, "PackedScene"):
		return {"available": false, "reason": "Scenario not implemented yet"}
	if not required_feature.is_empty() and not bool(features.get(required_feature, false)):
		return {"available": false, "reason": "Requires %s" % required_feature}
	return {"available": true, "reason": ""}
