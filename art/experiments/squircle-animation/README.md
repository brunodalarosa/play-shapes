# Squircle v1 model and animation source

`squircle-animated.blend` is the canonical editable model and saved idle/walk/run
source. PS-079 replaces the owner-approved PS-064 gloves with smooth toy spheres.
**The spherical hand proportions and motion await owner approval.** The canonical
runtime sheets are in `assets/runtime/animated_characters/squircle/v1/`; Playground,
Bubbles, the F12 Animation Lab and phone setup share that set.

## Review and recovery

- `previews/ps079-before-after-{256,128}.{gif,png}`: all three actions in both views,
  synchronized against the preserved PS-064 gloves.
- `previews/motion-review-{256,128}.gif`: all six revised loops at real review sizes.
- `previews/review-sheet.png`, `palette-and-blink.png`, `hand-detail-sphere.png`:
  revised proportions, ten player colors/expressions, and sphere surface detail.
- `previews/occlusion-proof.png`: separate colorable, visibility mask and face layers.
- `previews/frames/{idle,walk,run}/{front,three-quarter}/`: every composed frame.
- `export/`: complete raw colorable/mask sequences and authoritative manifest.
- `before-ps079/`: byte-preserved pre-revision Blender source, README and previews.
  This is recovery/comparison evidence, never a runtime consumer.
- `before-ps064/`, `before-inward-ps064/`, older before-after/walk-options/hand-detail
  media and PS-064 JSON records are historical evidence. They describe gloves.

The unchanged interactive `review.html` supports action, view, size, palette,
expression, pause, time, slow motion and ground-contact review:

```powershell
python -m http.server 8057 --bind 127.0.0.1 --directory .
# Open http://127.0.0.1:8057/review.html
```

Local HTTP avoids file-page pixel-access restrictions. In-place loops preserve
recorded locomotion speeds; the optional moving ground illustrates sole contact.

## Editable source and sizing

Open the saved source in Blender 5.2.2; active scene is
`PS057 | Squircle Animation Studio`. Textures are packed. No add-on or automatic
script execution is required. `Hand.L` and `Hand.R` each have a smooth-shaded
48-segment, 32-ring UV sphere centered on the unchanged wrist pivot. There are no
fingers, thumbs, cuffs, glove modifiers, hand shape keys, curl drivers or curl
animation channels. Both hands use the original blue toy material and tint path.
The floating limbs, five rigid controls and all remaining action curves are retained.

The proposed diameter is **0.60 m**, compared with **2.00 m body width** and
**0.92 m foot length**: **30%** and **65.22%**, respectively. It reads as a rounded
toy piece smaller than the feet, roughly 34 pixels across in the 256-pixel front
render, or 17 pixels at 128. No hand-pivot placement/travel adjustment was needed.
For a different diameter, edit each Hand mesh separately: in Edit Mode select all
vertices, use Median Point (the sphere center is its origin), and uniformly scale
by `desired_diameter / current_diameter`. Apply the same factor to the other hand.
Keep object scale at one and update scene custom property `Hand diameter m` for
validation and documentation. Save, then regenerate the complete export below.

Select `Animation.Controls`, use Dope Sheet > Action Editor, and choose
`PS057 | Idle`, `PS057 | Walk`, or `PS057 | Run`. Set end to 48, 24, or 16;
all use 24 fps. Space plays; Numpad 0 shows the saved camera. Pose Mode edits the
five independent rigid controls. The face follows the body. Actions use fake users,
linear interpolation and cyclic modifiers; key N+1 equals key 1 and is never exported.

| Clip | Frames | Duration | Forward travel | Contact |
|---|---:|---:|---:|---|
| Idle | 1–48 | 2 s | 0 | Both soles planted, breathing and offset hand motion |
| Walk | 1–24 | 1 s | 1.65 m/s | 62.5% stance per foot |
| Run | 1–16 | 2/3 s | 3.60 m/s | 37.5% stance, flight and opposing hand swing |

`simplify_hands_ps079.py` records the one-time migration from
`before-ps079/squircle-animated.blend`. It asserts equality of all remaining saved
curves and all five control matrices at every frame and loop key; sizing and hashes
are in `ps079-revision.json`. Do not reapply it over later owner edits.
`build_animations.py`, `hand_model.py`, `revise_hands.py`, `ps064_hands.py`,
`revise_ps064.py`, `turn_palms_inward.py`, and `mark_squircle_v1.py` are historical
construction/approval recipes. Never run them over the revised source.

