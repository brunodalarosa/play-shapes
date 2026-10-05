class_name TiltShiftTypes
extends RefCounted
## Stable scoring categories. Display names are presentation choices.

enum Team {
	ORANGE,
	BLUE,
	TRASH,
}


static func is_player_team(team: int) -> bool:
	return team == Team.ORANGE or team == Team.BLUE
