# Shape character face parts

The owner's face system for Shape Characters: parts that compose into expressive faces, first
used by minigame 005. The
[asset sources guide](../../docs/game-design-documents/Minigames/005/005%20-%20Asset%20sources.md)
describes the original sources. Tilt Shift 3D uses this system; [pending reviews](../../docs/pending-reviews.md)
lists what still needs the owner.

## Sources

The 26 PNGs in this folder are the owner's own work, kept unchanged: twelve reference faces,
named for their emoji counterparts, and fourteen parts named `facial_part_*`. They are small (an open eye is
40 pixels), flat navy `#3D465D` and white, built from circles, arcs and rounded bars.

The one exception to the two colours is `face_smirking`'s smirk, drawn in a darker `#37393F`; its
preset uses the navy smirk part like every other face.

## Vector masters

`vector/` holds one SVG master per part, in the source's pixel units and canvas: the
fourteen supplied parts, `facial_part_eye_x`, and twenty-nine parts drawn for the emoji
expressions. They all use the supplied parts' construction, in navy and white:

- circles for the eyes' whites and pupils;
- strokes with round caps for the closed eyes, the smile, the frown, the smirk and the X-eye;
- rounded polygons for the eyebrows and the eye wing: a filled path with a round-joined stroke;
- a rounded bar with two concave edges for the angry mouth, cut by a mask of two circles.

The only other colour is the tongue's pink `#F47DA8`, which always hangs from a navy mouth.
Tears, sweat, drool, the sleep bubble and the halo are white, so they read on every character
colour without an outline.

The original shapes were fitted to their source pixels; drawn at 1× they match their sources
within one source pixel. The half eyes and the winged eye are whole circles that their canvas
cuts, as in the sources. Every other master has a transparent margin of one source pixel, so
the round ends of strokes that touch a source's edge stay whole.

`facial_part_eye_x` is cut from `face_dizzy`: a 40 × 40 box at (0, 19) around its left eye, the
same box as the open eye's, holding two crossed round-capped strokes. It matches both of
`face_dizzy`'s eyes.

`face_content` shows the eye wing longer than `facial_part_eye_half_top_wing.png`, whose canvas cuts
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

The twelve original presets keep their supplied reference images, each named for the emoji it
reads as. Fifty-two more presets are drawn from the same parts. Every preset has a descriptive ID
and `emoji_reference` metadata:

