# Squircle animation study — PS-057

**Ready for owner motion review; human approval pending.** The approved PS-056
static model remains untouched in `../squircle-3d/`. This folder is a separate art
experiment. It does not replace production sprites or integrate with Godot.

## Review first

- `previews/motion-review-256.gif`: six looping clips together, at 256-pixel canvas size.
- `previews/motion-review-128.gif`: the same comparison at 128 pixels.
- `previews/palette-and-blink.png`: all ten canonical colors, neutral and blink.
- `previews/occlusion-proof.png`: a hand crossing the face, with the separate layers.
- `previews/*-beauty.png`: six unpacked, directly viewable sprite sheets.
- `previews/frames/{idle,walk,run}/{front,three-quarter}/`: individual composed PNGs.
- `export/`: original colorable/mask sequences and the authoritative `manifest.json`.

For live color, expression, size, pause, time, slow-motion, and ground-contact
controls, serve this directory locally and open `review.html`:

```powershell
python -m http.server 8057 --bind 127.0.0.1 --directory .
# Open http://127.0.0.1:8057/review.html
```

Use a local HTTP preview because browser pixel access can be restricted for
`file:` pages. The GIFs and PNGs open directly without a server. In-place GIFs are
local cycles, not world-translation previews. The optional moving ground in the
HTML page applies the recorded travel speed; green rings identify stance feet.
Front projection hides depth travel, so use the three-quarter view for contact.

## Editable Blender source

Open `squircle-animated.blend` in Blender 5.2.2. Active scene:
`PS057 | Squircle Animation Studio`. Textures are packed; no add-on or automatic
script execution is required. The original five mesh parts, face, pivots, material,
lights, softness setting, and fixed cameras are retained.

1. Select `Animation.Controls` in the Outliner.
2. Change an editor to **Dope Sheet**, then choose **Action Editor** from its mode menu.
3. Choose `PS057 | Idle`, `PS057 | Walk`, or `PS057 | Run` in the action dropdown.
4. Set the timeline end to **48**, **24**, or **16** respectively. All use **24 fps**.
5. Press Space over the viewport to play. Numpad 0 returns to the active camera.
6. In Pose Mode, the five named controls independently move the body, hands,
   and feet. The bones drive the original pivots rigidly; there is no skin deformation.
   The face follows the body, including its subtle squash and rotation.

The three actions use fake users so they remain saved even while another action
is active. Key **N+1** matches key **1** for looping but is **never exported**.
Curves use linear interpolation between authored 24-fps poses and cyclic modifiers.
Edit a duplicate action/source when experimenting. Export reads the saved action
keys; it does not regenerate them from the construction script.

| Clip | Export frames | Duration | Forward travel | Contact / feel |
|---|---:|---:|---:|---|
| Idle | 1–48 | 2 s | 0 | Both soles planted; breathing and offset hand motion |
| Walk | 1–24 | 1 s | 1.65 m/s | 62.5% stance per foot; alternating steps and gentle bob |
| Run | 1–16 | ⅔ s | 3.60 m/s | 37.5% stance per foot; flight, body compression and stronger hand gestures |

The proposed frame rate and sizes are review choices, not approved production
requirements. Blinks are independent of the locomotion actions. The page blinks
briefly every 3.7 seconds; the two-second comparison GIF has one demonstration blink.

## Render / export recipe

