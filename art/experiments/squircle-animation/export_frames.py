"""Deterministic fixed-camera export; never saves/mutates the source blend.

blender -b squircle-animated.blend --python export_frames.py -- [--output recheck] [--frames 1]
"""
from pathlib import Path
import sys
import json
import argparse
import hashlib
import os
import bpy
import numpy as np
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

HERE = Path(__file__).resolve().parent
os.environ['OPTIX_CACHE_PATH'] = str(HERE / '.cache')
(HERE / '.cache').mkdir(exist_ok=True)
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, VIEWS, PARTS, CONTROLS, activate_clip

parser = argparse.ArgumentParser()
parser.add_argument('--output', default='export')
parser.add_argument('--clips', nargs='+', choices=list(CLIPS), default=list(CLIPS))
parser.add_argument('--views', nargs='+', choices=list(VIEWS), default=list(VIEWS))
parser.add_argument('--frames', nargs='+', type=int)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
out = HERE / args.output
out.mkdir(parents=True, exist_ok=True)
scene = bpy.data.scenes['PS057 | Squircle Animation Studio']
bpy.context.window.scene = scene
face = bpy.data.objects['Face.Plane - neutral artwork']
parts = [bpy.data.objects[n] for n in PARTS]
original_materials = [p.active_material for p in parts]
original_face_material = face.active_material
catcher = bpy.data.objects['Ground.ShadowCatcher - optional']
catcher.hide_render = True
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.image_settings.color_depth = '8'
scene.render.film_transparent = True
scene.render.engine = 'CYCLES'
scene.render.threads_mode = 'FIXED'
scene.render.threads = 8
scene.cycles.seed = 57
scene.cycles.use_animated_seed = False
scene.render.use_persistent_data = True
prefs = bpy.context.preferences.addons['cycles'].preferences
prefs.compute_device_type = 'OPTIX'
prefs.get_devices()
gpu = False
for device in prefs.devices:
    device.use = device.type == 'OPTIX'
    gpu |= device.use
scene.cycles.device = 'GPU' if gpu else 'CPU'


def material(name, node):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    shader = nodes.new(node)
    output = nodes.new('ShaderNodeOutputMaterial')
    links.new(shader.outputs[0], output.inputs['Surface'])
    return mat


holdout = material('PS057 Export | Holdout occluder', 'ShaderNodeHoldout')
mask_mat = material('PS057 Export | Visible face rectangle', 'ShaderNodeEmission')
mask_mat.node_tree.nodes.get('Emission').inputs['Color'].default_value = (1,1,1,1)


def project(point):
    p = world_to_camera_view(scene, scene.camera, point)
    return [round(p.x*256, 6), round((1-p.y)*256, 6)]


def render(path, mask=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path)
    scene.cycles.samples = 16 if mask else 48
    scene.cycles.use_denoising = not mask
    bpy.ops.render.render(write_still=True)
    if mask:
        # The contract consumes alpha only. Cycles persistent shader caching
        # can leave RGB black or white when swapping emission/holdout materials.
        # Canonicalize unused RGB to white while preserving rendered coverage.
        img = bpy.data.images.load(str(path), check_existing=False)
        img.colorspace_settings.name = 'Non-Color'
        img.alpha_mode = 'STRAIGHT'
        pixels = np.empty(len(img.pixels), dtype=np.float32)
        img.pixels.foreach_get(pixels)
        pixels.reshape(-1,4)[:,:3] = 1.0
        img.pixels.foreach_set(pixels)
        img.filepath_raw = str(path)
        img.file_format = 'PNG'
        img.save()
        bpy.data.images.remove(img)


manifest = {
    'schema': 'ps057.sprite-experiment.v1', 'source': 'squircle-animated.blend',
    'source_sha256': hashlib.sha256(Path(bpy.data.filepath).read_bytes()).hexdigest(),
    'blender': bpy.app.version_string, 'engine': 'Cycles', 'device': scene.cycles.device,
    'resolution': [256,256], 'fps': 24, 'seed': 57, 'beauty_samples': 48, 'mask_samples': 16,
    'view_transform': 'AgX', 'shadow': 'none; eventual scene supplies ground shadow',
    'alpha': 'straight RGBA PNG, untrimmed; face mask uses alpha channel',
    'forward_axis': '-Y', 'root_anchor_world': [0,0,0],
    'layers': {'colorable': 'Blue toy without face; recolor at composite time',
               'face-mask': 'Visibility of entire opaque face plane; toy meshes are holdouts'},
    'face_mapping': 'Pixel-space top-left, top-right, bottom-left; affine UV; source RGBA applied through mask alpha',
    'clips': []}
(out/'expressions').mkdir(exist_ok=True)
for expression in ('neutral', 'blink'):
    bpy.data.images['PS056 Face - '+expression].save_render(str(out/'expressions'/f'{expression}.png'), scene=scene)
for clip in args.clips:
    spec = CLIPS[clip]
    rig = activate_clip(scene, clip)
    for view in args.views:
        scene.camera = bpy.data.objects[VIEWS[view]]
        record = {'name': clip, 'view': view, **spec, 'duration_seconds': spec['frames']/24,
                  'camera': VIEWS[view], 'yaw_degrees': 0 if view=='front' else 35,
                  'elevation_degrees': 0 if view=='front' else 9,
                  'orthographic_scale': scene.camera.data.ortho_scale,
                  'anchor_px': project(Vector((0,0,0))), 'sequence': []}
        for frame in args.frames or range(1, spec['frames']+1):
            if not 1 <= frame <= spec['frames']:
                raise ValueError(f'{clip}: frame out of export range: {frame}')
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            rel = Path(clip) / view
            base_path = rel / 'colorable' / f'{frame:04d}.png'
            mask_path = rel / 'face-mask' / f'{frame:04d}.png'
            face.hide_render = True
            for part, mat in zip(parts, original_materials):
                part.active_material = mat
            render(out/base_path)
            face.hide_render = False
            face.active_material = mask_mat
            for part in parts:
                part.active_material = holdout
            render(out/mask_path, mask=True)
            face.active_material = original_face_material
            corners = [project(face.matrix_world @ Vector(co)) for co in
                       [(-.625,0,.3625),(.625,0,.3625),(-.625,0,-.3625)]]
            feet = {}
            for name, offset in [('Foot.L',0), ('Foot.R',.5)]:
                pivot = bpy.data.objects[CONTROLS[name]]
                p = pivot.matrix_world.translation
                phase = ((frame-1)/spec['frames'] + offset) % 1
                feet[name] = {'world': [round(v,6) for v in p], 'pixel': project(p),
                              'planted': clip=='idle' or phase <= spec['stance']+1e-8}
            record['sequence'].append({'frame': frame, 'time_seconds': (frame-1)/24,
                                       'colorable': base_path.as_posix(), 'face_mask': mask_path.as_posix(),
                                       'face_corners_px': corners, 'feet': feet})
            print(f'PS057_FRAME {clip} {view} {frame}/{spec["frames"]}', flush=True)
        manifest['clips'].append(record)
        (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n', encoding='utf-8')
print('PS057_EXPORT_COMPLETE', out, flush=True)
