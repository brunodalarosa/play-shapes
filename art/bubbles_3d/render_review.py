"""Render review images of the jellyfish or pufferfish into ignored scratch/review/.

Usage: blender --background --factory-startup --python render_review.py -- <model> [--exported]

Writes front, side and three-quarter views on grey, and a 1920 x 1080 gameplay frame on blue
through the scene's 30 degree camera framing the 19.2-unit play plane, with crops of each
creature at true pixel size and enlarged four times.
"""

import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

DIRECTORY = Path(__file__).resolve().parent
OUTPUT = DIRECTORY / "scratch" / "review"
PLANE_WIDTH = 19.2
FIELD_OF_VIEW = 30.0

# Directions in Blender coordinates. The GLB's -Z is Blender's +Y, so the jellyfish faces
# +Y; the pufferfish faces +X. The game camera looks along the GLB's -Z, from Blender's -Y.
MODELS = {
    "jellyfish": {
        "views": {
            "front": Vector((0, 1, 0.12)),
            "side": Vector((1, 0, 0.12)),
            "three-quarter": Vector((0.75, 1, 0.35)),
        },
        # Turned to face the game camera, as the scene will place it.
        "game": [(0.0, 0.0, 180.0, Vector((-1.5, 0, 0)))],
    },
    "pufferfish": {
        "views": {
            "front": Vector((1, 0, 0.12)),
            "side": Vector((0, -1, 0.12)),
            "three-quarter": Vector((1, -0.9, 0.35)),
        },
        # Heading right, diagonally up-right, diagonally down-left and turned toward the camera.
        "game": [
            (0.0, 0.0, 0.0, Vector((1.0, 0, 1.2))),
            (0.0, -45.0, 0.0, Vector((3.2, 0, 1.2))),
            (0.0, 135.0, 0.0, Vector((1.0, 0, -1.0))),
            (0.0, 0.0, -35.0, Vector((3.2, 0, -1.0))),
        ],
    },
}


def linear(hex_color):
    def channel(value):
        value /= 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return (*[channel(int(hex_color[i : i + 2], 16)) for i in (1, 3, 5)], 1.0)


def load_model(name, exported):
    if exported:
        bpy.ops.import_scene.gltf(filepath=str(DIRECTORY / name / "export" / f"{name}.glb"))
        objects = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    else:
        path = DIRECTORY / name / f"{name}.blend"
        with bpy.data.libraries.load(str(path)) as (source, target):
            target.objects = list(source.objects)
        objects = [o for o in target.objects if o.type == "MESH"]
        for obj in objects:
            bpy.context.scene.collection.objects.link(obj)
    root = bpy.data.objects.new(f"{name} root", None)
    bpy.context.scene.collection.objects.link(root)
    for obj in objects:
        if obj.parent is None:
            obj.parent = root
    return root, objects


def studio(background):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.6
    world = bpy.data.worlds.new("Review")
    scene.world = world
    world.color = background[:3]
    background_node = world.node_tree.nodes["Background"]
    background_node.inputs["Color"].default_value = background
    background_node.inputs["Strength"].default_value = 1.0
    for rotation, energy in (((50, 0, 30), 3.0), ((60, 0, -150), 1.2), ((-30, 0, 90), 0.8)):
        light = bpy.data.lights.new("Light", "SUN")
        light.energy = energy
        light.angle = math.radians(20)
        obj = bpy.data.objects.new("Light", light)
        obj.rotation_euler = [math.radians(a) for a in rotation]
        scene.collection.objects.link(obj)


def camera(location, target, orthographic_scale=None):
    data = bpy.data.cameras.new("Camera")
    obj = bpy.data.objects.new("Camera", data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()
    if orthographic_scale:
        data.type = "ORTHO"
        data.ortho_scale = orthographic_scale
    else:
        data.sensor_fit = "HORIZONTAL"
        data.angle = math.radians(FIELD_OF_VIEW)
    bpy.context.scene.camera = obj
    return obj


def render(path, width, height, border=None):
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.use_border = border is not None
    scene.render.use_crop_to_border = border is not None
    if border:
        scene.render.border_min_x, scene.render.border_min_y = border[0], border[1]
        scene.render.border_max_x, scene.render.border_max_y = border[2], border[3]
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def enlarge(path, factor):
    image = bpy.data.images.load(str(path))
    image.scale(image.size[0] * factor, image.size[1] * factor)
    image.filepath_raw = str(path.with_name(path.stem + "-x4.png"))
    image.file_format = "PNG"
    image.save()


def views(name, exported, suffix):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    root, objects = load_model(name, exported)
    studio(linear("#C8C8C8"))
    points = [o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    size = max(high - low)
    middle = (low + high) / 2
    for view, direction in MODELS[name]["views"].items():
        camera(middle + direction.normalized() * 10, middle, size * 1.35)
        render(OUTPUT / f"{name}-{view}{suffix}.png", 900, 900)


def gameplay(name, exported, suffix):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    studio(linear("#1E88C8"))
    distance = PLANE_WIDTH / 2 / math.tan(math.radians(FIELD_OF_VIEW) / 2)
    camera(Vector((0, -distance, 0)), Vector())
    placed = []
    for rx, ry, rz, location in MODELS[name]["game"]:
        root, _objects = load_model(name, exported)
        root.rotation_euler = [math.radians(a) for a in (rx, ry, rz)]
        root.location = location
        placed.append(location)
    frame = OUTPUT / f"{name}-gameplay{suffix}.png"
    render(frame, 1920, 1080)

    # Crop around the placed creatures, in normalized frame coordinates.
    xs = [0.5 + p.x / PLANE_WIDTH for p in placed]
    zs = [0.5 + p.z / (PLANE_WIDTH * 9 / 16) for p in placed]
    margin = 1.2 / PLANE_WIDTH
    border = (
        min(xs) - margin,
        min(zs) - margin * 16 / 9,
        max(xs) + margin,
        max(zs) + margin * 16 / 9,
    )
    crop = OUTPUT / f"{name}-gameplay-crop{suffix}.png"
    render(crop, 1920, 1080, border)
    enlarge(crop, 4)


def main():
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    name = arguments[0]
    exported = "--exported" in arguments
    suffix = "-export" if exported else ""
    OUTPUT.mkdir(parents=True, exist_ok=True)
    views(name, exported, suffix)
    gameplay(name, exported, suffix)


main()
