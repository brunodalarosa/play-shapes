"""Export the saved bin source to a GLB and verify the round trip.

Usage: blender --background --factory-startup --python export_and_verify.py

Checks the crate copies against SHA256SUMS, exports only the bin's asset collection, imports
the GLB into an empty scene and checks names, triangles, materials, the origin, the cut and
assembly at every width and height the scene may ask for. Writes bin/export/verification.json
and copies the GLB and the crate's license to the runtime folder. It never saves over the
source.
"""

import hashlib
import json
from pathlib import Path
import shutil

import bpy
from mathutils import Vector

DIRECTORY = Path(__file__).resolve().parent
SOURCE = DIRECTORY / "bin" / "bin.blend"
TARGET = DIRECTORY / "bin" / "export" / "bin.glb"
RUNTIME = DIRECTORY.parents[1] / "assets" / "runtime" / "minigames" / "tilt_shift_3d" / "crate"
COLLECTION = "Bin Asset"
MESHES = ["BinLeft", "BinMiddle", "BinRight"]
MATERIALS = {"Body": "#FD5D14", "Trim": "#FE9666"}
TRIANGLE_CAP = 300
TOLERANCE = 0.0005
# Native measurements in glTF axes: X across the opening, Y up, Z depth with the front at -Z.
CUT = 0.75
OUTER = 1.0
DEPTH = 2.0
HEIGHT = 0.8
# The 19.2-unit arena's opening widths the scene may ask for, and its height scales.
ARENA_WIDTH = 19.2
OPENINGS = [0.10, 0.20, 0.30, 0.40]
HEIGHT_SCALES = [0.75, 1.0, 2.0]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def linear(hex_color):
    def channel(value):
        value /= 255
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return [channel(int(hex_color[i : i + 2], 16)) for i in (1, 3, 5)]


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_library_copies():
    hashes = {}
    for line in (DIRECTORY / "SHA256SUMS").read_text().splitlines():
        expected, relative = line.split("  ", 1)
        actual = sha256(DIRECTORY / relative)
        require(actual == expected, f"Library copy changed: {relative}")
        hashes[relative] = actual
    require(len(hashes) == 4, "SHA256SUMS lists the crate's four files")
    return hashes


def export():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    collection = bpy.data.collections.get(COLLECTION)
    require(collection is not None, f"Missing collection {COLLECTION}")
    objects = list(collection.objects)
    require(sorted(o.name for o in objects) == MESHES, f"{COLLECTION} must hold {MESHES}")
    for obj in objects:
        require(obj.type == "MESH", f"{obj.name} must be a mesh")
        require(obj.parent is None, f"{obj.name} must not be parented")
        require(obj.matrix_world.is_identity, f"{obj.name} must have applied transforms")
        require(not obj.modifiers, f"{obj.name} must have no modifiers")
        require(
            "custom_normal" not in obj.data.attributes,
            f"{obj.name} must not carry normals inherited from the crate",
        )

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    TARGET.parent.mkdir(exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(TARGET),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_texcoords=False,
    )


def gltf_points(obj):
    """World vertex positions in glTF axes: Blender (x, y, z) is glTF (x, z, -y)."""
    points = []
    for vertex in obj.data.vertices:
        p = obj.matrix_world @ vertex.co
        points.append(Vector((p.x, p.z, -p.y)))
    return points


def bounds(points):
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    return low, high


def close(a, b):
    return abs(a - b) < TOLERANCE


