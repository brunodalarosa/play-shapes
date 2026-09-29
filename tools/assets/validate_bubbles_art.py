"""Validate exported PNGs and Godot import settings; requires Pillow.

Read-only validation. Source comparison requires owner-provided files.
The independent export-pack check uses verify_bubbles_pack.gd.
"""
from hashlib import sha256
import json
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / 'assets/runtime/minigames/bubbles_and_jellyfishes'
parser = argparse.ArgumentParser(description='Validate Bubbles runtime art against owner-provided source files.')
parser.add_argument('--source-dir', type=Path, required=True, help='directory containing the original Bubbles sprite sheet and background')
SOURCE = parser.parse_args().source_dir
manifest = json.loads((ROOT/'art/bubbles/extraction_manifest.json').read_text())
for name in manifest['source_sha256']:
    if not (SOURCE / name).is_file():
        parser.error(f'missing {SOURCE / name}; request the source art from the owner and pass --source-dir PATH')
try:
    from PIL import Image
except ImportError as error:
    parser.error('Pillow is required for source-art validation; install it with python -m pip install Pillow')
entries = manifest['assets']
assert len(entries) == 18
assert len({e['path'] for e in entries}) == len(entries)
assert {str(p.relative_to(RUNTIME)).replace('\\','/') for p in RUNTIME.rglob('*.png')} == {e['path'] for e in entries}
for name, expected in manifest['source_sha256'].items():
    assert sha256((SOURCE/name).read_bytes()).hexdigest() == expected, name
sheet = Image.open(SOURCE/manifest['source_sheet']).convert('RGBA')
for entry in entries:
    path = RUNTIME/entry['path']
    assert sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
    image = Image.open(path).convert('RGBA')
    assert list(image.size) == entry['size'], path
    alpha = image.getchannel('A')
    if 'sheet_rect' in entry:
        assert alpha.getbbox() == (8,8,image.width-8,image.height-8), path
        values = set(alpha.get_flattened_data())
        assert 0 in values and 255 in values and any(0<a<255 for a in values), path
        x,y,_,_ = entry['sheet_rect']
        left,top,w,h = entry['trim_in_rect']
        source = sheet.crop((x+left,y+top,x+left+w,y+top+h))
        exported = image.crop((8,8,8+w,8+h))
        for original,cleaned in zip(source.get_flattened_data(),exported.get_flattened_data()):
            if cleaned[3]:
                assert original[:3] == cleaned[:3], f'RGB changed: {path}'
    elif entry['path'].endswith('far_background.png'):
        assert alpha.getextrema() == (255,255)
        assert image.tobytes() == Image.open(SOURCE/manifest['source_background']).convert('RGBA').tobytes()
    else:
        # Overlay center stays empty; alpha still exists at the framing edges.
        assert alpha.getbbox() is not None
        assert alpha.crop((260,200,1660,860)).getbbox() is None
    settings = path.with_suffix('.png.import').read_text()
    for setting in ['compress/mode=0','mipmaps/generate=true','process/fix_alpha_border=true',
                    'process/premult_alpha=false','detect_3d/compress_to=0']:
        assert setting in settings, f'{path}: {setting}'
print('BUBBLES_ART_OK: 18 PNGs; hashes, dimensions, source RGB, alpha padding, overlay center and imports verified.')
