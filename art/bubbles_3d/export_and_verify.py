"""Export the saved jellyfish or pufferfish source to a GLB and verify the round trip.

Usage: blender --background --factory-startup --python export_and_verify.py -- <model>

Checks the library parts against SHA256SUMS, exports only the model's asset collection,
imports the GLB into an empty scene and checks names, triangles, materials, origin and
orientation there. Writes <model>/export/verification.json and copies the GLB to the runtime
folder. It never saves over the source.
"""

import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

DIRECTORY = Path(__file__).resolve().parent
RUNTIME = DIRECTORY.parents[1] / "assets" / "runtime" / "minigames" / "bubbles_3d"
TOLERANCE = 0.001

MODELS = {
    "jellyfish": {
        "collection": "Jellyfish Asset",
        "meshes": ["Bell", "Tentacles", "Eyes"],
        "triangle_cap": 600,
        "materials": {
            "Bell": "#F48FB1",
            "Bell Rim": "#F8BBD0",
            "Tentacles": "#F07BA6",
            "Eyes": "#151515",
        },
        "origin_mesh": "Bell",
        "double_sided": [],
    },
    "pufferfish": {
        "collection": "Pufferfish Asset",
        "meshes": ["Body", "Fins", "Face"],
        "triangle_cap": 700,
        "materials": {
            "Body": "#FF9800",
            "Spike Tips": "#FFB74D",
            "Fins": "#FF5722",
            "Eye White": "#FAFAFA",
            "Pupil": "#151515",
            "Cheeks": "#F48FB1",
            "Mouth": "#EF5A5A",
        },
        "origin_mesh": "Body",
        # The fins are single sheets cut from the fish.
        "double_sided": ["Fins"],
    },
}


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


def check_library_parts(name):
    hashes = {}
    for line in (DIRECTORY / "SHA256SUMS").read_text().splitlines():
        expected, relative = line.split("  ", 1)
        if relative.startswith(f"{name}/"):
            actual = sha256(DIRECTORY / relative)
            require(actual == expected, f"Library part changed: {relative}")
            hashes[relative] = actual
    require(hashes, f"No library parts listed for {name}")
    return hashes


def glb_materials(path):
    """Material name to doubleSided, read from the GLB's JSON chunk."""
    data = path.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20 : 20 + length])
    return {m["name"]: m.get("doubleSided", False) for m in document["materials"]}


def bounds(objects):
    points = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    low = Vector([min(p[i] for p in points) for i in range(3)])
    high = Vector([max(p[i] for p in points) for i in range(3)])
    return low, high


def gltf_bounds(low, high):
    """Blender Z-up bounds as glTF Y-up minimum and maximum; Blender +Y is glTF -Z."""
    minimum = [low.x, low.z, -high.y]
    maximum = [high.x, high.z, -low.y]
    return [round(v, 5) for v in minimum], [round(v, 5) for v in maximum]


def export(name, spec):
    source = DIRECTORY / name / f"{name}.blend"
    bpy.ops.wm.open_mainfile(filepath=str(source))
    collection = bpy.data.collections.get(spec["collection"])
    require(collection is not None, f"Missing collection {spec['collection']}")
    objects = list(collection.objects)
    require(
        sorted(o.name for o in objects) == sorted(spec["meshes"]),
        f"Asset collection must hold exactly {spec['meshes']}",
    )
    for obj in objects:
        require(obj.type == "MESH", f"{obj.name} must be a mesh")
        require(obj.parent is None, f"{obj.name} must not be parented")
        require(obj.matrix_world.is_identity, f"{obj.name} must have applied transforms")
        require(not obj.modifiers, f"{obj.name} must have no modifiers")
        require(
            "custom_normal" not in obj.data.attributes,
            f"{obj.name} must not carry normals inherited from a library source",
        )
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        if all(edge.is_manifold for edge in bm.edges):
            require(bm.calc_volume(signed=True) > 0, f"{obj.name} is inside out")
        bm.free()

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    target = DIRECTORY / name / "export" / f"{name}.glb"
    target.parent.mkdir(exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(target),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_texcoords=False,
    )
    return source, target


