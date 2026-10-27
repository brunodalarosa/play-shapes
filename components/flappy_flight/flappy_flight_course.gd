class_name FlappyFlightCourse
extends RefCounted
## What the flight collides with: obstacles sorted along the course, pickups, the start and the
## finish line. The ground is at height zero and there is no ceiling.

var start_x := 0.0
var start_y := 0.0
var finish_x := 0.0
var obstacles: Array[FlappyFlightObstacle] = []
var pickups: Array[FlappyFlightPickup] = []


static func from_dictionary(data: Dictionary) -> FlappyFlightCourse:
	var course := FlappyFlightCourse.new()
	course.start_x = data.start_x
	course.start_y = data.start_y
	course.finish_x = data.finish_x
	for entry: Dictionary in data.obstacles:
		course.obstacles.append(FlappyFlightObstacle.from_dictionary(entry))
	for entry: Dictionary in data.pickups:
		course.pickups.append(FlappyFlightPickup.from_dictionary(entry))
	return course


func to_dictionary() -> Dictionary:
	return {
		"start_x": start_x,
		"start_y": start_y,
		"finish_x": finish_x,
		"obstacles": obstacles.map(
			func(obstacle: FlappyFlightObstacle) -> Dictionary:
				return obstacle.to_dictionary(),
		),
		"pickups": pickups.map(
			func(pickup: FlappyFlightPickup) -> Dictionary:
				return pickup.to_dictionary(),
		),
	}
