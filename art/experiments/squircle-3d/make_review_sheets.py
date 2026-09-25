"""Compose review boards from Blender renders. Does not alter source artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent / 'previews'
FONT = 'C:/Windows/Fonts/segoeui.ttf'
BOLD = 'C:/Windows/Fonts/segoeuib.ttf'
BG, PANEL, INK, MUTED = '#171d2a', '#222c3c', '#f3f5fa', '#aebdd2'


def font(size, bold=False):
    try:
        return ImageFont.truetype(BOLD if bold else FONT, size)
    except OSError:
        return ImageFont.load_default()


def label(draw, xy, text, size=20, fill=INK, bold=False):
    draw.text(xy, text, fill=fill, font=font(size, bold))


def place(board, name, xy, size):
    pic = Image.open(HERE / name).convert('RGBA')
    pic = pic.resize((size, size), Image.Resampling.LANCZOS)
    board.paste(pic, xy, pic)


for view in ('front', 'three-quarter'):
    source = Image.open(HERE / f'blue-{view}-768.png').convert('RGBA')
    for size in (128, 256):
        source.resize((size, size), Image.Resampling.LANCZOS).save(HERE / f'blue-{view}-{size}.png')

board = Image.new('RGB', (1280, 1130), BG)
d = ImageDraw.Draw(board)
label(d, (48, 30), 'SQUIRCLE / TOY STUDY', 32, bold=True)
label(d, (48, 79), 'PS-056   /   Editable Blender model   /   Awaiting owner review', 18, MUTED)
for x, title, view in [(32, 'FRONT', 'front'), (656, 'THREE-QUARTER / 35°', 'three-quarter')]:
    d.rounded_rectangle((x, 126, x + 592, 694), radius=18, fill=PANEL)
    label(d, (x + 24, 145), title, 20, bold=True)
    place(board, f'blue-{view}-768.png', (x + 16, 169), 560)
label(d, (48, 730), 'SMALL-SIZE CHECK', 22, bold=True)
label(d, (48, 765), '128 px and 256 px canvases shown at native size in this sheet', 17, MUTED)
for x, view in [(70, 'front'), (690, 'three-quarter')]:
    place(board, f'blue-{view}-128.png', (x, 841), 128)
    place(board, f'blue-{view}-256.png', (x + 170, 792), 256)
    label(d, (x + 28, 985), '128 px', 17, MUTED)
    label(d, (x + 264, 1058), '256 px', 17, MUTED)
board.save(HERE / 'review-sheet.png')

colors = [('Red','E53935'),('Orange','F57C00'),('Golden Yellow','FBC02D'),('Green','43A047'),
          ('Cyan','00ACC1'),('Blue','1E88E5'),('Indigo','3949AB'),('Purple','8E24AA'),
          ('Pink','EC407A'),('Brown','8D6E63')]
board = Image.new('RGB', (1500, 860), BG)
d = ImageDraw.Draw(board)
label(d, (42, 28), 'THE EXISTING TEN-COLOR PALETTE', 30, bold=True)
label(d, (42, 75), 'Identical model, camera, and lighting. Only the shared toy material changes.', 19, MUTED)
for i, (color, hex_value) in enumerate(colors):
    x, y = 24 + (i % 5) * 296, 125 + (i // 5) * 350
    d.rounded_rectangle((x, y, x + 272, y + 328), radius=15, fill=PANEL)
    place(board, color.lower().replace(' ', '-') + '-three-quarter-768.png', (x, y), 272)
    label(d, (x + 18, y + 266), color, 20, bold=True)
    label(d, (x + 18, y + 297), '#' + hex_value, 15, MUTED)
board.save(HERE / 'palette-sheet.png')
print('Created two review sheets and four transparent small-size previews.')
