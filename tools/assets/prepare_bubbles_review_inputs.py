"""Pixel-identical RGBA copies for GIMP's indexed-PNG alpha issue; needs Pillow.

Only existing Shape Character reference art is normalized, in ignored output.
Bubbles art extraction and review composition are performed in GIMP.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
for relative in ['bodies/circle.png', 'faces/neutral.png', 'hands/open.png', 'feet/round.png']:
    source = ROOT/'assets/runtime/shape_characters'/relative
    target = ROOT/'test-results/ps-036-038/gimp-shapes'/relative
    target.parent.mkdir(parents=True, exist_ok=True)
    rgba = Image.open(source).convert('RGBA')
    rgba.save(target)
    assert Image.open(target).tobytes() == rgba.tobytes()
print('Prepared four pixel-identical GIMP reference copies.')