def verify(name, spec, target):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(target))
    meshes = {o.name: o for o in bpy.context.scene.objects if o.type == "MESH"}
    require(
        sorted(meshes) == sorted(spec["meshes"]),
        f"GLB meshes {sorted(meshes)} != {spec['meshes']}",
    )
    require(
        all(o.type == "MESH" for o in bpy.context.scene.objects),
        "GLB holds only meshes",
    )

    triangles = {}
    for obj in meshes.values():
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles[obj.name] = len(mesh.loop_triangles)
        require(
            all(t.area > 1e-10 for t in mesh.loop_triangles),
            f"Degenerate triangle in {obj.name}",
        )
    total = sum(triangles.values())
    require(total <= spec["triangle_cap"], f"{total} triangles exceed {spec['triangle_cap']}")

    materials = {}
    for obj in meshes.values():
        for slot in obj.material_slots:
            node = slot.material.node_tree.nodes.get("Principled BSDF")
            color = list(node.inputs["Base Color"].default_value)[:3]
            materials[slot.material.name] = color
    require(
        sorted(materials) == sorted(spec["materials"]),
        f"Materials {sorted(materials)} != {sorted(spec['materials'])}",
    )
    for material, hex_color in spec["materials"].items():
        expected = linear(hex_color)
        close = all(abs(a - b) < TOLERANCE for a, b in zip(materials[material], expected))
        require(close, f"{material} is not {hex_color}")

    sided = glb_materials(target)
    double = sorted(name for name, value in sided.items() if value)
    require(double == sorted(spec["double_sided"]), f"Double-sided materials are {double}")

    low, high = bounds([meshes[spec["origin_mesh"]]])
    centre = (low + high) / 2
    require(centre.length < TOLERANCE, f"Origin is not at the {spec['origin_mesh']} centre")

    per_mesh = {}
    for mesh_name, obj in meshes.items():
        minimum, maximum = gltf_bounds(*bounds([obj]))
        per_mesh[mesh_name] = {
            "minimum": minimum,
            "maximum": maximum,
            "triangles": triangles[mesh_name],
        }
    globals()[f"check_{name}"](meshes, per_mesh)

    minimum, maximum = gltf_bounds(*bounds(meshes.values()))
    return {
        "triangles": total,
        "triangles_by_mesh": triangles,
        "materials": spec["materials"],
        "bounds_gltf": {"minimum": minimum, "maximum": maximum},
        "meshes_gltf": per_mesh,
    }


def check_jellyfish(meshes, per_mesh):
    # glTF -Z is the front; Y is up.
    eyes, bell, tentacles = per_mesh["Eyes"], per_mesh["Bell"], per_mesh["Tentacles"]
    require(eyes["maximum"][2] < 0, "Eyes are on the -Z front of the bell")
    bell_tree = tree(meshes["Bell"])
    for part in islands(meshes["Eyes"]):
        require(any(touches(bell_tree, q) for q in part), "Each eye sits on the bell")
    require(tentacles["minimum"][1] < bell["minimum"][1] - 0.15, "Tentacles hang below")
    require(tentacles["maximum"][1] > bell["minimum"][1], "Tentacles start under the bell")
    width = bell["maximum"][0] - bell["minimum"][0]
    height = bell["maximum"][1] - bell["minimum"][1]
    require(abs(height / width - 0.7) < 0.02, "Bell height is 0.7 of its width")


def check_pufferfish(meshes, per_mesh):
    # +X is the front; Y is up.
    face, body, fins = per_mesh["Face"], per_mesh["Body"], per_mesh["Fins"]
    require(face["minimum"][0] > 0, "The face is on the +X front")
    require(fins["minimum"][0] < body["minimum"][0], "The tail fin extends behind the body")
    body_tree = tree(meshes["Body"])
    parts = islands(meshes["Fins"]) + islands(meshes["Face"])
    attached = [p for p in parts if any(touches(body_tree, q) for q in p)]
    # A pupil sits on its eye rather than on the body: it must sink into an attached part.
    for part in parts:
        if part in attached:
            continue
        inside = any(any(within(q, other) for q in part) for other in attached)
        require(inside, "Every fin and face part touches the body or sinks into a part that does")


def touches(surface, point):
    """True when the point lies inside the closed surface or within 0.02 of it."""
    location, normal, _index, distance = surface.find_nearest(point)
    return distance < 0.02 or (point - location).dot(normal) < 0


def within(point, part):
    low = Vector([min(q[i] for q in part) for i in range(3)])
    high = Vector([max(q[i] for q in part) for i in range(3)])
    return all(low[i] <= point[i] <= high[i] for i in range(3))


def tree(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.transform(obj.matrix_world)
    result = BVHTree.FromBMesh(bm)
    bm.free()
    return result


def islands(obj):
    """World positions of each connected part of a mesh."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    seen = set()
    parts = []
    for start in bm.verts:
        if start.index in seen:
            continue
        stack = [start]
        part = []
        seen.add(start.index)
        while stack:
            vertex = stack.pop()
            part.append(obj.matrix_world @ vertex.co)
            for edge in vertex.link_edges:
                other = edge.other_vert(vertex)
                if other.index not in seen:
                    seen.add(other.index)
                    stack.append(other)
        parts.append(part)
    bm.free()
    return parts


def main():
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    require(len(arguments) == 1 and arguments[0] in MODELS, f"Name one of {list(MODELS)}")
    name = arguments[0]
    spec = MODELS[name]

    library = check_library_parts(name)
    source, target = export(name, spec)
    report = {
        "result": "PASS",
        "blender_version": bpy.app.version_string,
        "library_sha256": library,
        "source_sha256": sha256(source),
        "export_sha256": sha256(target),
        "export_bytes": target.stat().st_size,
    }
    report.update(verify(name, spec, target))

    runtime = RUNTIME / name / target.name
    runtime.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(target, runtime)
    report_path = DIRECTORY / name / "export" / "verification.json"
    report_path.write_text(json.dumps(report, indent=2) + "\n", newline="\n")
    print(f"{name}: PASS, {report['triangles']} triangles")


main()
