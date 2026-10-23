"""Render current Cubio artwork and six motion poses, independently of game assets."""
import json
import sys
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from animation_common import CLIPS, VIEWS, activate_clip

scene = bpy.data.scenes['Cubio Animation Studio']
bpy.context.window.scene = scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 24
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
bpy.data.objects['Ground.ShadowCatcher - optional'].hide_render = True
bpy.data.objects['Face.Plane - neutral artwork'].hide_render = False
output = HERE / 'previews'
output.mkdir(exist_ok=True)


def render(path, size=512):
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


activate_clip(scene, 'idle')
for view, camera in VIEWS.items():
    scene.camera = bpy.data.objects[camera]
    render(output / f'{view}.png')
scene.camera = bpy.data.objects['Camera.ThreeQuarter']

tiles = []
for clip, spec in CLIPS.items():
    activate_clip(scene, clip)
    scene.frame_set(spec['frames'] if spec.get('playback') == 'held' else
                    {'idle': 1, 'walk': 7, 'run': 5, 'lever_pull': 13}[clip])
    render(output / f'{clip}.png', 256)
    image = bpy.data.images.load(str(output / f'{clip}.png'), check_existing=False)
    pixels = np.empty(256 * 256 * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    tiles.append(pixels.reshape(256, 256, 4))
    bpy.data.images.remove(image)
sheet = np.ones((512, 768, 4), dtype=np.float32)
sheet[:, :, :3] = (0.94, 0.96, 0.98)
for index, tile in enumerate(tiles):
    row, column = 1 - index // 3, index % 3
    alpha = tile[:, :, 3:4]
    target = sheet[row * 256:(row + 1) * 256, column * 256:(column + 1) * 256]
    target[:, :, :3] = tile[:, :, :3] * alpha + target[:, :, :3] * (1 - alpha)
image = bpy.data.images.new('Cubio Motion Review', 768, 512, alpha=True)
image.pixels.foreach_set(sheet.ravel())
image.filepath_raw = str(output / 'motion-poses.png')
image.file_format = 'PNG'
image.save()
print('CUBIO_REVIEW_OK', json.dumps({'output': str(output), 'pose_order': list(CLIPS)}))
