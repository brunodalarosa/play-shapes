class_name ShapeFaceLayer
extends RefCounted
## One face part placed in a face box measured in face heights.

var part := ""
## Centre from the box's centre, in face heights, X right and Y down.
var center := Vector2.ZERO
## Drawn size in face heights, margin included.
var size := Vector2.ONE
## Clockwise turn about the centre.
var rotation_degrees := 0.0
## Flipped horizontally about its centre before it turns.
var mirror := false


func copy() -> ShapeFaceLayer:
	var result := ShapeFaceLayer.new()
	result.part = part
	result.center = center
	result.size = size
	result.rotation_degrees = rotation_degrees
	result.mirror = mirror
	return result
