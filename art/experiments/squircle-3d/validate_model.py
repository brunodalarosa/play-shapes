"""Focused structural checks. Art approval remains with the owner."""
from pathlib import Path
import hashlib
import json
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
scene = next(s for s in bpy.data.scenes if s.name.startswith('PS056 |'))
bpy.context.window.scene = scene
bpy.context.view_layer.update()
parts = [bpy.data.objects[n] for n in ('Body.Squircle','Hand.L','Hand.R','Foot.L','Foot.R')]
face = bpy.data.objects['Face.Plane - neutral artwork']
assert len({p.data.as_pointer() for p in parts}) == 5
assert len({p.active_material.as_pointer() for p in parts}) == 1
assert face.active_material != parts[0].active_material
assert face.parent == bpy.data.objects['Body.Pivot']
assert not face.constraints
assert len(face.data.polygons) == 1
assert all(abs(v.co.y) < 1e-7 for v in face.data.vertices)
assert face.location.y < -.65
assert scene.render.film_transparent and scene.render.image_settings.color_mode == 'RGBA'
assert len([o for o in scene.objects if o.type == 'CAMERA']) == 2
assert len([o for o in scene.objects if o.type == 'LIGHT']) == 3
assert len([m for m in bpy.data.materials if m.name.startswith('Toy | ')]) == 10
assert abs(parts[0].data.shape_keys.key_blocks[1].value - .30) < 1e-6
feet = {}
for part in parts[-2:]:
    z = min((part.matrix_world @ v.co).z for v in part.data.vertices)
    assert abs(z) < 1e-6
    feet[part.name] = {'sole_minimum_world_z': z, 'pivot': part.parent.name}
textures = {}
for name in ('neutral', 'blink'):
    packed = bpy.data.images['PS056 Face - ' + name]
    assert packed.packed_file
    expected = HERE.parents[2] / 'assets/runtime/shape_characters/faces' / (name + '.png')
    copied = HERE / 'textures' / (name + '.png')
    digest = hashlib.sha256(copied.read_bytes()).hexdigest()
    assert digest == hashlib.sha256(expected.read_bytes()).hexdigest()
    textures[name] = {'sha256': digest, 'packed': True, 'matches_runtime_art': True}
report = {
    'blender_version': bpy.app.version_string,
    'scene': scene.name,
    'approval': 'pending owner review; technical checks are not art approval',
    'checks': 'passed',
    'independent_colorable_meshes': [p.name for p in parts],
    'face': {'flat': True, 'body_parented': True, 'camera_facing_constraint': False,
             'separate_material': True, 'source_pixels_unchanged': True},
    'feet': feet, 'textures': textures,
    'cameras': {o.name: {'orthographic_scale': o.data.ortho_scale,
                       'position': list(o.location)} for o in scene.objects if o.type == 'CAMERA'},
    'lights': [o.name for o in scene.objects if o.type == 'LIGHT'],
    'palette_materials': [m.name for m in bpy.data.materials if m.name.startswith('Toy | ')],
}
(HERE / 'validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('PS-056 structural checks passed; owner art approval remains pending.')
