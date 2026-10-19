"""Render review images of the exported bin into ignored scratch/review/.

Usage: blender --background --factory-startup --python render_review.py

Assembles bin/export/bin.glb as the scene will, at openings of 0.10, 0.20 and 0.40 arena widths
in orange, blue and grey, with Trim a lighter mix of the same colour. Writes a 1920 x 1080 frame
through the scene's 30 degree camera with the bins' fronts filling the band below the mouth
line, three-quarter views of each width in each colour, and the 0.20 width at 0.75 and 2 times
its height.
"""

import math
from pathlib import Path

import bpy
from mathutils import Vector

DIRECTORY = Path(__file__).resolve().parent
OUTPUT = DIRECTORY / "scratch" / "review"
GLB = DIRECTORY / "bin" / "export" / "bin.glb"
ARENA_WIDTH = 19.2
ARENA_HEIGHT = 10.8
FIELD_OF_VIEW = 30.0
CUT = 0.75
HEIGHT = 0.8
# The mouths sit 0.4925 arena widths below the top; the front panels fill the 0.07 band below.
MOUTH = ARENA_HEIGHT / 2 - 0.4925 * ARENA_WIDTH
BAND_SCALE = 0.07 * ARENA_WIDTH / HEIGHT
OPENINGS = [0.10, 0.20, 0.40]
COLOURS = {"orange": "#FD5D14", "blue": "#0055FA", "grey": "#AC9992"}
TRIM_MIX = 0.35


def linear(hex_color):
    def channel(value):
        value /= 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return (*[channel(int(hex_color[i : i + 2], 16)) for i in (1, 3, 5)], 1.0)


def lighter(hex_color):
    rgb = [int(hex_color[i : i + 2], 16) for i in (1, 3, 5)]
    mixed = [round(c + (255 - c) * TRIM_MIX) for c in rgb]
    return "#" + "".join(f"{c:02X}" for c in mixed)


def flat(name, hex_color):
    material = bpy.data.materials.new(name)
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = linear(hex_color)
    bsdf.inputs["Roughness"].default_value = 0.8
    return material


def bin_at(width, colour, location, height_scale):
    """Imports the GLB and places its three meshes for one opening, as the scene will."""
    bpy.ops.import_scene.gltf(filepath=str(GLB))
    meshes = {o.name.split(".")[0]: o for o in bpy.context.selected_objects if o.type == "MESH"}
    body, trim = flat("Body", COLOURS[colour]), flat("Trim", lighter(COLOURS[colour]))
    shift = (width - 2 * CUT) / 2
    for name, obj in meshes.items():
        obj.parent = None
        for slot in obj.material_slots:
            slot.material = body if slot.material.name.startswith("Body") else trim
        offset = {"BinLeft": -shift, "BinMiddle": 0.0, "BinRight": shift}[name]
        obj.location = location + Vector((offset, 0, 0))
        stretch = width / (2 * CUT) if name == "BinMiddle" else 1.0
        obj.scale = (stretch, 1.0, height_scale)
    for obj in [o for o in bpy.context.scene.objects if o.type == "EMPTY"]:
        bpy.data.objects.remove(obj)


def studio(background):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.6
    world = bpy.data.worlds.new("Review")
    scene.world = world
    node = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    node.inputs["Color"].default_value = background
    node.inputs["Strength"].default_value = 1.0
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


def render(path, width, height):
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def gameplay():
    """The three widths along the bottom of a cream wall, through the game camera."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    studio(linear("#F3E9D2"))
    distance = ARENA_WIDTH / 2 / math.tan(math.radians(FIELD_OF_VIEW) / 2)
    camera(Vector((0, -distance, 0)), Vector())
    widths = [o * ARENA_WIDTH for o in OPENINGS]
    gap = (ARENA_WIDTH - sum(w + 0.5 for w in widths)) / (len(widths) + 1)
    x = -ARENA_WIDTH / 2 + gap
    for width, colour in zip(widths, COLOURS):
        outer = width + 0.5
        bin_at(width, colour, Vector((x + outer / 2, 0, MOUTH)), BAND_SCALE)
        x += outer + gap
    render(OUTPUT / "bin-gameplay.png", 1920, 1080)


def three_quarter(name, placements):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    studio(linear("#C8C8C8"))
    for width, colour, location, height_scale in placements:
        bin_at(width, colour, location, height_scale)
    bpy.context.view_layer.update()
    points = [
        o.matrix_world @ Vector(c)
        for o in bpy.context.scene.objects
        if o.type == "MESH"
        for c in o.bound_box
    ]
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    middle = (low + high) / 2
    direction = Vector((0.35, -1, 0.6)).normalized()
    rotation = (-direction).to_track_quat("-Z", "Y")
    right, up = rotation @ Vector((1, 0, 0)), rotation @ Vector((0, 1, 0))
    across = max(p.dot(right) for p in points) - min(p.dot(right) for p in points)
    tall = max(p.dot(up) for p in points) - min(p.dot(up) for p in points)
    camera(middle + direction * 40, middle, max(across, tall * 16 / 9) * 1.1)
    render(OUTPUT / f"{name}.png", 1600, 900)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    gameplay()
    for opening in OPENINGS:
        width = opening * ARENA_WIDTH
        placements = []
        x = 0.0
        for colour in COLOURS:
            placements.append((width, colour, Vector((x, 0, 0)), BAND_SCALE))
            x += width + 1.5
        three_quarter(f"bin-width-{round(opening * 100):02d}", placements)
    width = 0.2 * ARENA_WIDTH
    placements = [
        (width, "orange", Vector((0, 0, 0)), 0.75),
        (width, "blue", Vector((width + 1.5, 0, 0)), 2.0),
    ]
    three_quarter("bin-height-075-and-2", placements)


main()
