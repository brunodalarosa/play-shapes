class_name MinigameDefinition
extends Resource
## What the shared code knows about one minigame. The catalog lists one per minigame.
##
## The scene and the ready-screen content are paths, not loaded resources, so that listing
## a minigame does not load its art and sound.

## Stable identifier of the minigame for the host and the phones.
@export var id: StringName

## Name shown in the lobby, on the ready screen and in the debug menu.
@export var display_name: String

## The shared-screen scene of a round.
@export_file("*.tscn") var scene_path: String

## Largest number of players a round supports.
@export_range(2, 10) var max_players := 10

## The PreMinigameContent the ready screen shows.
@export_file("*.tres") var pre_minigame_content_path: String

## Whether the debug menu offers a round with exactly one registered player.
@export var one_player_debug := false


## Loads the ready-screen content, or returns null when the path does not lead to one.
func load_pre_minigame_content() -> PreMinigameContent:
	if not ResourceLoader.exists(pre_minigame_content_path):
		return null

	return load(pre_minigame_content_path) as PreMinigameContent
