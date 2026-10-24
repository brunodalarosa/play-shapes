"""Render the saved source or exported GLB using the same review studio."""

from pathlib import Path
import sys

import bpy
from mathutils import Vector


DIRECTORY = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(DIRECTORY / "billboard.blend"))
scene = bpy.context.scene
arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
exported = "--exported" in arguments
if exported:
    for obj in list(bpy.data.collections["Billboard Asset"].objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(DIRECTORY / "export" / "billboard.glb"))

directory = DIRECTORY / "review"
directory.mkdir(exist_ok=True)
views = {
    "near-frontal": ((0, 24, 10), 17),
    "three-quarter": ((-14, 22, 12), 18),
    "rear": ((0, -24, 10), 17),
    "side": ((-24, 0, 10), 19),
}
if exported:
    views = {"export-near-frontal": views["near-frontal"]}

for name, (position, scale) in views.items():
    camera = scene.camera
    camera.location = position
    camera.rotation_euler = (
        Vector((0, 0, 5.7)) - camera.location
    ).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = scale
    scene.render.filepath = str(directory / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED {name}")
