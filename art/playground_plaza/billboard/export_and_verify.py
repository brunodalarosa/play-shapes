"""Export the saved billboard and verify its independent display and GLB round trip."""

import hashlib
import json
from pathlib import Path
import struct

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector


DIRECTORY = Path(__file__).resolve().parent
SOURCE = DIRECTORY / "billboard.blend"
EXPORT = DIRECTORY / "export" / "billboard.glb"
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
        require(obj.name == "Display" or closed, f"Open mesh: {obj.name}")
        require(all(face.calc_area() > 1e-10 for face in bm.faces), f"Zero area: {obj.name}")
        positive = bm.calc_volume(signed=True) > 0
        require(obj.name == "Display" or positive, f"Inverted mesh: {obj.name}")
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


def check_display(obj):
    mesh = obj.data
    require(not obj.modifiers, "Display must remain a plain quad")
    require(len(mesh.vertices) == 4 and len(mesh.polygons) in (1, 2),
            "Display must remain one square surface")
    points = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    close([min(p[i] for p in points) for i in range(3)], [-3, .201, 5],
          "Display lower bounds changed")
    close([max(p[i] for p in points) for i in range(3)], [3, .201, 11],
          "Display upper bounds changed")
    require(mesh.uv_layers.active is not None, "Display UV missing")
    mapping = []
    for face in mesh.polygons:
        normal = obj.matrix_world.to_3x3() @ face.normal
        require(normal.y > .999, "Display must face +Y in Blender")
        for index in face.loop_indices:
            point = points[mesh.loops[index].vertex_index]
            uv = mesh.uv_layers.active.data[index].uv
            close(uv, [(3 - point.x) / 6, (point.z - 5) / 6],
                  "Display UV is mirrored, rotated or cropped")
            mapping.append({"position": list(point), "uv": list(uv)})
    require(len(obj.material_slots) == 1, "Display must have one material")
    require(obj.material_slots[0].material.name == "Display Blank Cream",
            "Independent display material missing")
    return mapping


def check_supports(objects):
    by_name = {obj.name: obj for obj in objects}

    def bounds(obj):
        points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        return ([min(p[i] for p in points) for i in range(3)],
                [max(p[i] for p in points) for i in range(3)])

    for side in ("Left", "Right"):
        bottom, top = bounds(by_name["Foot " + side])
        low, high = bounds(by_name["Support " + side])
        require(abs(bottom[2]) < TOLERANCE, "Foot must sit on ground")
        require(low[2] <= top[2] and high[2] >= 4.8,
                "Support must connect foot to frame")
        for axis in (0, 1):
            require(low[axis] > bottom[axis] and high[axis] < top[axis],
                    "Foot must contain support footprint")


def check_gltf(document, binary):
    json_length = struct.unpack_from("<I", binary, 12)[0]
    buffer_start = 28 + json_length
    points = []
    display_uv = []

    def read_accessor(index, width):
        accessor = document["accessors"][index]
        require(accessor["componentType"] == 5126, "Unexpected float encoding")
        require(accessor["type"] == f"VEC{width}", "Unexpected accessor size")
        view = document["bufferViews"][accessor["bufferView"]]
        start = buffer_start + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", width * 4)
        return [struct.unpack_from(f"<{width}f", binary, start + i * stride)
                for i in range(accessor["count"])]

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
            primitives = document["meshes"][node["mesh"]]["primitives"]
            for primitive in primitives:
                require(primitive.get("mode", 4) == 4, "Expected triangle primitives")
                attributes = primitive["attributes"]
                vertices = read_accessor(attributes["POSITION"], 3)
                world = [transform @ Vector(p) for p in vertices]
                points.extend(world)
                if node.get("name") == "Display":
                    require(len(primitives) == 1, "Display must export independently")
                    uvs = read_accessor(attributes["TEXCOORD_0"], 2)
                    normals = read_accessor(attributes["NORMAL"], 3)
                    material = document["materials"][primitive["material"]]
                    require(material["name"] == "Display Blank Cream",
                            "GLB display material changed")
                    for p, uv, n in zip(world, uvs, normals):
                        require(abs(p.z + .201) < TOLERANCE, "GLB display plane changed")
                        normal = transform.to_3x3() @ Vector(n)
                        require(normal.z < -.999, "GLB display must face -Z")
                        # glTF uses the image's top-left origin; Blender uses bottom-left.
                        close(uv, [(3 - p.x) / 6, (11 - p.y) / 6],
                              "GLB display mapping changed")
                        display_uv.append({"position": list(p), "uv": list(uv)})
        for child in node.get("children", []):
            visit(child, transform)

    for index in document["scenes"][document.get("scene", 0)]["nodes"]:
        visit(index, Matrix.Identity(4))
    bounds = {"minimum": [min(p[i] for p in points) for i in range(3)],
              "maximum": [max(p[i] for p in points) for i in range(3)]}
    close(bounds["minimum"], [-3.2, 0, -.4], "GLB minimum bounds changed")
    close(bounds["maximum"], [3.2, 11.57, .4], "GLB maximum bounds changed")
    require(len(display_uv) == 4, "GLB display corners missing")
    return bounds, display_uv


