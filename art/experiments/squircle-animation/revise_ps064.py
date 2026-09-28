"""Apply PS064 to a saved animation source; preserve every non-hand channel."""
from pathlib import Path
import sys, math, json
import bpy
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, activate_clip, curves
from ps064_hands import rebuild_hands, pose_hands
scene = bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene = scene
rig = bpy.data.objects['Animation.Controls']

def preserved_channels():
    return {clip:[(c.data_path,c.array_index,[(tuple(k.co),k.interpolation) for k in c.keyframe_points])
                  for c in curves(bpy.data.actions['PS057 | '+clip.title()])
                  if 'Hand' not in c.data_path] for clip in CLIPS}

before = preserved_channels()
rebuild_hands(rig)
for clip, spec in CLIPS.items():
    activate_clip(scene, clip)
    for frame in range(1,spec['frames']+2):
        scene.frame_set(frame)
        pose_hands(rig, clip, math.tau*(frame-1)/spec['frames'])
        rig.keyframe_insert('["Hand curl"]',frame=frame,group='Hand shape')
        for name in ('Hand.L','Hand.R'):
            for prop in ('location','rotation_euler'):
                rig.pose.bones[name].keyframe_insert(prop,frame=frame,group=name)
    for curve in curves(rig.animation_data.action):
        if 'Hand' in curve.data_path:
            for key in curve.keyframe_points: key.interpolation = 'LINEAR'
            if not curve.modifiers: curve.modifiers.new('CYCLES')
assert before == preserved_channels(), 'Non-hand channels changed'
scene['Hand revision'] = 'PS064: hanging idle, 35% curled walk, closed running fists. Owner review pending.'
scene['PS064 inward palms applied'] = True
rig['Rig type'] = 'Five rigid controls plus Hand curl: native driven glove shape keys.'
activate_clip(scene,'idle')
scene.camera = bpy.data.objects['Camera.ThreeQuarter']
scene.frame_set(1)
bpy.context.view_layer.update()
guide = bpy.data.texts.get('START HERE - PS064 Hands') or bpy.data.texts.new('START HERE - PS064 Hands')
guide.clear()
guide.write('PS064 HAND REVIEW - approval pending\nChoose PS057 | Idle / Walk / Run on Animation.Controls.\nHand curl is keyed: 0 idle, .35 walk, 1 run. Native drivers update the two Closed fist shape keys.\nTimeline ends: 48 / 24 / 16, at 24 fps. Frame N+1 repeats frame 1.\nBefore: before-ps064/squircle-animated.blend. Static PS056 source is unchanged.\n')
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'squircle-animated.blend'))
(HERE/'ps064-revision.json').write_text(json.dumps({'non_hand_animation_channels_unchanged':True,
    'before_source':'before-ps064/squircle-animated.blend','hand_curl':{'idle':0,'walk':.35,'run':1},
    'swing_y_amplitude_m':{'idle':.018,'walk':.30,'run':.67},
    'approval':'pending'},indent=2)+'\n')
