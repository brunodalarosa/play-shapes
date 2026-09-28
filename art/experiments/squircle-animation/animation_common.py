"""Small, Blender-native PS-057 action/export contract."""
import math
import bpy

CLIPS = {
    'idle': {'frames': 48, 'fps': 24, 'speed': 0.0, 'stance': 1.0},
    'walk': {'frames': 24, 'fps': 24, 'speed': 1.65, 'stance': .625},
    'run': {'frames': 16, 'fps': 24, 'speed': 3.6, 'stance': .375},
}
VIEWS = {'front': 'Camera.Front', 'three-quarter': 'Camera.ThreeQuarter'}
PARTS = ['Body.Squircle', 'Hand.L', 'Hand.R', 'Foot.L', 'Foot.R']
CONTROLS = {'Body': 'Body.Pivot', 'Hand.L': 'Hand.L.Wrist',
            'Hand.R': 'Hand.R.Wrist', 'Foot.L': 'Foot.L.Contact', 'Foot.R': 'Foot.R.Contact'}


def activate_clip(scene, name):
    rig = bpy.data.objects['Animation.Controls']
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions['PS057 | ' + name.title()]
    rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    scene.frame_start = 1
    scene.frame_end = CLIPS[name]['frames']
    scene.render.fps = CLIPS[name]['fps']
    scene.frame_set(1)
    return rig


def foot_phase(phase, stance, stride):
    """Linear stance cancels forward root travel; airborne return is Hermite.

    Forward is -Y. In-place stance moves +Y at exactly the metadata speed.
    The Hermite return matches stance velocity at both boundaries.
    """
    phase %= 1.0
    if phase <= stance:
        return -stride / 2 + stride * phase / stance, 0.0
    t = (phase - stance) / (1 - stance)
    tangent = stride * (1 - stance) / stance
    y = ((2*t**3 - 3*t**2 + 1) * stride/2
         + (t**3 - 2*t**2 + t) * tangent
         + (-2*t**3 + 3*t**2) * -stride/2
         + (t**3 - t**2) * tangent)
    return y, math.sin(math.pi*t)**2


def curves(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                yield from bag.fcurves
