"""One-time PS-079 revision of the saved PS-064 source, never a scene rebuild.

Run only on before-ps079/squircle-animated.blend. Edit both Hand meshes together
in the saved source for subsequent size tuning; do not reapply this migration.
"""
from pathlib import Path
import sys, json, hashlib
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, PARTS, CONTROLS, activate_clip, curves

DIAMETER = 0.60
scene = bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene = scene
assert 'Hand curl' in bpy.data.objects['Animation.Controls'], 'Use the preserved pre-PS079 source'

def animation_snapshot():
    return {a.name: [(f.data_path, f.array_index,
                      [(tuple(k.co), tuple(k.handle_left), tuple(k.handle_right), k.interpolation)
                       for k in f.keyframe_points])
                     for f in curves(a) if f.data_path != '["Hand curl"]']
            for a in bpy.data.actions}

def poses():
    result = []
    for clip, spec in CLIPS.items():
        activate_clip(scene, clip)
        for frame in range(1, spec['frames'] + 2):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            result.append([list(row) for n in CONTROLS.values() for row in bpy.data.objects[n].matrix_world])
    return result

before_curves, before_poses = animation_snapshot(), poses()
original_sha = hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest()
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

for name in ('Hand.L', 'Hand.R'):
    hand = bpy.data.objects[name]
    old_mesh = hand.data
    material = hand.active_material
    hand.modifiers.clear()
    # Replace only the mesh datablock: object identity, parent and pivot remain.
    bpy.ops.object.select_all(action='DESELECT')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=DIAMETER / 2)
    temporary = bpy.context.object
    sphere = temporary.data
    hand.data = sphere
    bpy.data.objects.remove(temporary, do_unlink=True)
    bpy.data.meshes.remove(old_mesh)
    sphere.name = name + ' | smooth sphere'
    sphere.materials.append(material)
    for polygon in sphere.polygons:
        polygon.use_smooth = True
    for key in list(hand.keys()):
        del hand[key]
    hand['Design'] = 'PS079 smooth floating toy sphere; no cuff, fingers or curl'
    hand['Sizing'] = 'Diameter 0.60 m; edit both meshes together around their unchanged origins'

rig = bpy.data.objects['Animation.Controls']
for action in bpy.data.actions:
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in list(bag.fcurves):
                    if curve.data_path == '["Hand curl"]':
                        bag.fcurves.remove(curve)
del rig['Hand curl']
rig['Rig type'] = 'Five rigid controls; spherical hands, no hand-curl deformation'
assert animation_snapshot() == before_curves, 'A saved motion channel changed'
assert poses() == before_poses, 'A control transform changed'
scene['Hand model'] = 'PS079 spheres'
scene['Hand diameter m'] = DIAMETER
scene['Hand revision'] = 'PS079 spherical hands; owner visual approval pending'
if 'PS064 inward palms applied' in scene:
    del scene['PS064 inward palms applied']
guide = bpy.data.texts.get('START HERE - PS064 Hands')
if guide:
    guide.name = 'START HERE - PS079 Spheres'
    guide.clear()
    guide.write('SQUIRCLE V1 / PS079 SPHERICAL HANDS / APPROVAL PENDING\n'
                'Select PS057 | Idle / Walk / Run on Animation.Controls.\n'
                '48 / 24 / 16 frames at 24 fps; N+1 repeats frame 1.\n'
                'Both smooth spheres: 0.60 m diameter, centered on unchanged hand pivots.\n'
                'For sizing, scale both Hand meshes equally in Edit Mode about their origins.\n'
                'No fingers, cuffs, shape keys or Hand curl channels.\n'
                'Export saved source with export_frames.py, make_previews.py, review_ps064.py --task PS-079.\n'
                'The complete pre-revision source and previews are in before-ps079/.\n')
activate_clip(scene, 'idle')
scene.camera = bpy.data.objects['Camera.ThreeQuarter']
bpy.ops.object.select_all(action='DESELECT')
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(HERE / 'squircle-animated.blend'))
report = {'source_before_sha256': original_sha,
          'source_after_sha256': hashlib.sha256((HERE / 'squircle-animated.blend').read_bytes()).hexdigest(),
          'diameter_m': DIAMETER, 'body_width_m': 2.0, 'foot_length_m': 0.9199991822242737,
          'diameter_to_body_width': DIAMETER / 2.0,
          'diameter_to_foot_length': DIAMETER / 0.9199991822242737,
          'all_motion_curves_except_obsolete_curl_preserved': True,
          'all_five_control_matrices_preserved_at_every_frame_and_loop_key': True,
          'placement_adjustments': 'none; spheres centered on original hand pivots',
          'approval': 'pending owner proportion and motion review'}
(HERE / 'ps079-revision.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
