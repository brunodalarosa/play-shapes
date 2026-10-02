"""Shared Blender action and export contract for the canonical Squircle source."""

CLIPS = {
    'idle': {'frames': 48, 'fps': 24, 'speed': 0.0, 'stance': 1.0},
    'walk': {'frames': 24, 'fps': 24, 'speed': 1.65, 'stance': .625},
    'run': {'frames': 16, 'fps': 24, 'speed': 3.6, 'stance': .375},
    'look_up': {'frames': 9, 'fps': 24, 'speed': 0.0, 'stance': 1.0, 'playback': 'held'},
    'crouch': {'frames': 9, 'fps': 24, 'speed': 0.0, 'stance': 1.0, 'playback': 'held'},
}
VIEWS = {'front': 'Camera.Front', 'three-quarter': 'Camera.ThreeQuarter'}
PARTS = ['Body.Squircle', 'Hand.L', 'Hand.R', 'Foot.L', 'Foot.R']
CONTROLS = {'Body': 'Body.Pivot', 'Hand.L': 'Hand.L.Wrist',
            'Hand.R': 'Hand.R.Wrist', 'Foot.L': 'Foot.L.Contact', 'Foot.R': 'Foot.R.Contact'}


def activate_clip(scene, name):
    import bpy
    rig = bpy.data.objects['Animation.Controls']
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions[action_name(name)]
    rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    scene.frame_start = 1
    scene.frame_end = CLIPS[name]['frames']
    scene.render.fps = CLIPS[name]['fps']
    scene.frame_set(1)
    return rig


def action_name(name):
    return ('PS080 | ' if CLIPS[name].get('playback') == 'held' else 'PS057 | ') + name.replace('_', ' ').title()
