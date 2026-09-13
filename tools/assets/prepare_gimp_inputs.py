"""Lossless working copies: GIMP 3.2.6 misreads some supplied indexed PNG alpha.

Convert to RGBA without changing source files. GIMP performs the composition.
Pixel hashes verify the saved copies. These intermediates are ignored by Git.
"""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/Kenney_Shape_Characters'
OUT = ROOT / 'test-results/ps-009/gimp-rgba'
for file in PACK.rglob('*.png'):
    target = OUT / file.relative_to(PACK)
    target.parent.mkdir(parents=True, exist_ok=True)
    rgba = Image.open(file).convert('RGBA')
    rgba.save(target)
    assert Image.open(target).tobytes() == rgba.tobytes()
print('Prepared pixel-identical RGBA working copies for GIMP.')
