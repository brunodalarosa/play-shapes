"""Export the saved Cubio as a rigged, animated GLB for real-time 3D scenes.

Run with Blender against the saved source. The source file is never saved: the
rig is restructured only in this process's memory before export.
"""
from pathlib import Path
import hashlib
import json
import sys

import bpy

sys.path.append(str(Path(__file__).resolve().parent))
from animation_common import CLIPS, CONTROLS, action_name  # noqa: E402
from atomic_outputs import atomic_output  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'assets/runtime/animated_characters/cubio/model'
RIG = 'Animation.Controls'
# Godot node names cannot contain dots, so the exported objects use plain names.
MESH_NAMES = {
    'Body.Cubio': 'Body',
    'Hand.L': 'HandL',
    'Hand.R': 'HandR',
    'Foot.L': 'FootL',
    'Foot.R': 'FootR',
}
# The empty a shape face is drawn on. Unrotated, its -Y faces out of the front, which is +Z
# once exported Y up.
ANCHOR_NAMES = {'Face.Anchor': 'FaceAnchor'}
EXPORTED_NAMES = {**MESH_NAMES, **ANCHOR_NAMES}


def bone_for(item):
    """The control bone whose COPY_TRANSFORMS empty carries this object."""
    holder = item.parent
    for bone, empty in CONTROLS.items():
        if holder.name == empty:
            return bone
    raise AssertionError(f'{item.name} is not carried by a control empty')


def parent_meshes_to_bones(rig):
    # In rest pose the empties sit exactly on their bones, so reparenting keeps
    # every mesh where the animated source scene shows it.
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    for source_name in EXPORTED_NAMES:
        item = bpy.data.objects[source_name]
        bone = bone_for(item)
        world = item.matrix_world.copy()
        item.parent = rig
        item.parent_type = 'BONE'
        item.parent_bone = bone
        item.matrix_parent_inverse.identity()
        item.matrix_world = world
    bpy.context.view_layer.update()
    rig.data.pose_position = 'POSE'


def rename_for_export(rig):
    for source_name, export_name in EXPORTED_NAMES.items():
        bpy.data.objects[source_name].name = export_name
    for clip in CLIPS:
        bpy.data.actions[action_name(clip)].name = clip
    rig.animation_data.action = None


def select_export_objects(rig):
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for export_name in EXPORTED_NAMES.values():
        bpy.data.objects[export_name].select_set(True)
    bpy.context.view_layer.objects.active = rig


def main():
    rig = bpy.data.objects[RIG]
    parent_meshes_to_bones(rig)
    rename_for_export(rig)
    select_export_objects(rig)
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / 'cubio.glb'
    with atomic_output(target) as temporary:
        bpy.ops.export_scene.gltf(
            filepath=str(temporary),
            export_format='GLB',
            use_selection=True,
            export_yup=True,
            export_apply=False,
            export_animations=True,
            export_animation_mode='ACTIONS',
            export_anim_slide_to_zero=True,
            export_force_sampling=True,
            export_frame_step=1,
            export_def_bones=False,
            export_rest_position_armature=True,
            # Godot and the phone assign the tint, so no materials are embedded.
            export_materials='NONE',
        )
    source = HERE / 'cubio-animated.blend'
    report = {
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'glb_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
        'clips': {
            name: {
                'frames': spec['frames'],
                'fps': spec['fps'],
                'playback': spec.get('playback', 'loop'),
                'forward_speed_m_per_s': spec['speed'],
            }
            for name, spec in CLIPS.items()
        },
        'meshes': sorted(MESH_NAMES.values()),
        'anchors': sorted(ANCHOR_NAMES.values()),
        'body_dimensions_m': list(bpy.data.objects['Body'].dimensions),
        'body_bevel_m': bpy.context.scene['Body bevel m'],
        'standing_height_m': round(bpy.data.objects['Body'].matrix_world.translation.z + 1.0, 3),
    }
    with atomic_output(OUT / 'model.json') as temporary:
        temporary.write_text(json.dumps(report, indent=2) + '\n', newline='\n')
    print('CUBIO_GLB_OK', target)


main()