def verify():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(TARGET))
    meshes = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
    require(sorted(meshes) == MESHES, f"GLB meshes {sorted(meshes)} != {MESHES}")
    require(all(o.type == "MESH" for o in bpy.context.scene.objects), "GLB holds only meshes")

    triangles = {}
    for obj in meshes.values():
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles[obj.name] = len(mesh.loop_triangles)
        require(all(t.area > 1e-8 for t in mesh.loop_triangles), f"Degenerate in {obj.name}")
    total = sum(triangles.values())
    require(total <= TRIANGLE_CAP, f"{total} triangles exceed {TRIANGLE_CAP}")

    for obj in meshes.values():
        names = sorted(slot.material.name for slot in obj.material_slots)
        require(names == sorted(MATERIALS), f"{obj.name} uses {names}, not Body and Trim")
        for slot in obj.material_slots:
            node = next(n for n in slot.material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            color = list(node.inputs["Base Color"].default_value)[:3]
            expected = linear(MATERIALS[slot.material.name])
            same = all(abs(a - b) < 0.001 for a, b in zip(color, expected))
            require(same, f"{slot.material.name} is not {MATERIALS[slot.material.name]}")
            require(not node.inputs["Base Color"].is_linked, "Materials must be flat colours")

    points = {name: gltf_points(obj) for name, obj in meshes.items()}
    low, high = bounds([p for part in points.values() for p in part])
    require(close(high.y, 0.0), "The origin is on the top rim line")
    require(close(low.y, -HEIGHT), f"The bin is {HEIGHT} tall")
    require(close(low.z, -DEPTH / 2) and close(high.z, DEPTH / 2), "Depth is centred")
    require(close(low.x, -OUTER) and close(high.x, OUTER), "The crate keeps its width")

    # The middle is a straight extrusion between the cut planes, so stretching it along X
    # changes no slope, normal or proportion.
    require(all(close(abs(p.x), CUT) for p in points["BinMiddle"]), "Middle verts on cuts")
    left_low, left_high = bounds(points["BinLeft"])
    right_low, right_high = bounds(points["BinRight"])
    require(close(left_low.x, -OUTER) and close(left_high.x, -CUT), "BinLeft spans its end")
    require(close(right_low.x, CUT) and close(right_high.x, OUTER), "BinRight spans its end")
    mirrored = [-left_high.x, left_low.y, left_low.z, -left_low.x, left_high.y, left_high.z]
    theirs = [*right_low, *right_high]
    require(all(close(a, b) for a, b in zip(mirrored, theirs)), "The ends mirror each other")
    # The side boards' inner faces lie on the cut planes, facing the mouth, from the floor's
    # depth to the top: the inner mouth is exactly the middle's width.
    for name, sign in (("BinLeft", -1), ("BinRight", 1)):
        area = 0.0
        for polygon in meshes[name].data.polygons:
            facing = close(polygon.normal.x, -sign) and close(polygon.center.x, sign * CUT)
            area += polygon.area if facing else 0.0
        require(close(area, (2 * CUT) * HEIGHT), f"{name}'s side board faces the mouth")

    assemblies = []
    for opening in OPENINGS:
        width = opening * ARENA_WIDTH
        for scale in HEIGHT_SCALES:
            assemblies.append(assemble(points, width, scale))

    per_mesh = {}
    for name, part in points.items():
        part_low, part_high = bounds(part)
        per_mesh[name] = {
            "minimum": [round(v, 5) for v in part_low],
            "maximum": [round(v, 5) for v in part_high],
            "triangles": triangles[name],
        }
    return {
        "triangles": total,
        "triangles_by_mesh": triangles,
        "materials": MATERIALS,
        "bounds_gltf": {
            "minimum": [round(v, 5) for v in low],
            "maximum": [round(v, 5) for v in high],
        },
        "meshes_gltf": per_mesh,
        "assemblies": assemblies,
    }


def assemble(points, width, height_scale):
    """Places the pieces as the scene will for one opening and checks the result."""
    shift = (width - 2 * CUT) / 2
    stretch = width / (2 * CUT)
    placed = {
        "BinLeft": [Vector((p.x - shift, p.y * height_scale, p.z)) for p in points["BinLeft"]],
        "BinMiddle": [
            Vector((p.x * stretch, p.y * height_scale, p.z)) for p in points["BinMiddle"]
        ],
        "BinRight": [Vector((p.x + shift, p.y * height_scale, p.z)) for p in points["BinRight"]],
    }
    left_low, left_high = bounds(placed["BinLeft"])
    middle_low, middle_high = bounds(placed["BinMiddle"])
    right_low, right_high = bounds(placed["BinRight"])
    require(close(middle_high.x - middle_low.x, width), "The middle fills the opening")
    require(close(left_high.x, middle_low.x), "The left end meets the middle")
    require(close(right_low.x, middle_high.x), "The right end meets the middle")
    require(close(right_low.x - left_high.x, width), "The inner mouth equals the opening")
    require(close(left_high.x - left_low.x, OUTER - CUT), "The ends keep their width")
    require(close(left_low.y, -HEIGHT * height_scale), "Height follows its scale")
    return {
        "opening_arena_widths": round(width / ARENA_WIDTH, 3),
        "inner_mouth": round(right_low.x - left_high.x, 5),
        "outer_width": round(right_high.x - left_low.x, 5),
        "height": round(-left_low.y, 5),
        "middle_stretch": round(stretch, 5),
        "end_shift": round(shift, 5),
    }


def main():
    library = check_library_copies()
    export()
    report = {
        "result": "PASS",
        "blender_version": bpy.app.version_string,
        "library_sha256": library,
        "source_sha256": sha256(SOURCE),
        "export_sha256": sha256(TARGET),
        "export_bytes": TARGET.stat().st_size,
    }
    report.update(verify())

    RUNTIME.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(TARGET, RUNTIME / TARGET.name)
    shutil.copyfile(DIRECTORY / "crate" / "License.txt", RUNTIME / "License.txt")
    report_path = TARGET.parent / "verification.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", newline="\n")
    print(f"bin: PASS, {report['triangles']} triangles")


main()
