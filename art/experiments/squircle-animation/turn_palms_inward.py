"""One-time PS064 reference correction, preserving mesh geometry and action rhythm.

Run on the pre-correction saved source. Does not reconstruct authored animation.
Corrects wrist orientations and lowers wrist keys without changing the meshes.
"""
from pathlib import Path
import sys, math, json
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, curves, activate_clip
from ps064_hands import inward_rotation
scene = bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene = scene
assert not scene.get('PS064 inward palms applied', False), 'Correction already applied; do not double-offset'
rig = bpy.data.objects['Animation.Controls']

def key_snapshot():
    return {clip: {(c.data_path, c.array_index): [tuple(k.co) for k in c.keyframe_points]
                   for c in curves(bpy.data.actions['PS057 | '+clip.title()])}
            for clip in CLIPS}

before = key_snapshot()
for name in ('Hand.L','Hand.R'):
    hand = bpy.data.objects[name]
    assert max(abs(a) for a in hand.rotation_euler) < 1e-7 and hand.location.length < 1e-7, 'Unexpected mesh offset; inspect owner edits first'
    hand['PS064 palm correction'] = 'Wrist yaw/roll inward; running swing rotates about inward axis'
for clip in CLIPS:
    activate_clip(scene,clip)
    for frame in range(1,CLIPS[clip]['frames']+2):
        scene.frame_set(frame)
        for name in ('Hand.L','Hand.R'):
            bone=rig.pose.bones[name]
            bone.rotation_euler=inward_rotation(bone.rotation_euler,clip=='run')
            bone.keyframe_insert('rotation_euler',frame=frame,group=name)
    for curve in curves(bpy.data.actions['PS057 | '+clip.title()]):
        if curve.data_path in ('pose.bones["Hand.L"].location', 'pose.bones["Hand.R"].location') and curve.array_index == 2:
            for key in curve.keyframe_points:
                key.co.y -= .14
                key.handle_left.y -= .14
                key.handle_right.y -= .14
            curve.update()
after = key_snapshot()
for clip, channels in before.items():
    for (path, axis), keys in channels.items():
        if path in ('pose.bones["Hand.L"].location','pose.bones["Hand.R"].location') and axis == 2:
            assert all(abs(a[0]-b[0])<1e-7 and abs((a[1]-.14)-b[1])<1e-6
                       for a,b in zip(keys,after[clip][path,axis]))
        elif path not in ('pose.bones["Hand.L"].rotation_euler','pose.bones["Hand.R"].rotation_euler'):
            assert keys == after[clip][path,axis], 'Unrelated animation channel changed'
scene['PS064 inward palms applied'] = True
scene['Hand revision'] = 'Owner reference 05: inward palms in all actions, wrists lowered 0.14 m. Approval pending.'
activate_clip(scene,'idle')
scene.camera = bpy.data.objects['Camera.Front']
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'squircle-animated.blend'))
(HERE/'ps064-inward-revision.json').write_text(json.dumps({
    'source_before':'before-inward-ps064/squircle-animated.blend',
    'reference':'Management/Task references/PS-064/05-inward-palms-owner-target.png',
    'rotation_correction':'Inward wrist yaw/roll; run angular swing around world X', 'wrist_height_offset_m':-.14,
    'all_other_animation_channels_unchanged':True,
    'geometry_unchanged':True, 'approval':'pending'},indent=2)+'\n',encoding='utf-8')
