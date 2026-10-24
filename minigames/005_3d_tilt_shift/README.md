# Tilt Shift 3D

Minigame 005 is Tilt Shift in the 3D low-poly world. Two equal teams tilt their phones to
guide falling balls into their bins; each player is a paddle in their own colour, with a face
that reacts. The design is in `docs/game-design-documents/Minigames/005/`.

## Ownership

- `tilt_shift_3d_shift_controller.gd` owns the shift: roster, teams, rounds, selection,
  allocation, readiness, countdown, scoring and results. Physics reports catches only.
- `tilt_shift_3d_arena.gd` owns the Jolt bodies on the plane: paddles, balls, walls and the
  raised floor, delivery and catches. It converts between the rules' arena widths, measured
  from the top-left with Y down, and world units centred on the origin with Y up.
- `tilt_shift_3d_presentation.gd` and `tilt_shift_3d_presentation.tscn` draw the factory,
  bins, shape paddles, faces, names, balls, HUD, participant panel and results.
- `tilt_shift_3d_expression_driver.gd` turns fast turns, hits and the round's moments into
  faces; it reads the arena and never feeds back into it.
- `tilt_shift_3d_session.gd` carries motion preparation from the Pre-minigame screen into
  play, and `tilt_shift_3d_protocol.gd` is its phone protocol.
- `3d_tilt_shift.tscn` is the catalog entry's scene, with Return to lobby.

## Shape paddles and faces

Each paddle's collider and drawing come from `RoundedBar` in `components/rounded_bar/`, built
from the layout's length and thickness. The drawing adds a cream gap ring, the team outline and
a `ShapeFace3D` from `components/shape_face/`; the automatic paddle is grey with no face.

A hit squashes only the drawing. Names follow the paddles through `ScreenFollowLabel` for the
first seconds of each round. The phone shows the strongest face across the player's paddles.

## Tuning and tools

[The tuning guide](tuning/README.md) lists every value. The **Tilt Shift 3D** workshop tab edits
them and runs the 3D preview; F12 offers a simulated factory with ten synthetic players.
