"""Export the saved Squircle as a rigged, animated GLB for real-time 3D scenes.

Run with Blender against the saved source. The source file is never saved: the
rig is restructured only in this process's memory before export.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys

import bpy

sys.path.append(str(Path(__file__).resolve().parent))
from animation_common import CLIPS, CONTROLS, action_name  # noqa: E402
from atomic_outputs import atomic_output  # noqa: E402

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / 'assets/runtime/animated_characters/squircle/v1/model'
RIG = 'Animation.Controls'
FACE = 'Face.Plane - neutral artwork'
# Godot node names cannot contain dots, so the exported meshes use plain names.
MESH_NAMES = {
    'Body.Squircle': 'Body',
    FACE: 'Face',
    'Hand.L': 'HandL',
    'Hand.R': 'HandR',
    'Foot.L': 'FootL',
    'Foot.R': 'FootR',
}


def bone_for(mesh):
    """The control bone whose COPY_TRANSFORMS empty carries this mesh."""
    holder = mesh.parent
    for bone, empty in CONTROLS.items():
        if holder.name == empty:
            return bone
    raise AssertionError(f'{mesh.name} is not carried by a control empty')


def parent_meshes_to_bones(rig):
    # In rest pose the empties sit exactly on their bones, so reparenting keeps
    # every mesh where the sprite renders show it.
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    for source_name in MESH_NAMES:
        mesh = bpy.data.objects[source_name]
        bone = bone_for(mesh)
        world = mesh.matrix_world.copy()
        mesh.parent = rig
        mesh.parent_type = 'BONE'
        mesh.parent_bone = bone
        mesh.matrix_parent_inverse.identity()
        mesh.matrix_world = world
    bpy.context.view_layer.update()
    rig.data.pose_position = 'POSE'


def rename_for_export(rig):
    for source_name, export_name in MESH_NAMES.items():
        bpy.data.objects[source_name].name = export_name
    for clip in CLIPS:
        bpy.data.actions[action_name(clip)].name = clip
    rig.animation_data.action = None


def select_export_objects(rig):
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for export_name in MESH_NAMES.values():
        bpy.data.objects[export_name].select_set(True)
    bpy.context.view_layer.objects.active = rig


def main():
    rig = bpy.data.objects[RIG]
    parent_meshes_to_bones(rig)
    rename_for_export(rig)
    select_export_objects(rig)
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / 'squircle.glb'
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
            # Godot assigns the tint and face materials, so none are embedded.
            export_materials='NONE',
        )
    for face in ('neutral', 'blink'):
        with atomic_output(OUT / f'face-{face}.png') as temporary:
            shutil.copyfile(HERE / 'textures' / f'{face}.png', temporary)
    source = HERE / 'squircle-animated.blend'
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
        'standing_height_m': round(bpy.data.objects['Body'].matrix_world.translation.z + 1.0, 3),
    }
    with atomic_output(OUT / 'model.json') as temporary:
        temporary.write_text(json.dumps(report, indent=2) + '\n')
    print('SQUIRCLE_GLB_OK', target)


main()
