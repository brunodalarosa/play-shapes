"""Render the saved PS-056 scene without modifying or saving the source blend.

blender --background squircle-toy.blend --python render_previews.py
"""
from pathlib import Path
import json
import bpy

HERE = Path(__file__).resolve().parent
scene = next(s for s in bpy.data.scenes if s.name.startswith('PS056 |'))
bpy.context.window.scene = scene
out = HERE / 'previews'
out.mkdir(exist_ok=True)
parts = [bpy.data.objects[name] for name in ('Body.Squircle', 'Hand.L', 'Hand.R', 'Foot.L', 'Foot.R')]
face = bpy.data.objects['Face.Plane - neutral artwork']
catcher = bpy.data.objects['Ground.ShadowCatcher - optional']
original = (scene.camera, scene.render.filepath, scene.render.resolution_x, scene.render.resolution_y,
            scene.render.resolution_percentage, [p.active_material for p in parts], face.hide_render,
            catcher.hide_render, catcher.hide_get())
manifest = {'source': 'squircle-toy.blend', 'engine': 'Cycles', 'samples': scene.cycles.samples,
            'color_management': scene.view_settings.view_transform, 'outputs': []}


def render(filename, view, color, layer='beauty'):
    scene.camera = bpy.data.objects['Camera.' + ('Front' if view == 'front' else 'ThreeQuarter')]
    scene.render.filepath = str(out / filename)
    bpy.ops.render.render(write_still=True)
    manifest['outputs'].append({'file': filename, 'view': view, 'palette': color, 'layer': layer,
                                'width': 768, 'height': 768, 'transparent': True})


try:
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    face.hide_render = False
    catcher.hide_render = True
    palette = [m for m in bpy.data.materials if m.name.startswith('Toy | ')]
    for material in palette:
        color = material.name.split(' | ')[1]
        slug = color.lower().replace(' ', '-')
        for part in parts:
            part.active_material = material
        render(slug + '-three-quarter-768.png', 'three-quarter', color)
        if color in ('Blue', 'Red', 'Golden Yellow'):
            render(slug + '-front-768.png', 'front', color)
    blue = next(m for m in palette if ' | Blue | ' in m.name)
    for part in parts:
        part.active_material = blue
    face.hide_render = True
    render('blue-colorable-only-768.png', 'three-quarter', 'Blue', 'colorable-only')
    face.hide_render = False
    catcher.hide_render = False
    catcher.hide_set(False)
    render('blue-contact-shadow-768.png', 'three-quarter', 'Blue', 'beauty-with-optional-shadow')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
finally:
    scene.camera, scene.render.filepath = original[:2]
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = original[2:5]
    for part, material in zip(parts, original[5]):
        part.active_material = material
    face.hide_render, catcher.hide_render = original[6:8]
    catcher.hide_set(original[8])

result = {'renders': len(manifest['outputs']), 'output': str(out)}
