@tool
extends Control
## The same scheduler as gameplay, displayed as density bins and delivery ticks.

const Model := preload("res://addons/tilt_shift_workshop/workshop_model.gd")

var model: Model
var schedule := PackedInt32Array()
var bins := PackedInt32Array()


func setup(draft: Model) -> void:
	model = draft
	model.changed.connect(refresh)
	custom_minimum_size = Vector2(340, 100)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	refresh()


func refresh() -> void:
	schedule.clear()
	bins.resize(20)
	bins.fill(0)
	if model.profile.physics != null and model.profile.physics.validation_errors().is_empty():
		var duration := roundi(model.profile.round_duration_seconds * 1000.0)
		schedule = TiltShiftDelivery.schedule(
			model.profile.physics.ball_count,
			model.profile.physics.delivery_curve,
			duration,
		)
		for offset: int in schedule:
			bins[mini(19, floori(float(offset) / duration * 20.0))] += 1
	queue_redraw()


func _draw() -> void:
	if model == null or model.profile.physics == null:
		return
	var plot := Rect2(Vector2(32, 12), size - Vector2(46, 46))
	draw_rect(plot, Color("2b2925"))
	var maximum := maxi(1, int(Array(bins).max()))
	for index: int in bins.size():
		var height := float(bins[index]) / maximum * plot.size.y
		draw_rect(
			Rect2(
				plot.position + Vector2(index * plot.size.x / 20, plot.size.y - height),
				Vector2(plot.size.x / 20 - 2, height),
			),
			Color("657c9b"),
		)
	var curve: PackedVector2Array = model.profile.physics.delivery_curve
	var peak := 1.0
	for point: Vector2 in curve:
		peak = maxf(peak, point.y)
	for index: int in range(1, curve.size()):
		var a := plot.position + Vector2(
			curve[index - 1].x * plot.size.x,
			(1.0 - curve[index - 1].y / peak) * plot.size.y,
		)
		var b := plot.position + Vector2(
			curve[index].x * plot.size.x,
			(1.0 - curve[index].y / peak) * plot.size.y,
		)
		draw_line(a, b, Color("ec9644"), 2)
	var duration: float = model.profile.round_duration_seconds * 1000.0
	for offset: int in schedule:
		var x := plot.position.x + offset / duration * plot.size.x
		draw_line(Vector2(x, plot.end.y), Vector2(x, plot.end.y + 5), Color("a9c7eb"))
	var summary := "0%%–100%% • orange: relative intensity • blue: balls / %.2f s"
	summary %= model.profile.round_duration_seconds / 20.0
	draw_string(
		get_theme_default_font(),
		Vector2(12, size.y - 10),
		summary,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("d8d1c8"),
	)