def main():
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    collection = bpy.data.collections["Billboard Asset"]
    meshes = [obj for obj in collection.objects if obj.type == "MESH"]
    root = collection.objects["Billboard"]
    require(root.location.length < TOLERANCE, "Root must be at ground center")
    close(root.scale, [1, 1, 1], "Root scale changed")
    close(root.rotation_euler, [0, 0, 0], "Root rotation changed")
    require(not bpy.data.libraries, "Source contains linked libraries")
    require(not [im for im in bpy.data.images if im.source == "FILE"],
            "Source unexpectedly depends on image files")
    require(all(obj.parent == root for obj in meshes), "Asset parts must share the root")
    for obj in meshes:
        close(obj.scale, [1, 1, 1], f"Unapplied scale: {obj.name}")
        close(obj.rotation_euler, [0, 0, 0], f"Unapplied rotation: {obj.name}")
    expected_names = {"Display", "Frame", "Backing", "Support Left", "Support Right",
                      "Foot Left", "Foot Right", "Lamp Left", "Lamp Right"}
    require({obj.name for obj in meshes} == expected_names, "Asset parts changed")
    mapping = check_display(collection.objects["Display"])
    check_supports(meshes)
    source_geometry = geometry(meshes)
    materials = material_values(meshes)
    require(source_geometry["triangles"] < 3000, "Triangle budget exceeded")
    require(len(meshes) <= 12 and len(materials) <= 5, "Mesh/material budget exceeded")
    for obj in meshes:
        if obj.name != "Display":
            require(all(slot.material.name != "Display Blank Cream"
                        for slot in obj.material_slots), "Display material shared with structure")

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
    require(not document.get("animations") and not document.get("cameras")
            and not document.get("extensionsUsed"), "Unexpected export features")
    require({node["name"] for node in document["nodes"]} == expected_names | {"Billboard"},
            "Review objects leaked into export")
    require(len(document["materials"]) == len(materials), "Material count changed")
    bounds, exported_uv = check_gltf(document, binary)
    primitive_count = sum(len(mesh["primitives"]) for mesh in document["meshes"])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(EXPORT))
    imported = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    require({obj.name for obj in imported} == expected_names, "Round-trip part names changed")
    check_display(bpy.data.objects["Display"])
    check_supports(imported)
    round_trip = geometry(imported)
    for key in ("minimum", "maximum"):
        close(round_trip[key], source_geometry[key], f"Round-trip bounds changed: {key}")
    require(source_geometry["triangles_by_object"] == round_trip["triangles_by_object"],
            "Round-trip triangles changed")
    actual_materials = material_values(imported)
    require(set(materials) == set(actual_materials), "Round-trip material names changed")
    for name, values in materials.items():
        actual = actual_materials[name]
        close(actual["color"], values["color"], f"Round-trip color changed: {name}")
        for key in ("roughness", "metallic"):
            require(abs(values[key] - actual[key]) < TOLERANCE,
                    f"Round-trip {key} changed: {name}")

    report = {
        "result": "PASS", "blender_version": bpy.app.version_string,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "export_sha256": hashlib.sha256(binary).hexdigest(), "export_bytes": len(binary),
        "source_geometry_blender_xyz": source_geometry,
        "round_trip_geometry_blender_xyz": round_trip, "materials": materials,
        "gltf_world_bounds_xyz": bounds, "exported_mesh_surfaces": primitive_count,
        "display_size": [6, 6], "display_bottom": 5,
        "display_source_mapping": mapping, "display_gltf_mapping": exported_uv,
        "gltf_orientation": "Y up; display -Z; ground-centered origin",
        "evidence": "AUTO: Blender source and GLB round trip; no Godot import/runtime evidence",
        "checks": ["closed positive-volume structure", "front-facing single display surface",
                   "no degenerate faces", "triangle, mesh and material budgets",
                   "square display bounds and full-square upright UV in source and GLB",
                   "grounded feet and support contact", "independent display mesh/material",
                   "applied mesh scales/rotations", "ground origin", "no external dependencies",
                   "no studio objects in export", "decoded GLB world bounds and orientation",
                   "round-trip names, bounds, triangles, UV and material values"],
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {len(meshes)} meshes, {source_geometry['triangles']} triangles, "
          f"{len(materials)} materials, {primitive_count} surfaces, {len(binary)} GLB bytes")


if __name__ == "__main__":
    main()
