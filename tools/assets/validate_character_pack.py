"""Read-only PNG/atlas checks. Run with: uv run --with pillow python tools/assets/validate_character_pack.py

The baseline records the supplied Kenney pixels before atlas expansion. It deliberately
ignores hidden RGB under fully transparent pixels, which image editors may normalize.
"""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/Kenney_Shape_Characters'
BASELINE = ROOT / 'art/character-feet/original_manifest.json'


def pixel_hash(image):
    rgba = image.convert('RGBA')
    data = bytes(channel for pixel in rgba.get_flattened_data()
                 for channel in (pixel if pixel[3] else (0, 0, 0, 0)))
    return hashlib.sha256(data).hexdigest()


def inspect():
    result = {}
    for resolution in ('Default', 'Double'):
        atlas_path = PACK / f'Spritesheet/spritesheet_{resolution.lower()}'
        atlas = Image.open(atlas_path.with_suffix('.png')).convert('RGBA')
        entries = ET.parse(atlas_path.with_suffix('.xml')).getroot()
        names, rectangles, records = set(), [], {}
        for entry in entries:
            name = entry.attrib['name']
            assert name not in names, f'Duplicate: {name}'
            names.add(name)
            x, y, w, h = (int(entry.attrib[k]) for k in ('x', 'y', 'width', 'height'))
            assert x >= 0 and y >= 0 and w > 0 and h > 0
            assert x+w <= atlas.width and y+h <= atlas.height, name
            for other, (a, b, c, d) in rectangles:
                assert x+w <= a or a+c <= x or y+h <= b or b+d <= y, (name, other)
            rectangles.append((name, (x, y, w, h)))
            standalone = Image.open(PACK / f'PNG/{resolution}' / name).convert('RGBA')
            assert standalone.size == (w, h), name
            standalone_hash = pixel_hash(standalone)
            atlas_hash = pixel_hash(atlas.crop((x, y, x+w, y+h)))
            records[name] = {'size': [w, h], 'standalone': standalone_hash, 'atlas': atlas_hash}
        assert names == {p.name for p in (PACK / f'PNG/{resolution}').glob('*.png')}
        result[resolution] = records
    return result


if __name__ == '__main__':
    records = inspect()
    baseline = json.loads(BASELINE.read_text())
    for resolution, entries in records.items():
        assert len(entries) == 105
        for name, original in baseline[resolution].items():
            assert entries[name] == original, f'Original changed: {resolution}/{name}'
        foot = entries['blue_foot_round.png']
        assert foot['standalone'] == foot['atlas'], 'Foot atlas differs'
        im = Image.open(PACK / f'PNG/{resolution}/blue_foot_round.png').convert('RGBA')
        assert im.getchannel('A').getextrema() == (0, 255)
        assert any(0 < a < 255 for a in im.getchannel('A').get_flattened_data()), 'Missing antialiasing'
    for name, entry in records['Default'].items():
        assert records['Double'][name]['size'] == [n*2 for n in entry['size']], name
    for name, digest in json.loads((BASELINE.parent / 'original_file_hashes.json').read_text()).items():
        assert hashlib.sha256((PACK / name).read_bytes()).hexdigest() == digest, name
    for file in (PACK / 'PNG').rglob('*.png.import'):
        settings = file.read_text()
        for expected in ('compress/mode=0', 'mipmaps/generate=true', 'process/fix_alpha_border=true', 'detect_3d/compress_to=0'):
            assert expected in settings, (file, expected)
    print('PASS: 105 entries per atlas; complete, in bounds, no overlaps; 104 original')
    print('standalone images and atlas crops preserved per resolution; transparent feet,')
    print('antialiased edges, exact foot atlas pixels, and true 2x dimensions throughout.')
