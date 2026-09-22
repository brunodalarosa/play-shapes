# Bubbles static-art review

PS-036 / PS-037 / PS-038, prepared 2026-09-22. Runtime art is under
[`assets/runtime/minigames/bubbles_and_jellyfishes/`](../../assets/runtime/minigames/bubbles_and_jellyfishes/README.md).

## Review images

- [All extracted sprites at native resolution](sprite-contact-sheet.png)
- [Three-layer environment at 1920×1080](environment-review-fhd.png)
- [Ten-player FHD readability study](arena-review-10-players-fhd.png)
- [Creature size, white-blink, rotation and phone composition samples](creature-size-review.png)
- [Editable GIMP arena review](arena-review.xcf)

These are static art studies, not screenshots of implemented Bubbles gameplay.
Bubble circles, names, timer and warning chevrons are review graphics. Existing
Shape Character art is used for scale. Each bubble shows five jellyfish as a
sample cap, not an approved tuning decision. The phone panel is a composition
study; it does not prove browser or physical-device readability.

Technical review found clean silhouettes on both dark and light backgrounds,
distinct spiky hazards and tentacled collectibles, and an open central play area.
The owner approved all three art sets on 2026-09-22 after receiving these reviews.
This acceptance does not establish physical-phone or moving-gameplay validation.
The generator/model and any separate license/attribution terms remain unspecified.

## Extraction

GIMP/GEGL reads the untouched source sheet. The extraction script uses individually
measured source rectangles, keeps the largest connected alpha core in each crop,
retains a two-pixel antialiased fringe, and remaps alpha 24–250 to 0–255 to remove
detached AI speckles. Visible RGB paper texture remains identical to the source.
Each sprite is trimmed and padded by eight pixels. This cleanup is specific to
opaque paper props, and must not be applied to translucent bubbles or VFX.

To regenerate, keep the original source files at the same path in the parent
design vault. First run `python tools/assets/prepare_bubbles_review_inputs.py`
(Pillow required) for pixel-identical RGBA working copies of existing player art;
this avoids GIMP's indexed-PNG alpha display issue. Through GIMP's Python
console/MCP, set `PLAY_SHAPES_ROOT` to the
absolute implementation checkout, then execute the files in this order:

```python
exec(compile(open(PLAY_SHAPES_ROOT + '/tools/assets/extract_bubbles_gimp.py', encoding='utf-8').read(), 'extract_bubbles_gimp.py', 'exec'))
exec(compile(open(PLAY_SHAPES_ROOT + '/tools/assets/compose_bubbles_gimp.py', encoding='utf-8').read(), 'compose_bubbles_gimp.py', 'exec'))
compose_all()
```

Only the extraction script runs on load. The composition script exposes individual
functions for bounded MCP calls: `build_overlays()`, `contact_sheet()`,
`size_review()` and `arena_review()`. A long GIMP operation may outlast an MCP
timeout; inspect output timestamps/GIMP before retrying. Exports overwrite only
this asset set and its review files; source images are never saved over.

## Validation

From the implementation root:

```powershell
python tools/assets/validate_bubbles_art.py
godot --headless --editor --path . --import
godot --headless --path . --export-pack "Play Shapes Windows Release" test-results/ps-036-038/bubbles.pck
```

The Python validator requires Pillow. It verifies all 18 PNGs, source and export
hashes, dimensions, unchanged visible source RGB, antialiased eight-pixel padding,
the overlays' empty center, and Godot import settings.

For pack inspection, create an empty project directory containing a `project.godot`
with `config_version=5`. Run Godot with that directory as `--path`, and pass the
absolute `tools/assets/verify_bubbles_pack.gd` path to `--script`. After `--`, pass
the absolute PCK path and absolute `art/bubbles/extraction_manifest.json` path.
This isolation prevents source files from masking missing exported resources.

Recorded results on Godot 4.7.2:

- `BUBBLES_ART_OK`: all 18 PNGs and their import policies passed.
- Normal-profile headless import and Windows release PCK export exited 0 with no
  script parse or texture import errors. Shutdown reported 68 leaked ObjectDB
  instances / 33 resources still in use; this is separate from import success.
- `BUBBLES_PACK_OK: 18 textures loaded from isolated export pack`. Each packed
  `.import` remap, destination `.ctex` and loaded texture dimensions were checked.
- GIMP visual review covered light/dark edges, FHD composition, small collectibles,
  white silhouettes and rotated hazards. The owner explicitly approved all three
  art sets on 2026-09-22.

Ignored logs and PCK are under `test-results/ps-036-038/`. This verifies pack
contents, not a playable Bubbles standalone build; the minigame is not implemented
by these tasks.
