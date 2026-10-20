# Shape character face parts

The owner's face system for Shape Characters: parts that compose into expressive faces, first
used by minigame 005. The
[asset sources guide](../../docs/game-design-documents/Minigames/005/005%20-%20Asset%20sources.md)
describes the original sources. Tilt Shift 3D uses this system; [pending reviews](../../docs/pending-reviews.md)
lists what still needs the owner.

## Sources

The 26 PNGs in this folder are the owner's own work, kept unchanged: twelve reference faces,
`face_a` to `face_l`, and fourteen parts named `facial_part_*`. They are small (an open eye is
40 pixels), flat navy `#3D465D` and white, built from circles, arcs and rounded bars.

The one exception to the two colours is `face_h`'s smirk, drawn in a darker `#37393F`; its
preset uses the navy smirk part like every other face.

## Vector masters

`vector/` holds one SVG master per part, in the source's pixel units and canvas: the
fourteen supplied parts, `facial_part_eye_x`, and twenty-eight parts for emoji expressions. They
use the same construction, in navy and white, with pink `#F47DA8` for the tongue:

- circles for the eyes' whites and pupils;
- strokes with round caps for the closed eyes, the smile, the frown, the smirk and the X-eye;
- rounded polygons for the eyebrows and the eye wing: a filled path with a round-joined stroke;
- a rounded bar with two concave edges for the angry mouth, cut by a mask of two circles.

The original shapes were fitted to their source pixels; drawn at 1× they match their sources
within one source pixel. The half eyes and the winged eye are whole circles that their canvas
cuts, as in the sources. Every other master has a transparent margin of one source pixel, so
the round ends of strokes that touch a source's edge stay whole.

`facial_part_eye_x` is cut from `face_j`: a 40 × 40 box at (0, 19) around its left eye, the
same box as the open eye's, holding two crossed round-capped strokes. It matches both of
`face_j`'s eyes.

`face_c` shows the eye wing longer than `facial_part_eye_half_top_wing.png`, whose canvas cuts
it. Its master is 55 pixels wide instead of 50, holding the whole wing, with the eye where it
was.

## Runtime parts and presets

`assets/runtime/shape_faces/`, shared by every minigame, holds each master exported as a PNG at
8 times its source size with transparent edges, and `face_presets.json`. The phone can draw a
face about 280 pixels tall, about five times the sources' size. They import with mipmaps, so a face drawn
small in 3D stays smooth.

`face_presets.json` lists every part's file, its size in source pixels and its margin
(`padding`, 1 or 0), and for each preset its design size, its box aspect
(width over height) and its layers, drawn in order:

- `part`: the part's name;
- `center`: the part's centre, from the face box's centre, in face heights, X right and Y down;
- `size`: the part's drawn width and height in face heights, margin included; a part may be
  stretched, as the longer eyebrows of several faces are;
- `rotation_degrees`: clockwise, about the part's centre;
- `mirror`: flips the part horizontally about its centre before it turns.

The original `face_a` to `face_l` presets keep their supplied reference images. Forty-two
additional presets have descriptive IDs and `emoji_reference` metadata:

