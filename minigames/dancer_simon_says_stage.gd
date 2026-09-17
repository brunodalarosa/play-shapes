@tool
class_name DancerSimonSaysStage
extends Control
## Editor-authored presentation shell for Flash? Pose!.
## Gameplay may populate/configure these stable slots, but must not reposition them.

@export_group("Editor Preview")
## Number of player character previews shown in the editor and placement review.
## All ten seat nodes remain present and editable regardless of this value.
@export_range(2, 10, 1) var preview_player_count: int = 10:
	set(value):
		preview_player_count = clampi(value, 2, 10)
		_queue_preview_refresh()

## Turn off only the character previews when authoring empty-stage artwork.
## Anchor nodes remain visible in the scene tree and 2D editor.
@export var show_character_previews: bool = true:
	set(value):
		show_character_previews = value
		_queue_preview_refresh()


func _ready() -> void:
	_refresh_previews()


func lead_slot() -> Control:
	return get_node(^"LeadSlot") as Control


func player_slots() -> Array[Control]:
	var slots: Array[Control] = []
	for child: Node in get_node(^"PlayerSlots").get_children():
		if child is Control:
			slots.append(child as Control)
	return slots


func _queue_preview_refresh() -> void:
	if is_inside_tree():
		_refresh_previews.call_deferred()


func _refresh_previews() -> void:
	if not is_node_ready():
		return
	var slots := player_slots()
	for index: int in slots.size():
		var preview := slots[index].get_node_or_null(^"PreviewCharacter") as CanvasItem
		if preview != null:
			preview.visible = show_character_previews and index < preview_player_count
	var lead_preview := lead_slot().get_node_or_null(^"PreviewCharacter") as CanvasItem
	if lead_preview != null:
		lead_preview.visible = show_character_previews
