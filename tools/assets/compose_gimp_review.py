"""Run in GIMP's Python console through MCP; composes review images only.

Set PLAY_SHAPES_ROOT to the absolute checkout path before executing this file.
Run prepare_gimp_inputs.py first, then call review('Default') / review('Double').
Export the returned image with GIMP. Nothing executes on import except definitions.
"""
from pathlib import Path
from gi.repository import Gimp, Gegl, Gio

ROOT = Path(PLAY_SHAPES_ROOT)
PACK = ROOT / 'assets/Kenney_Shape_Characters'
GIMP_INPUT = ROOT / 'test-results/ps-009/gimp-rgba'


def place(image, file, x, y):
    normalized = GIMP_INPUT / file.relative_to(PACK)
    if normalized.exists():
        file = normalized
    layer = Gimp.file_load_layer(Gimp.RunMode.NONINTERACTIVE, image, Gio.File.new_for_path(str(file)))
    image.insert_layer(layer, None, 0)
    layer.set_offsets(x, y)
    return layer


def canvas(w, h, color):
    image = Gimp.Image.new(w, h, Gimp.ImageBaseType.RGB)
    layer = Gimp.Layer.new(image, 'Review background', w, h, Gimp.ImageType.RGBA_IMAGE, 100, Gimp.LayerMode.NORMAL)
    image.insert_layer(layer,None,0)
    Gimp.context_set_foreground(Gegl.Color.new(color))
    layer.fill(Gimp.FillType.FOREGROUND)
    return image


def label(image, text, x, y, size=20):
    layer = Gimp.TextLayer.new(image,text,Gimp.Font.get_by_name('Sans-serif'),size,Gimp.Unit.pixel())
    image.insert_layer(layer,None,0)
    layer.set_color(Gegl.Color.new('#243951'))
    layer.set_offsets(x,y)


def review(resolution):
    scale = 1 if resolution == 'Default' else 2
    image = canvas(1000, 600, '#EDF3F7')
    label(image, f'PS-009 / {resolution} / native pixel size', 30, 20, 28)
    label(image, 'Kenney originals + project-created rounded foot (art approval pending)', 30, 62, 18)
    p = PACK / 'PNG' / resolution
    for i, name in enumerate(['blue_body_circle','blue_body_squircle','blue_hand_closed','blue_hand_open','face_a','blue_foot_round']):
        x = 30+i*160
        place(image,p/f'{name}.png',x,120)
        label(image, name.replace('blue_',''),x,290,14)
    label(image,'Assembly / mirrored feet / original face',30,340,20)
    cx,cy=220,440
    place(image,p/'blue_body_circle.png',cx-40*scale,cy-40*scale)
    face=place(image,p/'face_a.png',cx,cy)
    face.set_offsets(cx-face.get_width()//2,cy-face.get_height()//2)
    place(image,p/'blue_hand_closed.png',cx-64*scale,cy)
    place(image,p/'blue_hand_closed.png',cx+47*scale,cy)
    left=place(image,p/'blue_foot_round.png',cx-42*scale,cy+49*scale)
    # Mirror the pixel content about the center of this foot, not the canvas.
    left.transform_flip_simple(Gimp.OrientationType.HORIZONTAL,True,0)
    place(image,p/'blue_foot_round.png',cx+4*scale,cy+49*scale)
    for i,name in enumerate(['tile_background_tree_small','tile','tile_background_grass']):
        place(image,p/f'{name}.png',490+i*170,370)
    Gimp.Display.new(image)
    Gimp.displays_flush()
    return image
