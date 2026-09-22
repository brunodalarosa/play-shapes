"""Run inside GIMP 3 via MCP after setting PLAY_SHAPES_ROOT.

Uses GIMP/GEGL for source reads, sprite extraction, alpha cleanup and PNG export.
Original artwork is never modified. Source files live in the parent design vault.
"""
from collections import deque
from hashlib import sha256
import json
from pathlib import Path
from gi.repository import Gimp, Gegl, Gio

ROOT = Path(PLAY_SHAPES_ROOT)
SOURCE = ROOT.parent / 'Minigames/002/Generated Mockups'
OUT = ROOT / 'assets/runtime/minigames/bubbles_and_jellyfishes'
ART = ROOT / 'art/bubbles'
SHEET = 'bubbles-paper-ghibli-master-sprite-sheet.png'
BACKGROUND = 'bubbles-paper-craft-far-background-fhd.png'
# Rectangles in the original 1374 x 1145 sheet, not a uniform grid.
REGIONS = [
    ('jellyfish/jellyfish_small', (48, 311, 140, 174)),
    ('jellyfish/jellyfish', (230, 291, 170, 207)),
    ('jellyfish/jellyfish_drifting', (442, 291, 185, 213)),
    ('pufferfish/pufferfish_left', (636, 276, 247, 222)),
    ('pufferfish/pufferfish_right', (896, 276, 234, 222)),
    ('environment/kelp', (10, 700, 202, 249)),
    ('environment/sea_plant', (211, 751, 222, 198)),
    ('environment/coral_red', (430, 722, 235, 227)),
    ('environment/sponge_purple', (673, 734, 210, 215)),
    ('environment/rocks', (883, 789, 275, 160)),
    ('environment/shell_starfish', (1133, 771, 241, 178)),
    ('environment/sponge_orange', (10, 958, 195, 187)),
    ('environment/coral_pink', (202, 948, 210, 197)),
    ('environment/hanging_reef', (405, 945, 246, 200)),
    ('environment/reef_shelf', (631, 945, 310, 200)),
]


def export_png(image, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    proc = Gimp.get_pdb().lookup_procedure('file-png-export')
    config = proc.create_config()
    for name, value in {'run-mode': Gimp.RunMode.NONINTERACTIVE,
                        'image': image, 'file': Gio.File.new_for_path(str(path)),
                        'compression': 9, 'time': False, 'include-exif': False,
                        'include-xmp': False, 'include-iptc': False,
                        'include-color-profile': True}.items():
        config.set_property(name, value)
    result = proc.run(config)
    assert result.index(0) == Gimp.PDBStatusType.SUCCESS, str(result.index(0))


def clean_alpha(data, width, height):
    """Keep the principal opaque island and a two-pixel antialiased fringe.

    The AI sheet has faint detached colored noise. Identify connected cores at
    alpha >= 128, retain the largest connected component in each crop,
    then retain their two-pixel neighborhood. Remap alpha 24..250 to 0..255;
    RGB paper texture is unchanged. This policy is for opaque paper props only.
    """
    core = bytearray(a >= 128 for a in data[3::4])
    components = []
    for start in range(width * height):
        if not core[start]:
            continue
        core[start] = 0
        queue = deque([start])
        component = []
        while queue:
            p = queue.popleft()
            component.append(p)
            x, y = p % width, p // width
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height:
                        q = ny * width + nx
                        if core[q]:
                            core[q] = 0
                            queue.append(q)
        components.append(component)
    assert components
    keep = bytearray(width * height)
    for component in [max(components, key=len)]:
        for p in component:
            x, y = p % width, p // width
            for yy in range(max(0, y-2), min(height, y+3)):
                for xx in range(max(0, x-2), min(width, x+3)):
                    keep[yy*width+xx] = 1
    for p in range(width*height):
        a = data[p*4+3]
        data[p*4+3] = max(0, min(255, round((a-24)*255/226))) if keep[p] else 0
    return data


def extract_all():
    source = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(str(SOURCE/SHEET)))
    drawable = source.get_layers()[0]
    entries = []
    for name, (x, y, w, h) in REGIONS:
        rect = Gegl.Rectangle.new(x, y, w, h)
        data = bytearray(drawable.get_buffer().get(rect, 1.0, "R'G'B'A u8", Gegl.AbyssPolicy.NONE))
        data = clean_alpha(data, w, h)
        visible = [p for p, a in enumerate(data[3::4]) if a]
        left, right = min(p%w for p in visible), max(p%w for p in visible)+1
        top, bottom = min(p//w for p in visible), max(p//w for p in visible)+1
        ow, oh = right-left+16, bottom-top+16
        pixels = bytearray(ow*oh*4)
        for sy in range(top, bottom):
            start = ((sy-top+8)*ow+8)*4
            pixels[start:start+(right-left)*4] = data[(sy*w+left)*4:(sy*w+right)*4]
        image = Gimp.Image.new(ow, oh, Gimp.ImageBaseType.RGB)
        layer = Gimp.Layer.new(image, name, ow, oh, Gimp.ImageType.RGBA_IMAGE, 100, Gimp.LayerMode.NORMAL)
        image.insert_layer(layer, None, 0)
        buffer = layer.get_buffer()
        buffer.set(Gegl.Rectangle.new(0, 0, ow, oh), "R'G'B'A u8", bytes(pixels))
        buffer.flush()
        layer.update(0, 0, ow, oh)
        path = OUT / (name+'.png')
        export_png(image, path)
        entries.append({'path': name+'.png', 'size': [ow, oh], 'sheet_rect': [x,y,w,h],
                        'trim_in_rect': [left,top,right-left,bottom-top], 'padding': 8,
                        'pivot_normalized': [0.5,0.5], 'sha256': sha256(path.read_bytes()).hexdigest()})
        image.delete()
    source.delete()
    background = Gimp.file_load(Gimp.RunMode.NONINTERACTIVE, Gio.File.new_for_path(str(SOURCE/BACKGROUND)))
    path = OUT / 'environment/far_background.png'
    export_png(background, path)
    entries.insert(0, {'path': 'environment/far_background.png', 'size': [background.get_width(),background.get_height()],
                       'padding': 0, 'sha256': sha256(path.read_bytes()).hexdigest()})
    background.delete()
    ART.mkdir(parents=True, exist_ok=True)
    manifest = {'source_sheet': SHEET, 'source_background': BACKGROUND,
                'source_sha256': {name: sha256((SOURCE/name).read_bytes()).hexdigest() for name in (SHEET,BACKGROUND)},
                'tool': 'GIMP 3.2.6 / GEGL through MCP', 'assets': entries}
    (ART/'extraction_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    Gimp.displays_flush()
    print(json.dumps(entries))


extract_all()
