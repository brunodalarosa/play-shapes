"""Update only hand geometry and hand animation channels in the saved PS-057 file."""
from pathlib import Path
import sys
import math
import json
import bpy
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from animation_common import CLIPS, activate_clip, curves
from hand_model import rebuild_hands, pose_hands
scene=bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene=scene
rig=bpy.data.objects['Animation.Controls']


def unchanged_channels():
    result={}
    for name in CLIPS:
        action=bpy.data.actions['PS057 | '+name.title()]
        result[name]=[(c.data_path,c.array_index,[(tuple(k.co),k.interpolation) for k in c.keyframe_points])
                      for c in curves(action) if 'Hand.' not in c.data_path]
    return result


before=unchanged_channels()
rebuild_hands()
for clip,spec in CLIPS.items():
    activate_clip(scene,clip)
    for frame in range(1,spec['frames']+2):
        scene.frame_set(frame)
        pose_hands(rig,clip,math.tau*(frame-1)/spec['frames'])
        for name in ('Hand.L','Hand.R'):
            for prop in ('location','rotation_euler'):
                rig.pose.bones[name].keyframe_insert(prop,frame=frame,group=name)
    for curve in curves(rig.animation_data.action):
        if 'Hand.' in curve.data_path:
            for key in curve.keyframe_points:key.interpolation='LINEAR'
assert before==unchanged_channels(),'Non-hand animation channels changed'
rig['Rig type']='Five rigid controls; revised rounded glove hands with palms facing down.'
scene['Hand revision']='Owner requested broader glove-like hands and relaxed palm-down motion.'
activate_clip(scene,'idle')
scene.camera=bpy.data.objects['Camera.ThreeQuarter']
for obj in bpy.context.selected_objects:obj.select_set(False)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'squircle-animated.blend'))
(HERE/'hand-revision.json').write_text(json.dumps({'non_hand_animation_channels_unchanged':True,
    'source_reference':'https://sketchfab.com/3d-models/cartoon-hand-4e84e54713364931b8b2af5b8d48ce35',
    'reference_basis':'Owner supplied image; new geometry, no downloaded model or texture.',
    'changed':['Hand.L mesh','Hand.R mesh','Hand.L/R location and rotation keys'],
    'palm_normal_local':[0,-1,0]},indent=2)+'\n')
