# Tilt Shift art source

Approved raster masters and reproducible extraction for the Tilt Shift factory
art. The [runtime asset guide](../../assets/runtime/minigames/003/README.md)
defines layering, width handling and operator contact references.

## Source boundary

The four untouched PNG masters are under `sources/`:

- `gameplay-sheet.png`
- `basket-parts-sheet.png`
- `factory-parts-sheet.png`
- `blue-paper-backdrop.png`

The owner selected the ImageGen artwork on 2026-10-03 and approved importing it
on 2026-10-04. [Generation prompts](generation_prompts.json) preserve the initial
requests and refinements. The mockup guided the toy/papercraft appearance.
These PNGs are the editable raster sources; no layered authoring file exists.

The folder's `.gdignore` prevents source textures being imported by Godot.
Export presets exclude `art/**`. Normal play uses committed runtime textures
and needs none of these source files or the extraction tools.

## Extraction and regeneration

The [preparation tool](../../tools/assets/prepare_tilt_shift_art.py) requires
Python 3 with Pillow. Run from the project root:

```powershell
python tools/assets/prepare_tilt_shift_art.py build
godot --headless --editor --path . --import
python tools/assets/prepare_tilt_shift_art.py imports
godot --headless --editor --path . --import
python tools/assets/prepare_tilt_shift_art.py check
```

Measured source rectangles isolate each part; no uniform atlas grid is assumed.
Opaque cores use alpha 128, retain their two-pixel antialiased neighborhood,
and remap alpha 24–250 to 0–255. One connected core is kept per sprite; both
cores are kept for the paired falling marks. This policy is for these opaque
toy/paper props, not for translucent effects in other asset sets.

Visible source RGB is preserved exactly. Fully transparent pixels are cleared
to zero RGB; each trimmed sprite receives at least eight transparent pixels.
Paddle and grip groups share canvases and center pivots; basket layers share
their width. No source texture is resized or repainted.

The [import manifest](import_manifest.json) records original hashes, measured
rectangles, trimming, paste offsets, contact points, pivots and output hashes.
The check rebuilds pixels in memory, compares them with the committed textures,
checks visible RGB against the masters, and verifies the Godot import settings.

`build` also publishes source-free geometry to the runtime `manifest.json`. Run
`python tools/assets/prepare_tilt_shift_art.py metadata` to refresh geometry without
re-extracting images. The check verifies both manifests agree. Runtime calibration
defines the basket inner mouth at x=76..352, y=169 and the shared layer region x=8..420;
both front and back use one horizontal transform when fitted to scoring openings.

## Preview and verification

```powershell
python tools/assets/prepare_tilt_shift_art.py review
godot --headless --path . --script tests/tilt_shift_art_test.gd
node tools/check.mjs
```

The review writes an ignored contact sheet to
`test-results/tilt-shift-art/contact-sheet.png`. It composites actual PNG alpha
onto the arena blue. It is a static asset study, not gameplay evidence.

The Godot test loads all 22 textures, checks their import policies and mipmaps,
and verifies common paddle pivots, basket canvas widths and visible hand/lever
contact references. Running it establishes automated loading evidence only.

## Export-pack inspection

```powershell
godot --headless --editor --path . --export-pack "Runtime Asset Validation Pack" test-results/tilt-shift-art/art.pck
```

Create an empty project folder containing `project.godot` with `config_version=5`.
Use that folder as `--path`, the absolute
`tools/assets/verify_tilt_shift_pack.gd` path as `--script`, and after `--` pass
the absolute PCK and import-manifest paths. This isolates the pack from the
checkout so missing exported textures cannot be loaded from source files.

The helper checks every import remap, packed texture and loaded dimensions,
and runtime geometry, and rejects source masters in the pack. Pack inspection is automated evidence;
an exported Windows package still needs to run before claiming build evidence.
