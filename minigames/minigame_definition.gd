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

## Fewest registered players a normal launch needs.
@export_range(1, 10) var min_players := 2

## Largest number of players a round supports.
@export_range(1, 10) var max_players := 10

## Empty accepts every count within the normal limits; otherwise only these counts launch.
@export var allowed_player_counts := PackedInt32Array()

## The PreMinigameContent the ready screen shows.
@export_file("*.tres") var pre_minigame_content_path: String

## Whether the debug menu offers a round with exactly one registered player. A minigame whose
## [member min_players] is 1 already launches normally with one player and offers none.
@export var one_player_debug := false

## A Node script that coordinates the minigame from the Pre-minigame screen into play, for a
## minigame that prepares its players, such as calibrating phone tilt. Empty for none.
## The session host creates it on first use, in its minigame_session().
@export_file("*.gd") var session_script: String


## Loads the ready-screen content, or returns null when the path does not lead to one.
func load_pre_minigame_content() -> PreMinigameContent:
	if not ResourceLoader.exists(pre_minigame_content_path):
		return null

	return load(pre_minigame_content_path) as PreMinigameContent
