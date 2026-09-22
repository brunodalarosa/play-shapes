class_name BubblesPlayerVisual
extends Node2D
## Code-drawn bubble and temporary captured-jellyfish markers. Never decides rules.

var radius := 48.0
var captured_visual_count := 0
var spinning := false
var recovery_white := false


func update_appearance(new_radius: float, visual_count: int, active_spin: bool, white_blink: bool) -> void:
	radius = maxf(1.0, new_radius)
	captured_visual_count = maxi(0, visual_count)
	spinning = active_spin
	recovery_white = white_blink
	queue_redraw()


func _draw() -> void:
	var rim := Color(1.0, 1.0, 1.0, 0.95) if recovery_white else Color(0.68, 0.95, 1.0, 0.91)
	draw_circle(Vector2.ZERO, radius, Color(0.32, 0.81, 0.99, 0.15), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, rim, 3.0, true)
	draw_arc(Vector2(-radius * 0.14, -radius * 0.12), radius * 0.7, PI * 1.09, PI * 1.55,
		32, Color(1.0, 1.0, 1.0, 0.66), 4.0, true)
	for index: int in captured_visual_count:
		var turn := float(index) * 2.39996323
		var distance := sqrt((float(index) + 0.5) / float(maxi(captured_visual_count, 1))) * radius * 0.67
		var center := Vector2(cos(turn), sin(turn)) * distance
		var size := clampf(radius * 0.075, 3.0, 7.0)
		draw_circle(center, size, Color(0.61, 0.48, 0.95, 0.72), true, -1.0, true)
		draw_line(center + Vector2(-size * 0.4, size * 0.4), center + Vector2(-size * 0.55, size * 1.6), Color(0.84, 0.72, 1.0, 0.8), 1.5, true)
		draw_line(center + Vector2(size * 0.4, size * 0.4), center + Vector2(size * 0.55, size * 1.6), Color(0.84, 0.72, 1.0, 0.8), 1.5, true)
	if spinning:
		draw_arc(Vector2.ZERO, radius + 9.0, -0.3, 1.6, 24, Color(0.98, 0.91, 0.52, 0.95), 4.0, true)
		draw_arc(Vector2.ZERO, radius + 9.0, PI - 0.3, PI + 1.6, 24, Color(0.98, 0.91, 0.52, 0.95), 4.0, true)
