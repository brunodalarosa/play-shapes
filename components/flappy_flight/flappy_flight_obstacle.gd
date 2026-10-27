class_name FlappyFlightObstacle
extends RefCounted
## One obstacle pair: a ground box from the ground to the gap and a hanging box from the gap up
## without end, so flying high never skips it. Metres along the course and above the ground.

var x_start := 0.0
var x_end := 0.0
var gap_bottom := 0.0
var gap_top := 0.0
## Where a Cubio waits after this obstacle hits it, before its front face.
var respawn_x := 0.0
var respawn_y := 0.0


static func from_dictionary(data: Dictionary) -> FlappyFlightObstacle:
	var obstacle := FlappyFlightObstacle.new()
	obstacle.x_start = data.x_start
	obstacle.x_end = data.x_end
	obstacle.gap_bottom = data.gap_bottom
	obstacle.gap_top = data.gap_top
	obstacle.respawn_x = data.respawn_x
	obstacle.respawn_y = data.respawn_y
	return obstacle


func gap_centre() -> float:
	return (gap_bottom + gap_top) * 0.5


func to_dictionary() -> Dictionary:
	return {
		"x_start": x_start,
		"x_end": x_end,
		"gap_bottom": gap_bottom,
		"gap_top": gap_top,
		"respawn_x": respawn_x,
		"respawn_y": respawn_y,
	}