Run from this folder. Blender needs its bundled Python only; packing/checking needs
ordinary Python with Pillow and NumPy. The Codex workspace Python already has both.

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$python = 'C:\Users\backup pc\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $blender --background 'squircle-animated.blend' --python-exit-code 1 --python 'export_frames.py'
& $python make_previews.py
& $blender --background 'squircle-animated.blend' --python-exit-code 1 --python 'validate_animation.py'
```

Export uses **Cycles / 48 samples / denoising / AgX / seed 57 / transparent PNG
RGBA / 256×256**. Face visibility masks use 16 samples without denoising. OPTIX is
selected on this workstation's RTX 5070; CPU is used if no OPTIX device is found.
No user preferences are saved. Fixed cameras remain at orthographic scale **4.5**,
front **0° yaw / 0° elevation**, three-quarter **35° / 9°**. Framing is never fitted
per pose, action, color, or layer. No cropping or trimming is applied.

Every clip manifest records camera angles, fps, duration, explicit frame order,
time, layer paths, face placement, foot positions/stance, and the pixel location
of world **(0,0,0)**. Pixel coordinates start at the canvas top-left. At 256 pixels,
the anchors are front **(128, 204.231186)** and three-quarter
**(128, 203.292557)**. Use each recorded anchor, not the bounding-box center.
Forward is **-Y**. Translate a future runtime root by `-speed × elapsed_seconds`
along Y, or translate the ground oppositely for an in-place preview. A planted
sole's local +Y motion then cancels the root travel. No ground shadow is baked;
the eventual game scene should supply one. The optional PS-056 catcher stays disabled.

Original frame names are `0001.png` onward. `previews/sheets.json` records the
derived sheets' 8-column, row-major tile rectangles. Blank trailing cells are not
frames. `previews/*-{front,three-quarter}.png` are animated PNG loops; the `-beauty`,
`-colorable`, `-face-mask`, `-neutral`, and `-blink` files are ordinary packed sheets.

For a fresh-source replay:

```powershell
& $blender --background 'squircle-animated.blend' --python-exit-code 1 --python 'export_frames.py' -- --output recheck
& $python verify_export.py
```

For a small diagnostic, use `--output probe --clips run --views three-quarter --frames 1 5 9 13`.
Partial exports must use a separate output directory: their manifest intentionally
contains only those requested frames. Never mix a partial export into `export/`.

To add a future action: duplicate an action in Blender, pose the five controls,
add its loop-closing key, save, and add its frame count/speed/stance to `CLIPS`
in `animation_common.py`, retaining the shared 24 fps. A different fps also
requires updating the preview/compositing timing. The present validation assumes these forward stepping
clips; adapt contact definitions for jumps or gestures. `build_animations.py` is
the initial authoring recipe, **not** an exporter: it starts from the approved
static blend and overwrites `squircle-animated.blend`. Do not rerun it over owner edits.

## Tint and expression contract

There are two original per-frame raster sequences:

1. **Colorable:** the blue toy with face hidden, including all body/hand/foot
   shading and self-occlusion. A display-space palette transfer retains the blue
   source's highlights while replacing its colored component. The blue choice
   reproduces this base unchanged. All five parts receive the same operation.
2. **Face mask:** the visibility alpha of the full face rectangle, rendered with
   colorable meshes as holdouts. Hands cut holes in this mask when they cross the
   face, so face compositing does not paint eyes or mouth over a hand.

Three projected face corners per frame define an affine map (valid for these
orthographic cameras) from any 100×58 expression into the sprite. Multiply the
projected expression alpha by the mask alpha, then composite over the tinted
base. Original neutral/blink artwork remains packed and unchanged. Export also
creates two small AgX-transformed expression textures once to match the approved
face brightness. Future expressions require one texture transform, not a render
of every action/color combination. `make_previews.py` shows the reference math.

The neutral/blink per-frame layers and packed sheets are **derived preview
caches**, not new source-render requirements. A future runtime can sample the
original expression texture through the affine transform and mask instead.
The HTML review uses the derived face sheets for simple playback and recolors
the base at runtime; it never loads ten color-specific animation sets.

Limits: tint is a stylized transfer in display RGB, not a physically exact render
of ten materials. It does not reproduce color-dependent interreflection or
re-tonemap each palette color through AgX. Body shading/geometry and expressions
remain separable, but the current production `player_tint.gdshader` is tuned for
different 2D art and must **not** be applied unchanged. Face edges have normal
8-bit/mask/texture filtering approximation; no perspective camera, extreme side
view, changed expression-plane size, or production Godot compositor is validated.
PNG output is straight alpha; composite expressions with ordinary source-over.

## Add-on decision and evidence

**Skip GameSomeStudio's Sprite Sheet Generator for this exporter.** The actual
128-pixel compatibility test, pinned upstream source/license, direct comparison,
metadata and findings are in `addon-evaluation/README.md`. It can use the existing
three-quarter camera through its 0° selection, but its cardinal controls,
nested-part framing, missing layer exports, and incomplete metadata add work.
The approved static model needed a wrapper in that trial; the authored animation
file now has a real rigid control armature, so the original armature absence alone
is not the reason for rejecting the add-on.

`validation.json` measures every action at quarter-frame intervals: loop pose,
evaluated mesh sole height, floating foot/body gap, planted-foot position after root travel, and camera
containment. `export-verification.json` checks a whole fresh export, metadata,
RGBA files, untrimmed bounds and sheet tile ordering. Same-machine replay is
stable within **1/255** for colorable RGBA, expression RGBA and mask alpha, not
byte-identical under GPU rendering. Export canonicalizes unused mask RGB to
white to avoid Cycles shader-cache variation; use mask alpha for coverage. Minimum
rendered alpha margin is at least **8 pixels** in the reviewed export.

The Blender restricted profile reported inability to read user preferences and
write an optional thumbnail cache; source save, reopen and renders succeeded.
These are not texture/missing-file errors. No production engine checks are needed:
`.gdignore` keeps this experiment outside Godot import and production code is unchanged.

Owner review remains required for animation energy, foot rhythm, run hand overlap,
small-size readability, palette transfer, timing and the no-baked-shadow choice.
PS-058 must not treat this as approved art direction until that review is recorded.
