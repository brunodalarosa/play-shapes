# Play Shapes additions (PS-009)

The supplied Shape Characters 1.0 pack is by **Kenney** (www.kenney.nl), CC0.
`License.txt`, `Preview.png`, `Sample.png`, the vector overview, and all 208
original standalone PNGs are preserved byte-for-byte. Kenney did not create
or endorse the additional feet.

`PNG/Default/blue_foot_round.png` (40 x 24) and
`PNG/Double/blue_foot_round.png` (80 x 48) are **Play Shapes project-created
additions**, authored for this task in GIMP 3.2.6 using Bezier paths, a blue
gradient, and a separate translucent top highlight. The project owner explicitly
approved the foot art on 2026-09-13. One silhouette is mirrored for the two feet;
no pose library is implied.
The layered source is `art/character-feet/blue_foot_round.xcf` at repository root.

The spritesheets are expanded with a bottom shelf. All original rectangles
retain their coordinates, dimensions, names, and visible RGBA pixels:

| Atlas | Canvas | New foot rectangle (x, y, width, height) |
| --- | --- | --- |
| Default | 577 x 605 | 2, 579, 40, 24 |
| Double | 1154 x 1210 | 4, 1158, 80, 48 |

The PNG atlases use RGBA instead of indexed color after GIMP composition.
RGB values under fully transparent pixels may be normalized; the read-only
validator compares visible pixels and alpha, including antialiasing.

Review sheets and runtime evidence are in `art/character-feet/`. See
`DEVELOPMENT.md` for import settings, tint limitations, authoring, validation,
and the distinction between technical verification and human art approval.
