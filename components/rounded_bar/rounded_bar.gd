class_name RoundedBar
extends RefCounted
## A bar with rounded corners, built from its measurements alone: the front outline, a mesh
## extruded from it and a convex collider with the same outline. Length runs along X, thickness
## along Y and depth along Z, all centred on the origin. The corner radius stays the same when
## the length changes, so the ends never stretch. Nothing reads node scale.

## Arc segments per corner unless a caller asks for more.
const CORNER_SEGMENTS := 5


## The outline in the XY plane, counter-clockwise from the right end's upper corner. The
## radius is clamped to half the shorter side.
static func outline(
	length: float,
	thickness: float,
	radius: float,
	segments := CORNER_SEGMENTS,
) -> PackedVector2Array:
	var half := Vector2(maxf(length, 0.0001), maxf(thickness, 0.0001)) * 0.5
	var corner := clampf(radius, 0.0, minf(half.x, half.y))
	var inner := half - Vector2(corner, corner)
	var centres: Array[Vector2] = [
		Vector2(inner.x, inner.y),
		Vector2(-inner.x, inner.y),
		Vector2(-inner.x, -inner.y),
		Vector2(inner.x, -inner.y),
	]
	var count := maxi(segments, 1)
	var points := PackedVector2Array()
	for index: int in 4:
		var start := index * PI * 0.5
		for step: int in count + 1:
			var angle := start + PI * 0.5 * float(step) / float(count)
			points.append(centres[index] + Vector2(cos(angle), sin(angle)) * corner)
	return points


## A mesh of the bar: front and back faces and the side wall, with flat normals on the faces
## and normals that follow the outline on the wall.
static func mesh(
	length: float,
	thickness: float,
	depth: float,
	radius: float,
	segments := CORNER_SEGMENTS,
) -> ArrayMesh:
	var points := outline(length, thickness, radius, segments)
	var front := depth * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Godot treats clockwise triangles, seen from outside, as front faces.
	for side: float in [front, -front]:
		var normal := Vector3(0.0, 0.0, signf(side))
		var centre := vertices.size()
		vertices.append(Vector3(0.0, 0.0, side))
		normals.append(normal)
		for point: Vector2 in points:
			vertices.append(Vector3(point.x, point.y, side))
			normals.append(normal)
		for index: int in points.size():
			var next := (index + 1) % points.size()
			if side > 0.0:
				indices.append_array([centre, centre + 1 + next, centre + 1 + index])
			else:
				indices.append_array([centre, centre + 1 + index, centre + 1 + next])

	for index: int in points.size():
		var next := (index + 1) % points.size()
		var a := points[index]
		var b := points[next]
		var base := vertices.size()
		var edge_normal := Vector3(b.y - a.y, a.x - b.x, 0.0).normalized()
		for point: Vector2 in [a, b]:
			var smooth := _wall_normal(point, length, thickness, radius, edge_normal)
			vertices.append(Vector3(point.x, point.y, front))
			normals.append(smooth)
			vertices.append(Vector3(point.x, point.y, -front))
			normals.append(smooth)
		indices.append_array([base, base + 2, base + 1, base + 2, base + 3, base + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


## A convex collider with the bar's outline and depth.
static func shape(
	length: float,
	thickness: float,
	depth: float,
	radius: float,
	segments := CORNER_SEGMENTS,
) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for point: Vector2 in outline(length, thickness, radius, segments):
		points.append(Vector3(point.x, point.y, depth * 0.5))
		points.append(Vector3(point.x, point.y, -depth * 0.5))
	var result := ConvexPolygonShape3D.new()
	result.points = points
	result.margin = 0.0
	return result


static func _wall_normal(
	point: Vector2,
	length: float,
	thickness: float,
	radius: float,
	flat: Vector3,
) -> Vector3:
	# On a corner arc the normal points away from the arc's centre; on a straight edge it is
	# the edge's own normal.
	var half := Vector2(length, thickness) * 0.5
	var corner := clampf(radius, 0.0, minf(half.x, half.y))
	var inner := half - Vector2(corner, corner)
	var centre := Vector2(clampf(point.x, -inner.x, inner.x), clampf(point.y, -inner.y, inner.y))
	var away := point - centre
	if corner <= 0.0 or away.length() < corner * 0.5:
		return flat
	return Vector3(away.x, away.y, 0.0).normalized()
