# Tilt Shift art

Reusable toy/papercraft factory textures for minigame 003. These assets supply
presentation parts; the arena, physics, phone delivery and character animation
consume them separately.

## Inventory

| Folder | Parts | Use |
| --- | --- | --- |
| `environment/` | Blue paper backdrop and two side rails | Quiet arena surface and separate left/right framing. |
| `paddles/` | Orange, blue and neutral paddles | One shared paddle source, common canvas and center pivot for host and phone. |
| `gameplay/` | Ball, blank player badge and falling marks | Neutral ball and independent identity/feedback overlays. |
| `baskets/` | Three backs, three fronts and a trash badge | Orange, blue and trash bins assembled from separate layers. |
| `stations/` | Base, blank name plate, shaft, two grips and socket | One reusable operator station per player. |

The 22 textures and their exact dimensions, visible bounds, pivots and contact
points are in the [import manifest](../../../../art/tilt_shift/import_manifest.json).
All sprites have at least eight transparent pixels around their visible bounds.
The opaque background is kept at its original size and aspect ratio.

## Texture settings and scale

Godot imports use lossless compression, mipmaps, alpha-border correction,
straight alpha and disabled automatic 3D compression. Consumers should select
`CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` and
`CanvasItem.TEXTURE_REPEAT_DISABLED`. Retain the native aspect ratio when scaling.
The blue paper background is not a seamless tile.

Use the runtime PNGs for both host and phone artwork. The source sheet is the
canonical paddle master; the three treatments have the same canvas and pivot.
They retain the selected artwork's small contour differences. A phone must use
the same selected team texture and host angle as the shared arena.

The paddle neutral pose is horizontal. Rotate the beam about its center; add
player labels to the separate blank badge. PNG files do not encode a Godot pivot,
collision shape or filtering mode. The manifest describes these art references.

Choose display scale against the actual arena and phone composition. There is no
approved ball radius, paddle collider, operator size or gameplay opening width
in this asset import. Visual bounds exclude transparent canvas padding.

## Basket layers and widths

Draw the rear/opening behind balls, then the front panel over balls. Put the
trash badge above the trash front. Match the centers of a back and its front;
the back's `front_overlay_offset_px` locates the front canvas from the back canvas.
Both layers share a canvas width and keep their native heights.

For width edits, use each layer's `visible_bounds_px` as its working region,
preserving the first and last 64 pixels. Stretch only the intervening center
with a `NinePatchRect` or equivalent three-part renderer. Use the same displayed
width for both layers and each reflected team pair; do not stretch entire rims.
The separate trash emblem keeps its own aspect ratio and center pivot.

These margins are relative to the visible region, not the padded PNG canvas.
The working region needs more than 128 pixels of width before its center can
stretch. Different basket counts repeat the same parts; count and scoring
openings belong to the host preset, independently of decorative art extents.

## Stations and character contact

Use one base per player, including five on each side at ten players. Reuse the
existing player-colored Squircle library. Team grips and paddle colors identify
teams independently of the player's chosen body, hand and foot color.

All `anchors_px` coordinates use the PNG's top-left origin and native pixels.
Place the socket at the base's `socket_mount`. Rotate the shaft about its
`rotation_pivot`, and align a grip's `shaft_mount` with the shaft's `grip_mount`.
The grip's `hand_contact` supplies the character hand target. Transform these
points with the same scale and rotation as their texture.

The lever shaft has a lower pivot; other sprites use their center pivot.
Station placement can face either arena side without duplicating characters.
Cosmetic lever travel and operating poses do not imply full-body rotation when
a gameplay paddle completes repeated turns. Animation contact remains to be
reviewed in the actual character consumer.

## Sources and review

The owner approved the ImageGen artwork on 2026-10-03 and its import plan on
2026-10-04. Raster masters, saved prompts and reproducible extraction stay under
[`art/tilt_shift/`](../../../../art/tilt_shift/README.md), outside Godot import
and runtime exports. The source masters are editable PNGs, not layered/vector art.

Static art selection does not establish real-phone, couch-distance or moving
gameplay readability. The remaining reviews are listed in
[pending reviews](../../../../docs/pending-reviews.md#tilt-shift-art).
