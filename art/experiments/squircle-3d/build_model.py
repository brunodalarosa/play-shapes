"""Run in Blender's Text Editor or with blender --background --python.

Creates a NEW scene; never deletes or replaces an existing scene. The editable
blend needs neither this script nor the MCP to open, pose, tune, or render.
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
PALETTE = {
    'Red': 'E53935', 'Orange': 'F57C00', 'Golden Yellow': 'FBC02D',
    'Green': '43A047', 'Cyan': '00ACC1', 'Blue': '1E88E5',
    'Indigo': '3949AB', 'Purple': '8E24AA', 'Pink': 'EC407A', 'Brown': '8D6E63',
}


def linear(hex_color):
    def convert(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return tuple(convert(int(hex_color[i:i + 2], 16) / 255) for i in (0, 2, 4)) + (1,)


def activate(obj):
    for selected in bpy.context.selected_objects:
        selected.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def link_only(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def empty(name, location, collection, parent=None, display='PLAIN_AXES', size=.18):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = location
    obj.empty_display_type = display
    obj.empty_display_size = size
    obj.parent = parent
    return obj


def mesh(name, verts, faces, collection, parent=None):
    data = bpy.data.meshes.new(name + '.Mesh')
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    obj.parent = parent
    for polygon in data.polygons:
        polygon.use_smooth = True
    return obj


def signpow(value, power):
    return math.copysign(abs(value) ** power, value)


def body_coords(exponent):
    # Latitude runs along depth (Y); longitude traces the X/Z squircle.
    verts = [(0, -.65, 0)]
    rings, sides = 48, 96
    for j in range(1, rings):
        phi = -math.pi / 2 + math.pi * j / rings
        radial = abs(math.cos(phi)) ** .52
        y = .65 * signpow(math.sin(phi), .52)
        for i in range(sides):
            theta = math.tau * i / sides
            verts.append((radial * signpow(math.cos(theta), exponent), y,
                          radial * signpow(math.sin(theta), exponent)))
    verts.append((0, .65, 0))
    return verts


def ellipsoid(name, location, scale, collection):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    link_only(obj, collection)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def make_hand(name, side, collection, root, material):
    # A thumb plus three rounded fingers, retaining the original open silhouette.
    # Fused into one continuous editable mesh, with a wrist pivot outside the palm.
    parts = [ellipsoid(name + '.Palm', (0, 0, .05), (.22, .145, .24), collection)]
    for x, z, length, tilt in [(-.145, .28, .22, -.22), (.01, .34, .245, 0), (.155, .27, .205, .2)]:
        part = ellipsoid(name + '.Finger', (x, -.012, z), (.083, .11, length), collection)
        part.rotation_euler[1] = tilt
        parts.append(part)
    thumb = ellipsoid(name + '.Thumb', (-.25, -.025, .075), (.09, .115, .19), collection)
    thumb.rotation_euler[1] = -.8
    parts.append(thumb)
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    hand = bpy.context.object
    hand.name = name
    remesh = hand.modifiers.new('Continuous rounded fingers', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = .022
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = hand.modifiers.new('Gentle palm smoothing', 'SMOOTH')
    smooth.factor = 1.1
    smooth.iterations = 4
    sub = hand.modifiers.new('Surface finish', 'SUBSURF')
    sub.levels = 1
    sub.render_levels = 2
    # Joined mesh coordinates are relative to the first sphere at z=.05.
    for vertex in hand.data.vertices:
        vertex.co.z += .05
        vertex.co.x *= side
    hand.location = (0, 0, 0)
    activate(hand)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    pivot = empty(name + '.Wrist', (side * 1.68, .08, .92), collection, root)
    pivot.rotation_euler[1] = side * .42
    pivot.rotation_euler[2] = side * -.12
    hand.parent = pivot
    hand.data.materials.append(material)
    return hand


def aim(obj, at):
    obj.rotation_euler = (Vector(at) - obj.location).to_track_quat('-Z', 'Y').to_euler()


def build():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    scene = bpy.data.scenes.new('PS056 | Squircle Toy Studio')
    bpy.context.window.scene = scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 192
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.film_transparent = True
    scene.view_settings.view_transform = 'AgX'
    scene.world = bpy.data.worlds.new('PS056 | Neutral studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.7, .78, 1, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .28
    scene.unit_settings.system = 'METRIC'

    collections = {}
    for name in ('01 | Character - colorable', '02 | Face - untinted', '03 | Studio', '04 | Ground guides'):
        col = bpy.data.collections.new(name)
        scene.collection.children.link(col)
        collections[name[:2]] = col
    colorable, faces, studio, guides = (collections[key] for key in ('01', '02', '03', '04'))
    root = empty('Character.Root - ground anchor', (0, 0, 0), colorable, size=.35)
    root['Note'] = 'Ground Z=0; character faces -Y; left/right named by front-view screen position.'
    body_pivot = empty('Body.Pivot', (0, 0, 1.62), colorable, root)

    mats = {}
    for label, hex_value in PALETTE.items():
        mat = bpy.data.materials.new('Toy | ' + label + ' | #' + hex_value)
        mat.use_nodes = True
        mat.use_fake_user = True
        mat.diffuse_color = linear(hex_value)
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = linear(hex_value)
        shader.inputs['Roughness'].default_value = .32
        shader.inputs['IOR'].default_value = 1.46
        shader.inputs['Coat Weight'].default_value = .18
        shader.inputs['Coat Roughness'].default_value = .24
        mats[label] = mat
    material = mats['Blue']

    sides, rings = 96, 48
    polygons = []
    for i in range(sides):
        polygons.append((0, 1 + i, 1 + (i + 1) % sides))
    for j in range(rings - 2):
        for i in range(sides):
            a = 1 + j * sides + i
            b = 1 + j * sides + (i + 1) % sides
            polygons.append((a, a + sides, b + sides, b))
    last = 1 + (rings - 2) * sides
    top = len(body_coords(.4)) - 1
    for i in range(sides):
        polygons.append((last + i, top, last + (i + 1) % sides))
    body = mesh('Body.Squircle', body_coords(.4), polygons, colorable, body_pivot)
    body.data.materials.append(material)
    activate(body)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    body.shape_key_add(name='Basis - firmer squircle')
    soft = body.shape_key_add(name='Softness - rounder silhouette')
    for vertex, co in zip(soft.data, body_coords(.88)):
        vertex.co = co
    soft.value = .30
    body['Tuning'] = 'Object Data Properties > Shape Keys > Softness. 0=boxier; 1=rounder. Default 0.30.'

    # Original texture dimensions 100x58; same relative face/body width as 2D art.
    w, h = 1.25, .725
    face = mesh('Face.Plane - neutral artwork', [(-w/2, 0, -h/2), (w/2, 0, -h/2),
                (w/2, 0, h/2), (-w/2, 0, h/2)], [(0, 1, 2, 3)], faces, body_pivot)
    face.location = (0, -.665, .015)
    uv = face.data.uv_layers.new(name='Original face UV')
    for loop, value in zip(uv.data, [(0, 0), (1, 0), (1, 1), (0, 1)]):
        loop.uv = value
    ink = bpy.data.materials.new('Face | Original RGBA - never tint')
    ink.use_nodes = True
    nodes, links = ink.node_tree.nodes, ink.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    output.location = (600, 0)
    mix = nodes.new('ShaderNodeMixShader')
    mix.location = (370, 0)
    transparent = nodes.new('ShaderNodeBsdfTransparent')
    transparent.location = (120, -100)
    emission = nodes.new('ShaderNodeEmission')
    emission.location = (120, 90)
    image_node = nodes.new('ShaderNodeTexImage')
    image_node.name = 'EXPRESSION - choose neutral or blink'
    image_node.label = 'EXPRESSION - neutral / blink'
    image_node.extension = 'CLIP'
    image_node.location = (-180, 180)
    for expression in ('neutral', 'blink'):
        img = bpy.data.images.load(str(HERE / 'textures' / (expression + '.png')), check_existing=False)
        img.name = 'PS056 Face - ' + expression
        img.pack()
        img.use_fake_user = True
        img.filepath = '//textures/' + expression + '.png'
        if expression == 'neutral':
            image_node.image = img
    links.new(image_node.outputs['Color'], emission.inputs['Color'])
    links.new(image_node.outputs['Alpha'], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs['Surface'])
    face.data.materials.append(ink)
    face.visible_shadow = False
    face.visible_glossy = False
    face.visible_diffuse = False
    face.visible_transmission = False
    face['Note'] = 'Flat local XZ plane, 0.015m ahead of body. Body-parented; no camera-facing constraint.'
    make_hand('Hand.L', -1, colorable, root, material)
    make_hand('Hand.R', 1, colorable, root, material)

    for name, side in [('Foot.L', -1), ('Foot.R', 1)]:
        foot = ellipsoid(name, (0, 0, 0), (.39, .46, .22), colorable)
        # Flat sole and low round toe. Pivot lies at center of sole on Z=0.
        for v in foot.data.vertices:
            v.co.z = max(.0, v.co.z + .17)
        pivot = empty(name + '.Contact', (side * .49, -.13, 0), colorable, root)
        pivot.rotation_euler[2] = side * -.12
        foot.parent = pivot
        foot.data.materials.append(material)
        foot['Note'] = 'Local sole Z=0. Rotate parent Contact pivot for a step; whole root anchors ground.'

    ground = empty('Ground.Contact - Z equals 0', (0, 0, 0), guides, display='CIRCLE', size=1.2)
    ground['Shadow policy'] = 'Separate optional shadow catcher. Main beauty excludes it; no export decision implied.'
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.003))
    catcher = bpy.context.object
    catcher.name = 'Ground.ShadowCatcher - optional'
    link_only(catcher, guides)
    catcher.is_shadow_catcher = True
    catcher.hide_render = True
    catcher.hide_set(True)

    for name, yaw, elevation in [('Camera.Front', 0, 0), ('Camera.ThreeQuarter', 35, 9)]:
        data = bpy.data.cameras.new(name)
        data.type = 'ORTHO'
        data.ortho_scale = 4.5
        camera = bpy.data.objects.new(name, data)
        studio.objects.link(camera)
        angle, elev = math.radians(yaw), math.radians(elevation)
        target = Vector((0, 0, 1.34))
        camera.location = target + Vector((8 * math.sin(angle) * math.cos(elev),
                             -8 * math.cos(angle) * math.cos(elev), 8 * math.sin(elev)))
        aim(camera, target)
        camera['View'] = f'Orthographic; yaw {yaw} degrees, elevation {elevation} degrees.'
    scene.camera = bpy.data.objects['Camera.ThreeQuarter']
    for name, location, energy, size in [
        ('Light.Key - large softbox', (-3.5, -4.5, 6), 450, 4),
        ('Light.Fill - face readability', (3.5, -3, 3.2), 180, 3.5),
        ('Light.Rim - silhouette', (2, 3, 4.5), 550, 3),
    ]:
        data = bpy.data.lights.new(name, 'AREA')
        data.energy, data.shape, data.size = energy, 'DISK', size
        obj = bpy.data.objects.new(name, data)
        studio.objects.link(obj)
        obj.location = location
        aim(obj, (0, 0, 1.2))
    scene['Approval'] = 'PS-056 awaiting owner inspection. Not an approved PS-057 source.'
    scene['Palette source'] = 'characters/character_selection.gd at 8c1f850'
    scene['Ground contract'] = 'Z=0 is sole contact, -Y is front. Character.Root stays at ground anchor.'
    scene['Preview contract'] = '768 / 256 / 128 square RGBA, orthographic scale 4.5, yaw 0 / 35 degrees.'
    activate(body)
    body.active_shape_key_index = 1
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.region_3d.view_perspective = 'CAMERA'
            space.region_3d.view_camera_zoom = 12
            space.overlay.show_overlays = False
            space.shading.type = 'MATERIAL'
        elif area.type == 'PROPERTIES':
            area.spaces.active.context = 'DATA'
    bpy.context.view_layer.update()
    scene.render.filepath = str(HERE / 'previews' / 'blue-three-quarter-768.png')
    if (HERE / 'README.md').exists():
        tutorial = bpy.data.texts.new('START HERE - Squircle tuning guide')
        tutorial.write((HERE / 'README.md').read_text(encoding='utf-8'))
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'squircle-toy.blend'))
    return {'scene': scene.name, 'file': bpy.data.filepath, 'objects': len(scene.objects)}


if __name__ == '__main__':
    result = build()
