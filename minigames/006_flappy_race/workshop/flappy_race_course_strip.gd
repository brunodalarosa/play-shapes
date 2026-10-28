class_name FlappyRaceCourseStrip
extends Control
## The whole course as a strip: its obstacles, the finish and each racer's progress. A click
## picks the obstacle nearest the pointer.

signal picked(obstacle_index: int)

const BAR := WorkshopTheme.SECONDARY_CONTAINER
const OBSTACLE := WorkshopTheme.OUTLINE
const FINISH := WorkshopTheme.PRIMARY

var race: FlappyRaceController


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click to restart with the pack there"


func _draw() -> void:
	var bar := Rect2(0, size.y * 0.35, size.x, size.y * 0.3)
	draw_rect(bar, BAR)
	if race == null or race.course == null:
		return
	var length := race.course.length
	for obstacle: FlappyFlightObstacle in race.course.flight.obstacles:
		var x := obstacle.x_start / length * size.x
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), OBSTACLE, 1.0)
	draw_line(Vector2(size.x - 1, 0), Vector2(size.x - 1, size.y), FINISH, 2.0)
	for racer: FlappyRaceRacer in race.racers():
		var at := Vector2(clampf(racer.distance() / length, 0.0, 1.0) * size.x, size.y * 0.5)
		draw_circle(at, 6.0, Color.html(racer.character_color))
		draw_arc(at, 6.0, 0.0, TAU, 16, Color.BLACK, 1.0)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if race == null or race.course == null:
		return
	picked.emit(obstacle_at(click.position.x / maxf(size.x, 1.0) * race.course.length))
	accept_event()


## The obstacle whose respawn spot is nearest [param x], metres along the course.
func obstacle_at(x: float) -> int:
	var best := -1
	var best_distance := INF
	var obstacles := race.course.flight.obstacles
	for index: int in obstacles.size():
		var distance := absf(obstacles[index].respawn_x - x)
		if distance < best_distance:
			best = index
			best_distance = distance
	return best if x > race.course.flight.start_x + 1.0 else -1