## Reproducible export and import

Run these commands from this folder, using Blender and a Python with Pillow/NumPy:

```powershell
& $blender --background squircle-animated.blend --python-exit-code 1 --python export_frames.py
& $python make_previews.py
& $blender --background squircle-animated.blend --python-exit-code 1 --python render_hand_detail.py
& $python review_ps064.py --task PS-079
& $blender --background squircle-animated.blend --python-exit-code 1 --python validate_animation.py
& $blender --background squircle-animated.blend --python-exit-code 1 --python export_frames.py -- --output recheck
& $python verify_export.py
```

The existing `review_ps064.py --task PS-079` workflow copies all 18 derived
colorable/neutral/blink sheets and writes the compact canonical runtime manifest,
plus `ps079-runtime-sync.json` with source and sheet hashes. It preserves historical
PS-064 comparisons. `--hand-curl` is only for archived glove sources; spherical
hands reject it. Partial exports require a separate output directory, for example
`--output probe --clips run --views three-quarter --frames 1 5 9 13`.

From the implementation root, refresh the icons and import the canonical assets:

```powershell
node web/scripts/generate_pwa_icons.mjs
godot --headless --editor --path . --import
godot --headless --path . --script tests/squircle_animation_lab_test.gd
godot --headless --path . --script tests/lobby_playground_world_test.gd
godot --headless --path . --script tests/bubbles_presentation_test.gd
godot --path .
```

F12 > Animation Lab reviews all clips, colors, expressions and both sizes. The
phone HTTP routes serve the same canonical idle-front sheets and manifest directly;
there is no extra phone animation copy. The three generated `web/public/app-icon-*.png`
icons must be refreshed after art changes. No browser code/input changes are needed.

## Render, timing, layers and anchors

Cycles, 48 samples, denoising, AgX, seed 57, straight-alpha transparent RGBA PNG,
256×256 untrimmed tiles; face visibility masks use 16 samples without denoising.
OPTIX is selected if available, otherwise CPU; no user preferences are saved.
Fixed orthographic scale is 4.5: front 0° yaw/0° elevation; three-quarter 35°/9°.
Framing never fits individual poses, actions, layers or colors.

The source manifest records frame order, time, camera, projected face corners,
foot stance/positions and the ground-origin anchor. Anchors at 256 are front
(128, 204.231186), three-quarter (128, 203.292557); use these rather than bounding-box
centers. Forward is -Y; root travel is `-speed × elapsed_seconds` along Y. The optional
shadow catcher stays disabled; game scenes supply ground shadows. Sheets have eight
columns in row-major order. Blank trailing cells are never animation frames.

Colorable layers include body, both hands, feet, shading and self-occlusion with
the face hidden. A display-space blue-basis palette transfer preserves highlights
while tinting all five parts together. Neutral/blink remain independent untinted
face layers. Three projected corners give the expression affine transform; rendered
mask alpha clips it against body/hand occlusion. Mask RGB is canonical white.
Packed artwork and the two exported AgX expression textures remain unchanged.
Tint is a stylized RGB transfer, not a physical rerender of ten material colors.

`validation.json` checks loop seams, sole contact/travel, floating foot/body gaps,
both-camera containment, sphere shape and obsolete-dependency removal, and hand
body/floor/foot clearance at quarter-frame intervals. Foot clearance conservatively
uses the foot's world AABB against each sphere. `export-verification.json` checks
a complete independently reopened export, identical metadata, frame ordering,
packed tiles, alpha margins and consumed-channel replay tolerance <=1/255.
These are desktop technical evidence; physical-phone checks and owner visual
approval are separate and pending. Optional Blender thumbnail-cache and Godot
editor-settings write warnings do not imply asset/render/import failure.

Source art and review evidence are excluded from Godot import by `.gdignore`.
Only the curated runtime directory is consumed by the game. The previous sprite-sheet
add-on evaluation remains in `addon-evaluation/README.md`; the established exporter
retains the needed cameras, tint/expression separation, fixed framing and metadata.
