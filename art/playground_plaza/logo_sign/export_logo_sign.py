"""Build the cafe rooftop logo sign from the approved logo PNG and export it as a GLB.

The letters are traced from the artwork rather than modeled: each color is thresholded,
outlined with marching squares, simplified and extruded as a filled 2D curve. A cream
backing traced from the dilated outline and four metal posts complete the sign.
"""

import hashlib
import json
import math
from pathlib import Path

import bpy
import numpy as np


DIRECTORY = Path(__file__).resolve().parent
SOURCE = DIRECTORY.parent.parent / "logo" / "play-shapes-logo.png"
EXPORT = DIRECTORY / "export" / "logo_sign.glb"
REPORT = DIRECTORY / "export" / "verification.json"

# Sizes in plaza units, where the cafe roof is 7 wide.
WIDTH = 7.2
LIFT = 0.9
LETTER_HALF_DEPTH = 0.3
LETTER_BEVEL = 0.03
BACKING_HALF_DEPTH = 0.14
BACKING_OFFSET = 0.43
BACKING_MARGIN_PIXELS = 9
POST_RADIUS = 0.07
POST_FRACTIONS = (-0.36, -0.12, 0.12, 0.36)
# Traced at half the master's resolution; outlines keep points within this many pixels.
SAMPLE_STEP = 2
SIMPLIFY_PIXELS = 0.9
MAX_TRIANGLES = 9000

CREAM = (0.97, 0.93, 0.85)
METAL = (0.55, 0.6, 0.68)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def linear(srgb):
    return tuple(channel**2.2 for channel in srgb)


def load_pixels():
    image = bpy.data.images.load(str(SOURCE))
    width, height = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    # Blender stores rows bottom first; tracing works top first.
    return pixels[::-1][::SAMPLE_STEP, ::SAMPLE_STEP, :3]


def masks(pixels):
    # The background is a low-saturation cream; both letter colors are saturated.
    saturation = pixels.max(axis=2) - pixels.min(axis=2)
    ink = np.clip((saturation - 0.12) / 0.3, 0.0, 1.0)
    blue = ink * (pixels[..., 2] > pixels[..., 0])
    orange = ink * (pixels[..., 0] >= pixels[..., 2])
    return ink, blue, orange


def dilate(mask, radius):
    out = mask.copy()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy <= radius * radius:
                out = np.maximum(out, np.roll(np.roll(mask, dy, 0), dx, 1))
    return out


# Marching-squares cases: corner bits are top-left 1, top-right 2, bottom-right 4,
# bottom-left 8; edges are 0 top, 1 right, 2 bottom, 3 left. Each pair runs with the
# filled side on its right, so every outline is a closed, consistently wound loop.
CASES = {
    1: [(3, 0)],
    2: [(0, 1)],
    3: [(3, 1)],
    4: [(1, 2)],
    5: [(3, 0), (1, 2)],
    6: [(0, 2)],
    7: [(3, 2)],
    8: [(2, 3)],
    9: [(2, 0)],
    10: [(0, 1), (2, 3)],
    11: [(2, 1)],
    12: [(1, 3)],
    13: [(1, 0)],
    14: [(0, 3)],
}


def trace(field):
    padded = np.pad(field, 1)
    inside = (padded > 0.5).astype(np.uint8)
    case = inside[:-1, :-1] + inside[:-1, 1:] * 2 + inside[1:, 1:] * 4 + inside[1:, :-1] * 8

    def edge_key(row, column, edge):
        return [
            ("h", row, column),
            ("v", row, column + 1),
            ("h", row + 1, column),
            ("v", row, column),
        ][edge]

    def point(key):
        kind, row, column = key
        if kind == "h":
            a, b = padded[row, column], padded[row, column + 1]
            return (column - 1 + (0.5 - a) / (b - a), row - 1)
        a, b = padded[row, column], padded[row + 1, column]
        return (column - 1, row - 1 + (0.5 - a) / (b - a))

    following = {}
    for row, column in zip(*np.nonzero((case > 0) & (case < 15))):
        for start, end in CASES[int(case[row, column])]:
            following[edge_key(row, column, start)] = edge_key(row, column, end)

    loops = []
    while following:
        key = next(iter(following))
        loop = []
        while key in following:
            loop.append(point(key))
            key = following.pop(key)
        if len(loop) > 8:
            loops.append(loop)
    return loops


def simplify_open(points, tolerance):
    if len(points) < 3:
        return points
    first, last = np.array(points[0]), np.array(points[-1])
    direction = last - first
    length = math.hypot(*direction) or 1.0
    distances = [
        abs(direction[0] * (p[1] - first[1]) - direction[1] * (p[0] - first[0])) / length
        for p in points
    ]
    index = int(np.argmax(distances))
    if distances[index] <= tolerance:
        return [points[0], points[-1]]
    return simplify_open(points[: index + 1], tolerance)[:-1] + simplify_open(
        points[index:], tolerance
    )


