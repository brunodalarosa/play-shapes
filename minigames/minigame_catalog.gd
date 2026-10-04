class_name MinigameCatalog
extends Resource
## The minigames the host offers, in the order the lobby lists them.

@export var minigames: Array[MinigameDefinition] = []


## Returns the minigame with this id, or null.
func find(id: StringName) -> MinigameDefinition:
	for minigame: MinigameDefinition in minigames:
		if minigame.id == id:
			return minigame

	return null
