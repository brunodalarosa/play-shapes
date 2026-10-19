# Shape character face parts

The owner's face system for Shape Characters: parts that compose into expressive faces, first
used by minigame 005. The
[asset sources guide](../../docs/game-design-documents/Minigames/005/005%20-%20Asset%20sources.md)
decides the change. Nothing here is used by a scene yet; [pending reviews](../../docs/pending-reviews.md)
lists what still needs the owner.

## Sources

The 26 PNGs in this folder are the owner's own work, kept unchanged: twelve reference faces,
`face_a` to `face_l`, and fourteen parts named `facial_part_*`. They are small (an open eye is
40 pixels), flat navy `#3D465D` and white, built from circles, arcs and rounded bars.

The one exception to the two colours is `face_h`'s smirk, drawn in a darker `#37393F`; its
preset uses the navy smirk part like every other face.

## Vector masters

`vector/` holds one SVG master per part, in the source's pixel units and canvas: the
fourteen supplied parts and `facial_part_eye_x`. Each is made of the shapes the parts were
drawn with, in navy and white only:

- circles for the eyes' whites and pupils;
- strokes with round caps for the closed eyes, the smile, the frown, the smirk and the X-eye;
- rounded polygons for the eyebrows and the eye wing: a filled path with a round-joined stroke;
- a rounded bar with two concave edges for the angry mouth, cut by a mask of two circles.

Each shape was fitted to its source's pixels, and drawn at 1× every part matches its source
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
face about 280 pixels tall, about five times the sources' size.

`face_presets.json` lists every part's file, its size in source pixels and its margin
(`padding`, 1 or 0), and for each of `face_a` to `face_l` its source size, its box aspect
(width over height) and its layers, drawn in order:

- `part`: the part's name;
- `center`: the part's centre, from the face box's centre, in face heights, X right and Y down;
- `size`: the part's drawn width and height in face heights, margin included; a part may be
  stretched, as the longer eyebrows of several faces are;
- `rotation_degrees`: clockwise, about the part's centre;
- `mirror`: flips the part horizontally about its centre before it turns.

## Export and verification

The construction scripts that fitted the shapes and the presets are one-time and stay in
ignored `scratch/`; edit the SVG masters directly. From the repository root, after
`node tools/setup.mjs`:

```powershell
node art/shape_characters_face_system_assets/export_faces.mjs
```

[export_faces.mjs](export_faces.mjs) renders every master with Playwright's Chromium into the
runtime folder, then draws each preset at 1× from those PNGs, as a game would, and compares it
with its reference face. Pass `--check` to verify without rewriting the PNGs. It writes
[vector/verification.json](vector/verification.json) and fails when:

- any preset or part differs from its reference by more than one source pixel: some pixel at
  least half navy, or half white, has no pixel at least a quarter of that colour within one
  pixel in the other image, so that colour's edge is more than a pixel away;
- the X-eye differs from either of `face_j`'s eyes;
- any 8× PNG has a partly covered or blended pixel that touches no clear, fully navy or fully
  white pixel, which a blurred edge would have;
- the manifest and the masters disagree.

`tests/shape_faces_test.gd` checks that the runtime PNGs and manifest are the ones the script
last verified, that every part is 8× its source and has a master, and that the manifest holds
the twelve faces.
