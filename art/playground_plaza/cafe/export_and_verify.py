"""Export the saved cafe collection and check its GLB round trip in a disposable process."""

import hashlib
import json
from pathlib import Path
import struct

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector


DIRECTORY = Path(__file__).resolve().parent
SOURCE = DIRECTORY / "cafe.blend"
EXPORT = DIRECTORY / "export" / "cafe.glb"
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
        require(all(edge.is_manifold for edge in bm.edges), f"Open mesh: {obj.name}")
        require(all(face.calc_area() > 1e-10 for face in bm.faces), f"Zero area: {obj.name}")
        require(bm.calc_volume(signed=True) > 0, f"Inverted mesh: {obj.name}")
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


def gltf_bounds(document, binary):
    json_length = struct.unpack_from("<I", binary, 12)[0]
    buffer_start = 20 + json_length + 8
    points = []
    front_points = []

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
                accessor = document["accessors"][primitive["attributes"]["POSITION"]]
                require(accessor["componentType"] == 5126 and accessor["type"] == "VEC3",
                        "Unexpected position encoding")
                view = document["bufferViews"][accessor["bufferView"]]
                start = buffer_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
                for vertex in range(accessor["count"]):
                    offset = start + vertex * view.get("byteStride", 12)
                    point = transform @ Vector(struct.unpack_from("<3f", binary, offset))
                    points.append(point)
                    if node.get("name") == "Cup Emblem":
                        front_points.append(point)
        for child in node.get("children", []):
            visit(child, transform)

    for index in document["scenes"][document.get("scene", 0)]["nodes"]:
        visit(index, Matrix.Identity(4))
    bounds = {
        "minimum": [min(point[axis] for point in points) for axis in range(3)],
        "maximum": [max(point[axis] for point in points) for axis in range(3)],
    }
    for key, expected in (("minimum", [-3.5, 0, -2]), ("maximum", [3.5, 6.5, 2])):
        require(all(abs(a - b) < TOLERANCE for a, b in zip(bounds[key], expected)),
                f"GLB world bounds changed: {key}")
    require(front_points and all(point.z < -1.6 for point in front_points),
            "GLB facade must face -Z")
    return bounds


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    collection = bpy.data.collections["Cafe Asset"]
    meshes = [obj for obj in collection.objects if obj.type == "MESH"]
    root = collection.objects["Cafe"]
    require(root.location.length < TOLERANCE, "Root must be at ground center")
    require(not bpy.data.libraries, "Source contains linked libraries")
    require(not [image for image in bpy.data.images if image.source == "FILE"],
            "Source unexpectedly depends on image files")
    require(all(obj.parent == root for obj in meshes), "Asset parts must share the Cafe root")
    require(all((obj.scale - Vector((1, 1, 1))).length < TOLERANCE for obj in meshes),
            "Mesh scales must be applied")
    source_geometry = geometry(meshes)
    materials = material_values(meshes)
    require(source_geometry["triangles"] < 3000, "Triangle budget exceeded")
    require(len(materials) <= 8, "Material budget exceeded")
    require(abs(source_geometry["minimum"][2]) < TOLERANCE, "Base is not on the ground")
    require(abs(source_geometry["maximum"][2] - 6.5) < TOLERANCE, "Roof height changed")

    roof = collection.objects["Roof"]
    evaluated = roof.evaluated_get(bpy.context.evaluated_depsgraph_get())
    roof_mesh = evaluated.to_mesh()
    top = [evaluated.matrix_world @ vertex.co for vertex in roof_mesh.vertices
           if abs((evaluated.matrix_world @ vertex.co).z - 6.5) < TOLERANCE]
    require(len(top) >= 4, "Flat roof top missing")
    roof_width = max(point.x for point in top) - min(point.x for point in top)
    roof_depth = max(point.y for point in top) - min(point.y for point in top)
    require(roof_width > 6.8 and roof_depth > 3.8, "Unobstructed roof area too small")
    evaluated.to_mesh_clear()
    for obj in meshes:
        if obj != roof:
            require(max((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box) < 6.1,
                    f"Part obstructs roof: {obj.name}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), export_format="GLB", use_selection=True,
        export_yup=True, export_apply=True, export_animations=False,
        export_cameras=False, export_lights=False, export_extras=False,
        export_materials="EXPORT",
    )

    binary = EXPORT.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", binary)
    require(magic == b"glTF" and version == 2 and length == len(binary), "Invalid GLB header")
    json_length, json_kind = struct.unpack_from("<II", binary, 12)
    require(json_kind == 0x4E4F534A, "Missing GLB JSON chunk")
    document = json.loads(binary[20:20 + json_length])
    require(not document.get("images") and not document.get("textures"),
            "Unexpected image dependencies")
    require(all("uri" not in buffer for buffer in document["buffers"]),
            "External buffer dependency")
    require(not document.get("animations") and not document.get("cameras"),
            "Review objects leaked into export")
    require(len(document["materials"]) == len(materials), "Exported material count changed")
    exported_bounds = gltf_bounds(document, binary)

    source_names = {obj.name for obj in meshes}
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT))
    imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    require({obj.name for obj in imported} == source_names, "Round-trip part names changed")
    round_trip = geometry(imported)
    for key in ("minimum", "maximum"):
        require(all(abs(a - b) < TOLERANCE
                    for a, b in zip(source_geometry[key], round_trip[key])),
                f"Round-trip bounds changed: {key}")
    require(source_geometry["triangles"] == round_trip["triangles"],
            "Round-trip triangle count changed")
    imported_materials = material_values(imported)
    require(set(materials) == set(imported_materials), "Round-trip material names changed")
    for name, values in materials.items():
        actual = imported_materials[name]
        require(all(abs(a - b) < TOLERANCE for a, b in zip(values["color"], actual["color"])),
                f"Round-trip color changed: {name}")
        for key in ("roughness", "metallic"):
            require(abs(values[key] - actual[key]) < TOLERANCE,
                    f"Round-trip {key} changed: {name}")

    report = {
        "result": "PASS", "blender_version": bpy.app.version_string,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "export_sha256": hashlib.sha256(binary).hexdigest(),
        "export_bytes": len(binary), "source_geometry_blender_xyz": source_geometry,
        "round_trip_geometry_blender_xyz": round_trip, "materials": materials,
        "gltf_world_bounds_xyz": exported_bounds,
        "flat_roof_size": [roof_width, roof_depth],
        "gltf_orientation": "Y up; facade -Z; ground-centered origin",
        "evidence": "AUTO: Blender source and GLB round trip; no Godot import/runtime evidence",
        "checks": ["closed positive-volume parts", "no degenerate faces", "triangle budget",
                   "material budget", "flat unobstructed roof", "applied mesh scales",
                   "ground origin", "no external dependencies", "no studio objects in export",
                   "decoded GLB world bounds and facade orientation",
                   "round-trip part names, bounds, triangles and material values"],
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {len(meshes)} meshes, {source_geometry['triangles']} triangles, "
          f"{len(materials)} materials, {len(binary)} GLB bytes")


if __name__ == "__main__":
    main()