def simplify(loop):
    half = len(loop) // 2
    head = simplify_open(loop[: half + 1], SIMPLIFY_PIXELS)[:-1]
    return head + simplify_open(loop[half:] + [loop[0]], SIMPLIFY_PIXELS)[:-1]


def material(name, color, metallic=0.0, roughness=0.8):
    result = bpy.data.materials.new(name)
    shader = result.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return result


def median_color(pixels, mask):
    return linear(float(v) for v in np.median(pixels[mask > 0.99], axis=0))


def extruded(name, field, frame, half_depth, bevel, depth_offset, item):
    """A filled curve from the field's outlines, standing upright and facing glTF +Z."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "2D"
    curve.fill_mode = "BOTH"
    curve.extrude = half_depth
    curve.bevel_depth = bevel
    curve.bevel_resolution = 1
    left, bottom, scale = frame
    for loop in trace(field):
        loop = simplify(loop)
        spline = curve.splines.new("POLY")
        spline.points.add(len(loop) - 1)
        for target, (x, y) in zip(spline.points, loop):
            target.co = ((x - left) * scale - WIDTH / 2, (bottom - y) * scale, 0.0, 1.0)
        spline.use_cyclic_u = True
    curve.materials.append(item)

    holder = bpy.data.objects.new(name + " Curve", curve)
    bpy.context.scene.collection.objects.link(holder)
    graph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(holder.evaluated_get(graph))
    bpy.data.objects.remove(holder)
    mesh.name = name

    # Stand the outline up: the curve's +Z front becomes Blender -Y, which is glTF +Z.
    for vertex in mesh.vertices:
        x, y, z = vertex.co
        vertex.co = (x, -(z + depth_offset), y + LIFT)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def joined(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = result.data.name = name
    return result


def posts(metal, top):
    bpy.ops.object.select_all(action="DESELECT")
    parts = []
    for fraction in POST_FRACTIONS:
        x = fraction * WIDTH
        y = BACKING_OFFSET + BACKING_HALF_DEPTH + POST_RADIUS * 0.5
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=8, radius=POST_RADIUS, depth=top, location=(x, y, top / 2)
        )
        parts.append(bpy.context.object)
        bpy.ops.mesh.primitive_cone_add(
            vertices=8, radius1=0.2, radius2=0.16, depth=0.1, location=(x, y, 0.05)
        )
        parts.append(bpy.context.object)
    result = joined("Posts", parts)
    result.data.materials.clear()
    result.data.materials.append(metal)
    return result


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def bounds(objects):
    points = np.array([obj.matrix_world @ v.co for obj in objects for v in obj.data.vertices])
    return points.min(axis=0), points.max(axis=0)


def main():
    require(SOURCE.exists(), f"Missing logo source {SOURCE}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    pixels = load_pixels()
    ink, blue, orange = masks(pixels)

    rows, columns = np.nonzero(ink > 0.5)
    scale = WIDTH / float(columns.max() - columns.min())
    height = float(rows.max() - rows.min()) * scale
    frame = (float(columns.min()), float(rows.max()), scale)

    # Each color is traced on its own, so every letter keeps its artwork color.
    colored = [
        extruded(
            name,
            mask,
            frame,
            LETTER_HALF_DEPTH,
            LETTER_BEVEL,
            0.0,
            material("Logo " + name, median_color(pixels, mask)),
        )
        for name, mask in (("Blue", blue), ("Orange", orange))
    ]
    letters = joined("Letters", colored)

    outline = np.clip(dilate((ink > 0.5).astype(np.float32), BACKING_MARGIN_PIXELS), 0, 1)
    backing = extruded(
        "Backing",
        outline,
        frame,
        BACKING_HALF_DEPTH,
        0.0,
        -BACKING_OFFSET,
        material("Logo Backing", linear(CREAM)),
    )
    metal = material("Sign Metal", linear(METAL), metallic=0.6, roughness=0.35)
    support = posts(metal, LIFT + height / 2)

    parts = [letters, backing, support]
    counts = {obj.name: triangles(obj) for obj in parts}
    total = sum(counts.values())
    require(total <= MAX_TRIANGLES, f"Sign has {total} triangles, above {MAX_TRIANGLES}")
    low, high = bounds(parts)
    require(abs(low[2]) < 0.001, "The posts stand on the sign origin")
    letters_low, letters_high = bounds([letters])
    require(
        abs(letters_high[0] - letters_low[0] - WIDTH) < 0.1, "The letters keep the planned width"
    )

    root = bpy.data.objects.new("LogoSign", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in parts:
        obj.parent = root
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [root, *parts]:
        obj.select_set(True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), use_selection=True, export_yup=True, export_apply=True
    )

    report = {
        "source": SOURCE.name,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "export_sha256": hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
        "triangles": counts,
        "total_triangles": total,
        "materials": [m.name for m in bpy.data.materials if m.users],
        # Blender Z up; the GLB swaps it to Y up.
        "bounds_min": [round(float(v), 3) for v in low],
        "bounds_max": [round(float(v), 3) for v in high],
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


main()
