class_name RaceCamera3D
extends Camera3D
## Follows a race on one vertical plane at z = 0, seen straight from the front. The leader sits
## [member leader_share] of the width from the left; the view zooms between
## [member closest_height] and [member farthest_height] of visible height to fit the others,
## centred at [member centre_height]. Pan and zoom are smoothed. It reads positions only.

## Where the leader sits, as a share of the width from the left. Default: 0.65.
@export_range(0.05, 0.95, 0.01) var leader_share := 0.65
## Visible height at the closest zoom, metres.
@export var closest_height := 34.0
## Visible height at the furthest zoom, metres.
@export var farthest_height := 54.0
## The height the view is centred on, metres.
@export var centre_height := 17.0
## Room kept around every fitted point, metres.
@export var margin := 2.0
## Time to settle most of the way to a new framing, s.
@export var smoothing_seconds := 0.4
## A leader that moves further than this in one frame is a new leader, and the pan eases to it.
@export var leader_jump := 3.0

## The framing as drawn now.
var visible_height := 34.0
var leader_x := 0.0
var _offset := 0.0
var _framed := false


## Frames [param leader] and as many of [param others] as the zoom allows. With [param delta]
## zero it jumps to the framing.
func frame_race(leader: Vector2, others: PackedVector2Array, delta: float) -> void:
	var target_height := fitted_height(leader, others)
	var keep := 0.0 if delta <= 0.0 or not _framed else exp(-delta / maxf(smoothing_seconds, 0.001))
	if _framed and absf(leader.x - (leader_x - _offset)) > leader_jump:
		_offset = leader_x - leader.x
	_offset *= keep
	leader_x = leader.x + _offset
	visible_height = lerpf(target_height, visible_height, keep)
	_framed = true
	_place()


## The visible height that fits [param others] around [param leader], within the zoom limits.
func fitted_height(leader: Vector2, others: PackedVector2Array) -> float:
	var aspect := view_aspect()
	var needed := closest_height
	var points := others.duplicate()
	points.append(leader)
	for point: Vector2 in points:
		var behind := leader.x - point.x + margin
		if behind > 0.0:
			needed = maxf(needed, behind / leader_share / aspect)
		var ahead := point.x - leader.x + margin
		if ahead > 0.0:
			needed = maxf(needed, ahead / (1.0 - leader_share) / aspect)
		needed = maxf(needed, (absf(point.y - centre_height) + margin) * 2.0)
	return clampf(needed, closest_height, farthest_height)


## The part of the plane in view, metres along the race and above the ground.
func visible_rect() -> Rect2:
	var width := visible_height * view_aspect()
	var bottom := centre_height - visible_height * 0.5
	return Rect2(leader_x - leader_share * width, bottom, width, visible_height)


func shows(point: Vector2) -> bool:
	return visible_rect().has_point(point)


func view_aspect() -> float:
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	return size.x / maxf(size.y, 1.0)


func _place() -> void:
	var shown := visible_rect()
	var distance := visible_height * 0.5 / tan(deg_to_rad(fov) * 0.5)
	position = Vector3(shown.get_center().x, centre_height, distance)
	rotation = Vector3.ZERO