| Reference | Preset |
| --- | --- |
| 😀 | `face_grinning` |
| 😉 | `face_winking` |
| 😊 | `face_smiling_eyes` |
| 😐 | `face_neutral` |
| 😮 | `face_surprised` |
| 😕 | `face_confused` |
| 😞 | `face_disappointed` |
| 😦 | `face_frowning_open_mouth` |
| 🙄 | `face_rolling_eyes` |
| 🫤 | `face_diagonal_mouth` |
| ☹️ | `face_frowning` |
| 😖 | `face_confounded` |
| 😵 | `face_dizzy` |
| 😗 | `face_kissing` |
| 😙 | `face_kissing_smiling_eyes` |
| 😚 | `face_kissing_closed_eyes` |
| ☺️ | `face_warm_smile` |
| 🤨 | `face_raised_eyebrow` |
| 😏 | `face_smirking` |
| 😣 | `face_persevering` |
| 😯 | `face_hushed` |
| 🫩 | `face_exhausted` |
| 😌 | `face_relieved` |
| 😒 | `face_unamused` |
| 😔 | `face_pensive` |
| 😟 | `face_worried` |
| 😳 | `face_flushed` |
| 😵‍💫 | `face_spiral_eyes` |
| 🥴 | `face_woozy` |
| 😠 | `face_angry` |
| 🥺 | `face_pleading` |
| 😧 | `face_anguished` |
| 😁 | `face_beaming` |
| 😫 | `face_tired` |
| 😲 | `face_astonished` |
| 😩 | `face_weary` |
| 😬 | `face_grimacing` |
| 😛 | `face_tongue` |
| 😜 | `face_winking_tongue` |
| 😝 | `face_squinting_tongue` |
| 😋 | `face_savoring_food` |
| 🤪 | `face_zany` |

The emoji presets use the same navy and white, round strokes and layered construction,
with pink as the tongue's accent colour.
Their new parts have editable SVG masters; there are no supplied raster references for them.
`source_size` is their design canvas. Existing gameplay assignments still use the original IDs.

Closed, X and spiral eyes retain their shape during blinks. Tired eyes and under-eye bags are separate
layers, so the bags remain when those eyes close; side glances keep both pupils looking the
same way. Blush uses short navy strokes to preserve the palette. Glossy eyes use white
highlights; beaming and grimacing mouths use white teeth within the same navy outlines.

The reusable tongue has a broad pink fill, a navy outline, a soft rounded tip and a short
curved crease. It projects past the mouth; turning it upward at the smile's corner makes
the lip-licking pose. It is a separate layer from the mouth and eyes, so it retains its
placement during blinks.

## Export and verification

The construction scripts that fitted the shapes and the presets are one-time and stay in
ignored `scratch/`; edit the SVG masters directly. From the repository root, after
`node tools/setup.mjs`:

```powershell
node art/shape_characters_face_system_assets/export_faces.mjs
```

[export_faces.mjs](export_faces.mjs) renders every master with Playwright's Chromium into the
runtime folder, then draws each preset at 1× from those PNGs, as a game would, and compares it
with its supplied reference where one exists. Pass `--check` to verify without rewriting the
PNGs. New expressions are checked for valid parts and nonempty output; emoji recognizability
needs owner review. The script writes
[vector/verification.json](vector/verification.json) and fails when:

- any preset or part differs from its reference by more than one source pixel: some pixel at
  least half navy, or half white, has no pixel at least a quarter of that colour within one
  pixel in the other image, so that colour's edge is more than a pixel away;
- the X-eye differs from either of `face_j`'s eyes;
- any 8× PNG has a partly covered or blended pixel that touches no clear pixel or fully solid
  palette colour (navy/white, or navy/pink for the tongue), which a blurred edge would have;
- the manifest and the masters disagree.

`tests/shape_faces_test.gd` checks that the runtime PNGs and manifest are the ones the script
last verified, including the SVG hashes, that every part is 8× its design size and has a
master, and that the manifest keeps the original faces. `shape_face_emoji_test.gd` checks
the new presets on 3D quads and their blink rules. The workshop discovers them from the manifest.

New parts also need entries in the HTTP service's asset whitelist and the standalone build
policy's required runtime paths. The host and standalone tests check every manifest part.

Review the new expressions only through Godot 3D captures:

```powershell
godot --path . --script tests/shape_face_3d_visual_check.gd
```

It writes front, three-quarter and blink captures under `test-results/shape-face-emoji/`,
with enlarged studies and default paddle proportions, at most sixteen expressions per page.
Small pages keep only the rows they need. Filenames contain the first and last expression
indices. Pass `-- --start=37` to capture the five tongue expressions from the thirty-eighth
emoji preset onwards.
The reference labels use an installed
emoji font, so their appearance varies by system. Captures do not establish creative approval.
