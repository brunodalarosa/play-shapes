class_name BubblesPlayerVisual
extends Node2D
## Procedural shared-screen bubble and burst. Collision geometry lives elsewhere.

const SMALL_JELLYFISH: Texture2D = preload("res://assets/runtime/minigames/bubbles_and_jellyfishes/jellyfish/jellyfish_small.png")
const RIM_COLORS: Array[Color] = [Color("6eeaff"), Color("a785ff"), Color("ff8bce"), Color("ffdf9d"), Color("8af8c7")]

var radius := 48.0
var captured_visual_count := 0
var spinning := false
var recovery_white := false
var pull := Vector2.ZERO
var surface_angle := 0.0
var burst_progress := -1.0
var particle_density := 10


func update_appearance(new_radius: float, visual_count: int, active_spin: bool, white_blink: bool,
		new_pull: Vector2 = Vector2.ZERO, angle: float = 0.0, burst: float = -1.0, density: int = 10) -> void:
	radius = maxf(1.0, new_radius)
	captured_visual_count = maxi(0, visual_count)
	spinning = active_spin
	recovery_white = white_blink
	pull = new_pull
	surface_angle = angle
	burst_progress = burst
	particle_density = clampi(density, 0, 32)
	queue_redraw()


func _draw() -> void:
	if burst_progress >= 0.0 and burst_progress < 1.0:
		_draw_burst()
		return
	var stretch := clampf(pull.length(), 0.0, 0.22)
	var along := pull.normalized() if stretch > 0.001 else Vector2.RIGHT
	var sideways := along.orthogonal()
	var center := along * radius * stretch * 0.22
	var ellipse := PackedVector2Array()
	for index: int in 65:
		var theta := float(index) * TAU / 64.0
		ellipse.append(center + along * cos(theta) * radius * (1.0 + stretch) + sideways * sin(theta) * radius * (1.0 - stretch * 0.46))
	# A thin translucent wash preserves the character and captured markers.
	draw_colored_polygon(ellipse, Color(0.27, 0.75, 1.0, 0.10))
	draw_arc(center + Vector2(radius * 0.04, radius * 0.04), radius * 0.79,
		0.15 + surface_angle, 1.35 + surface_angle, 22, Color(0.43, 0.83, 1.0, 0.13), maxf(3.0, radius * 0.12), true)
	draw_arc(center, radius * 0.87, 2.2 + surface_angle, 3.9 + surface_angle,
		24, Color(0.74, 0.63, 1.0, 0.10), maxf(3.0, radius * 0.09), true)
	_draw_rim(ellipse, 1.0 if recovery_white else 0.88)
	for index: int in 12:
		var start := float(index) * TAU / 12.0 + surface_angle
		var color := Color.WHITE if recovery_white else RIM_COLORS[index % RIM_COLORS.size()]
		draw_arc(center, radius * (0.97 + stretch * 0.25), start, start + TAU / 12.0 + 0.04,
			9, Color(color.r, color.g, color.b, 0.50), maxf(2.0, radius * 0.055), true)
	draw_arc(center + Vector2(-radius * 0.08, -radius * 0.08), radius * 0.74,
		-2.55 + surface_angle, -1.65 + surface_angle, 20, Color(1, 1, 1, 0.76), maxf(2.0, radius * 0.055), true)
	draw_arc(center, radius * 0.91, 0.38 + surface_angle, 1.15 + surface_angle,
		16, Color(0.87, 1.0, 1.0, 0.34), maxf(1.5, radius * 0.03), true)
	for index: int in captured_visual_count:
		var turn := float(index) * 2.39996323
		var distance := sqrt((float(index) + 0.5) / float(maxi(captured_visual_count, 1))) * radius * 0.67
		var marker_center := Vector2(cos(turn), sin(turn)) * distance
		var width := clampf(radius * 0.25, 22.0, 32.0)
		var size := Vector2(width, width * float(SMALL_JELLYFISH.get_height()) / float(SMALL_JELLYFISH.get_width()))
		draw_texture_rect(SMALL_JELLYFISH, Rect2(marker_center - size * 0.5, size), false, Color(1, 1, 1, 0.82))
	if spinning:
		_draw_decorative_bubbles()


func _draw_rim(points: PackedVector2Array, opacity: float) -> void:
	draw_polyline(points, Color(0.73, 0.97, 1.0, 0.65 * opacity), maxf(2.0, radius * 0.045), true)
	draw_polyline(points, Color(1, 1, 1, 0.56 * opacity), maxf(1.0, radius * 0.016), true)


func _draw_decorative_bubbles() -> void:
	for index: int in particle_density:
		var phase := float(index) * 2.39996 + surface_angle * (0.55 + float(index % 3) * 0.2)
		var point := Vector2.from_angle(phase) * radius * (1.12 + float(index % 4) * 0.075)
		var size := 2.2 + float(index % 3) * 1.2
		draw_arc(point, size, 0.0, TAU, 12, Color(0.8, 0.98, 1, 0.52), 1.2, true)
		draw_circle(point + Vector2(-size * 0.28, -size * 0.3), 0.7, Color(1, 1, 1, 0.7))


func _draw_burst() -> void:
	var age := clampf(burst_progress, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.45, 1.0, age)
	var fragment_count := maxi(4, int(particle_density / 2.0))
	for index: int in fragment_count:
		var phase := float(index) * TAU / float(fragment_count) + 0.14
		var center := Vector2.from_angle(phase) * radius * (0.25 + age * 1.14)
		var color := RIM_COLORS[index % RIM_COLORS.size()]
		draw_arc(center, radius * (0.30 - age * 0.17), phase + 1.0, phase + 2.7,
			11, Color(color.r, color.g, color.b, 0.83 * fade), maxf(2.0, radius * 0.055), true)
		draw_arc(center, radius * (0.27 - age * 0.16), phase + 1.05, phase + 2.5,
			10, Color(1, 1, 1, 0.38 * fade), maxf(1.0, radius * 0.016), true)
	for index: int in particle_density:
		var phase := float(index) * 2.39996
		var point := Vector2.from_angle(phase) * radius * (0.35 + age * (0.75 + float(index % 4) * 0.13))
		if index % 4 == 0:
			var star := 2.0 + float(index % 3)
			draw_line(point - Vector2(star, 0), point + Vector2(star, 0), Color(1, 1, 0.87, fade), 1.2, true)
			draw_line(point - Vector2(0, star), point + Vector2(0, star), Color(1, 1, 0.87, fade), 1.2, true)
		else:
			draw_arc(point, 2.0 + float(index % 3), 0.0, TAU, 12, Color(0.8, 0.97, 1, 0.75 * fade), 1.3, true)
