"""Export the saved cafe table and check source preservation and its GLB round trip."""

import hashlib
import json
from pathlib import Path
import struct

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector


DIRECTORY = Path(__file__).resolve().parent
SOURCE = DIRECTORY / "cafe-table.blend"
EXPORT = DIRECTORY / "export" / "cafe-table.glb"
REPORT = DIRECTORY / "export" / "verification.json"
TOLERANCE = 0.0001


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def geometry(objects):
    points = []
    triangles = 0
    per_object = {}
    graph = bpy.context.evaluated_depsgraph_get()

    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        vertices = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
        points.extend(vertices)
        count = len(mesh.loop_triangles)
        triangles += count
        per_object[obj.name] = count

        bm = bmesh.new()
        bm.from_mesh(mesh)
        # glTF splits vertices at normals and material seams; weld before topology checks.
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
        closed = all(edge.is_manifold for edge in bm.edges)
        require(closed, f"Open mesh: {obj.name}")
        require(all(face.calc_area() > 1e-10 for face in bm.faces), f"Zero area: {obj.name}")
        positive = bm.calc_volume(signed=True) > 0
        require(positive, f"Inverted mesh: {obj.name}")
        bm.free()
        evaluated.to_mesh_clear()

    return {
        "minimum": [min(point[axis] for point in points) for axis in range(3)],
        "maximum": [max(point[axis] for point in points) for axis in range(3)],
        "triangles": triangles,
        "mesh_count": len(objects),
        "triangles_by_object": per_object,
    }


def material_values(objects):
    values = {}
    for obj in objects:
        for slot in obj.material_slots:
            material = slot.material
            require(material is not None, f"Missing material: {obj.name}")
            node = material.node_tree.nodes.get("Principled BSDF")
            require(node is not None, f"Missing principled shader: {material.name}")
            values[material.name] = {
                "color": list(node.inputs["Base Color"].default_value),
                "roughness": node.inputs["Roughness"].default_value,
                "metallic": node.inputs["Metallic"].default_value,
            }
    return values


def close(actual, expected, message):
    require(len(actual) == len(expected), message)
    require(all(abs(a - b) < TOLERANCE for a, b in zip(actual, expected)), message)


def original_geometry():
    hashes = {
        "Table_RoundSmall.obj": "7e95bb32fe64438ff90e4f25407acf86ebd6173405da99fe0c150b9121bdbece",
        "Table_RoundSmall.mtl": "f9cf420bec3be1dcebf8294fb1fa28fecd75a5c61069c77b898136ebe4efe060",
    }
    for name, expected in hashes.items():
        data = (DIRECTORY / "source" / name).read_bytes()
        require(hashlib.sha256(data).hexdigest() == expected, f"Original hash changed: {name}")
    lines = (DIRECTORY / "source" / "Table_RoundSmall.obj").read_text().splitlines()
    require([line for line in lines if line.startswith("mtllib ")]
            == ["mtllib Table_RoundSmall.mtl"], "Unexpected OBJ dependency")
    mtl = (DIRECTORY / "source" / "Table_RoundSmall.mtl").read_text()
    require(not any(line.strip().startswith("map_") for line in mtl.splitlines()),
            "Unexpected source texture dependency")
    points = [tuple(map(float, line.split()[1:])) for line in lines if line.startswith("v ")]
    top = [p for p in points if p[0] ** 2 + p[2] ** 2 > .9 ** 2]
    support = [p for p in points if p not in top]
    width = max(p[0] for p in top) - min(p[0] for p in top)
    scale = 4.25 / width
    ground = min(p[1] for p in points)
    height = (max(p[1] for p in top) - ground) * scale
    extension = 3 - height
    require(extension > 0, "Pedestal must be taller than normalized original")
    expected = {}
    for name, vertices in (("Tabletop", top), ("Pedestal and Base", support)):
        expected[name] = [Vector((x * scale, -z * scale,
                                 (y - ground) * scale
                                 + (extension if name == "Tabletop" or y >= .320398 else 0)))
                          for x, y, z in vertices]
    require(len(top) == 120 and len(support) == 180, "Source components changed")
    return expected, {
        "original_hashes": hashes, "uniform_scale": scale,
        "normalized_original_height": height, "pedestal_extension": extension,
        "tabletop_thickness": (max(p[1] for p in top) - min(p[1] for p in top)) * scale,
        "extended_original_ring_heights": [.247605, .320399],
        "preservation": "All vertices match the uniformly normalized original; only the upper "
                        "pedestal and complete tabletop are translated upward",
    }