| Reference | Preset | Source |
| --- | --- | --- |
| 🙂 | `face_slightly_smiling` | Original |
| 😒 | `face_unamused` | Original |
| 😌 | `face_content` | Original |
| 🤨 | `face_suspicious` | Original |
| 😼 | `face_scheming` | Original |
| 😈 | `face_mischievous` | Original |
| 😤 | `face_furious` | Original |
| 😏 | `face_smirking` | Original |
| 😟 | `face_worried` | Original |
| 😵 | `face_dizzy` | Original |
| 😞 | `face_disappointed` | Original |
| 😊 | `face_smiling_eyes` | Original |
| 😀 | `face_grinning` | Drawn |
| 😉 | `face_winking` | Drawn |
| 😐 | `face_neutral` | Drawn |
| 😮 | `face_surprised` | Drawn |
| 😕 | `face_confused` | Drawn |
| 😦 | `face_frowning_open_mouth` | Drawn |
| 🙄 | `face_rolling_eyes` | Drawn |
| 🫤 | `face_diagonal_mouth` | Drawn |
| ☹️ | `face_frowning` | Drawn |
| 😖 | `face_confounded` | Drawn |
| 😗 | `face_kissing` | Drawn |
| 😙 | `face_kissing_smiling_eyes` | Drawn |
| 😚 | `face_kissing_closed_eyes` | Drawn |
| ☺️ | `face_warm_smile` | Drawn |
| 🤨 | `face_raised_eyebrow` | Drawn |
| 😣 | `face_persevering` | Drawn |
| 😯 | `face_hushed` | Drawn |
| 🫩 | `face_exhausted` | Drawn |
| 😌 | `face_relieved` | Drawn |
| 😔 | `face_pensive` | Drawn |
| 😳 | `face_flushed` | Drawn |
| 😵‍💫 | `face_spiral_eyes` | Drawn |
| 🥴 | `face_woozy` | Drawn |
| 😠 | `face_angry` | Drawn |
| 🥺 | `face_pleading` | Drawn |
| 😧 | `face_anguished` | Drawn |
| 😁 | `face_beaming` | Drawn |
| 😫 | `face_tired` | Drawn |
| 😲 | `face_astonished` | Drawn |
| 😩 | `face_weary` | Drawn |
| 😬 | `face_grimacing` | Drawn |
| 😛 | `face_tongue` | Drawn |
| 😜 | `face_winking_tongue` | Drawn |
| 😝 | `face_squinting_tongue` | Drawn |
| 😋 | `face_savoring_food` | Drawn |
| 🤪 | `face_zany` | Drawn |
| 😂 | `face_joy_tears` | Drawn |
| 😅 | `face_grinning_sweat` | Drawn |
| 😎 | `face_sunglasses` | Drawn |
| 😍 | `face_heart_eyes` | Drawn |
| 🥲 | `face_smiling_tear` | Drawn |
| 🤩 | `face_star_struck` | Drawn |
| 😥 | `face_sad_relieved` | Drawn |
| 😪 | `face_sleepy` | Drawn |
| 😴 | `face_sleeping` | Drawn |
| 🤤 | `face_drooling` | Drawn |
| 😓 | `face_downcast_sweat` | Drawn |
| 🤑 | `face_money_mouth` | Drawn |
| 😢 | `face_crying` | Drawn |
| 😭 | `face_loudly_crying` | Drawn |
| 🥹 | `face_holding_back_tears` | Drawn |
| 😇 | `face_halo` | Drawn |

## Drawing a new face

The drawn presets follow the measurements of the originals, so every face reads as one set:

- Eyes are 40 pixels across, their centres 60 pixels apart on one eye line. An open eye is a
  white circle with a navy pupil 24 pixels across; other eyes change the pupil or cut the
  circle, never the size.
- Lines are 8 pixels with round caps, as in the supplied smile, frown and closed eyes. Nothing
  is drawn thinner than 6 pixels, and there are no outlines, hatching or small sparkles.
- Mouths are about 32 pixels wide, centred 31 pixels below the eye line. Open mouths are filled
  navy shapes; teeth are white bars inside them, or a whole white mouth.
- Brows are the supplied slabs, `eyebrow_a` or `eyebrow_d`, level or turned up to 15° at the
  inner end.

Every preset shares one frame: `face_slightly_smiling`'s 100 × 58 pixels, with the eye line 9
pixels above its centre. A face drawn at a given height therefore has the same eye size and eye
line whatever its expression; brows, tears, the sleep marks and the halo may reach outside the
frame. Each original's reference image sits at its own place in the frame, which
`export_faces.mjs` lists.

Closed eyes, X-eyes, squeezed eyes, spirals, hearts, stars and dollar signs keep their shape
during blinks, and so do sunglasses. Decorations and the tongue are layers of their own and
keep their place while open eyes close. Dollar signs share one reading direction.

## Export and verification

The construction scripts that fitted the shapes and laid out the presets are one-time and stay
in ignored `scratch/`; edit the SVG masters and the manifest directly. From the repository root, after
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
- the X-eye differs from either of `face_dizzy`'s eyes;
- any 8× PNG has a partly covered or blended pixel that touches no clear pixel or fully solid
  colour from its part palette, navy and white or the tongue's pink, which a blurred edge
  would have;
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
indices. Pass `-- --start=42` to capture the sixteen decorated expressions from the forty-third
emoji preset onwards.
The reference labels use an installed
emoji font, so their appearance varies by system. Captures do not establish creative approval.