def check_preservation(objects, expected):
    for obj in objects:
        graph = bpy.context.evaluated_depsgraph_get()
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        points = [evaluated.matrix_world @ v.co for v in mesh.vertices]
        wanted = expected[obj.name]
        require(all(any((a - b).length < .00001 for b in wanted) for a in points),
                f"Shape changed: {obj.name}")
        require(all(any((a - b).length < .00001 for b in points) for a in wanted),
                f"Original vertices missing: {obj.name}")
        evaluated.to_mesh_clear()


def check_top(obj, thickness):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lower = min(p.z for p in points)
    upper = max(p.z for p in points)
    close([upper, upper - lower], [3, thickness], "Tabletop height/thickness changed")
    caps = [face for face in obj.data.polygons
            if all(abs(points[i].z - 3) < TOLERANCE for i in face.vertices)]
    require(caps, "Flat tabletop cap missing")
    area = sum(face.area for face in caps)
    require(area > 13, "Broad flat tabletop area changed")
    require(all(face.normal.z > .999 for face in caps), "Tabletop cap must face upward")
    return area


def gltf_bounds(document, binary):
    buffer_start = 28 + struct.unpack_from("<I", binary, 12)[0]
    points = []

    def visit(index, parent):
        node = document["nodes"][index]
        if "matrix" in node:
            values = node["matrix"]
            local = Matrix([values[i:i + 4] for i in range(0, 16, 4)]).transposed()
        else:
            x, y, z, w = node.get("rotation", [0, 0, 0, 1])
            local = Matrix.LocRotScale(Vector(node.get("translation", [0, 0, 0])),
                                       Quaternion((w, x, y, z)),
                                       Vector(node.get("scale", [1, 1, 1])))
        transform = parent @ local
        if "mesh" in node:
            for primitive in document["meshes"][node["mesh"]]["primitives"]:
                require(primitive.get("mode", 4) == 4, "Expected triangle primitives")
                accessor = document["accessors"][primitive["attributes"]["POSITION"]]
                require(accessor["componentType"] == 5126 and accessor["type"] == "VEC3",
                        "Unexpected position encoding")
                view = document["bufferViews"][accessor["bufferView"]]
                start = buffer_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
                stride = view.get("byteStride", 12)
                for i in range(accessor["count"]):
                    points.append(transform @ Vector(struct.unpack_from("<3f", binary,
                                                                        start + i * stride)))
        for child in node.get("children", []):
            visit(child, transform)

    for index in document["scenes"][document.get("scene", 0)]["nodes"]:
        visit(index, Matrix.Identity(4))
    bounds = {"minimum": [min(p[i] for p in points) for i in range(3)],
              "maximum": [max(p[i] for p in points) for i in range(3)]}
    close(bounds["minimum"], [-2.125, 0, -2.125], "GLB minimum bounds changed")
    close(bounds["maximum"], [2.125, 3, 2.125], "GLB maximum bounds changed")
    return bounds


def main():
    expected, adaptation = original_geometry()
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    collection = bpy.data.collections["Cafe Table Asset"]
    meshes = [obj for obj in collection.objects if obj.type == "MESH"]
    names = {"Tabletop", "Pedestal and Base"}
    require({obj.name for obj in meshes} == names, "Named parts changed")
    root = collection.objects["CafeTable"]
    close(root.location, [0, 0, 0], "Root must be at ground center")
    close(root.scale, [1, 1, 1], "Root scale must be applied")
    close(root.rotation_euler, [0, 0, 0], "Root rotation must be applied")
    require(all(obj.parent == root for obj in meshes), "Parts must share CafeTable root")
    require(not bpy.data.libraries, "Source contains linked libraries")
    require(not [im for im in bpy.data.images if im.source == "FILE"],
            "Source contains external image dependencies")
    for obj in meshes:
        close(obj.scale, [1, 1, 1], f"Unapplied scale: {obj.name}")
        close(obj.rotation_euler, [0, 0, 0], f"Unapplied rotation: {obj.name}")
        require(not obj.modifiers, f"Unexpected geometry modifier: {obj.name}")
    check_preservation(meshes, expected)
    area = check_top(collection.objects["Tabletop"], adaptation["tabletop_thickness"])
    source_geometry = geometry(meshes)
    require(source_geometry["triangles_by_object"]
            == {"Tabletop": 236, "Pedestal and Base": 356}, "Source triangle budget changed")
    require(abs(source_geometry["minimum"][2]) < TOLERANCE, "Base must sit on ground")
    materials = material_values(meshes)
    require(set(materials) == {"Tabletop Golden Yellow", "Pedestal Charcoal"},
            "Expected two independent materials")
    for obj in meshes:
        require(len(obj.material_slots) == 1, f"Unexpected material slots: {obj.name}")
    for name, color in (("Tabletop Golden Yellow", "F4B940"), ("Pedestal Charcoal", "30333B")):
        srgb = [int(color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
        linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb]
        close(materials[name]["color"], linear + [1], f"Approved color changed: {name}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    EXPORT.parent.mkdir(exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_animations=False,
        export_cameras=False, export_lights=False, export_extras=False,
        export_materials="EXPORT",
    )
    binary = EXPORT.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", binary)
    require(magic == b"glTF" and version == 2 and length == len(binary), "Invalid GLB header")
    json_length, kind = struct.unpack_from("<II", binary, 12)
    require(kind == 0x4E4F534A, "GLB JSON missing")
    document = json.loads(binary[20:20 + json_length])
    require(not document.get("images") and not document.get("textures"),
            "Unexpected texture dependencies")
    require(all("uri" not in buffer for buffer in document["buffers"]), "External buffer")
    require(not document.get("cameras") and not document.get("animations")
            and not document.get("extensionsUsed"), "Unexpected export features")
    require({node["name"] for node in document["nodes"]} == names | {"CafeTable"},
            "Review objects leaked into export")
    surfaces = sum(len(mesh["primitives"]) for mesh in document["meshes"])
    require(surfaces == 2 and len(document["materials"]) == 2, "Export surface budget changed")
    bounds = gltf_bounds(document, binary)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT))
    imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    require({obj.name for obj in imported} == names, "Round-trip mesh names changed")
    check_preservation(imported, expected)
    round_area = check_top(bpy.data.objects["Tabletop"], adaptation["tabletop_thickness"])
    require(abs(round_area - area) < TOLERANCE, "Round-trip flat top area changed")
    round_geometry = geometry(imported)
    require(round_geometry["triangles_by_object"] == source_geometry["triangles_by_object"],
            "Round-trip triangle count changed")
    for key in ("minimum", "maximum"):
        close(round_geometry[key], source_geometry[key], f"Round-trip {key} bounds changed")
    actual_materials = material_values(imported)
    require(set(actual_materials) == set(materials), "Round-trip material names changed")
    for name, values in materials.items():
        close(actual_materials[name]["color"], values["color"], f"Color changed: {name}")
        for key in ("roughness", "metallic"):
            require(abs(actual_materials[name][key] - values[key]) < TOLERANCE,
                    f"Round-trip {key} changed: {name}")

    report = {
        "result": "PASS", "blender_version": bpy.app.version_string,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "export_sha256": hashlib.sha256(binary).hexdigest(), "export_bytes": len(binary),
        "adaptation": adaptation, "source_geometry_blender_xyz": source_geometry,
        "round_trip_geometry_blender_xyz": round_geometry, "materials": materials,
        "flat_top_area": area, "gltf_world_bounds_xyz": bounds,
        "exported_mesh_surfaces": surfaces, "gltf_orientation": "Y up; ground-centered origin",
        "evidence": "AUTO: Blender source and GLB round trip; no Godot import/runtime evidence",
        "checks": ["approved OBJ/MTL hashes", "closed positive-volume geometry",
                   "no degenerate faces", "all original vertices preserved after normalization",
                   "only straight pedestal collar extended", "tabletop and base shapes preserved",
                   "flat broad top at height 3 with original normalized thickness",
                   "grounded base", "applied transforms", "two materials and mesh surfaces",
                   "approved golden-yellow and charcoal colors", "no external dependencies",
                   "no review objects in export", "decoded GLB bounds and Y-up orientation",
                   "round-trip geometry preservation, names, bounds, triangles and materials"],
        "license_status": "Pack-specific license evidence unresolved; publication pending",
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {len(meshes)} meshes, {source_geometry['triangles']} triangles, "
          f"{len(materials)} materials, {surfaces} surfaces, {len(binary)} GLB bytes")


if __name__ == "__main__":
    main()
