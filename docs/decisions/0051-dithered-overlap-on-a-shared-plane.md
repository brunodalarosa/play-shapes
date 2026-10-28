# 0051. Characters sharing a plane take depth slots, and the one in front dithers

Decided by the owner on 2026-10-27, for minigame 006 and every scene after it.

## Situation

Players pass through one another in Flappy Race, so Cubios on its one plane overlap often,
most of all at the start. Drawn at the same depth they z-fight; drawn with alpha blending they
need sorting the GL Compatibility renderer does poorly, and a translucent Cubio loses its face.

## Decision

Characters that share a plane each take a fixed, thin depth slot, ordered by seat, so no two
share a depth. While a character's outline on screen overlaps a character in a slot behind
it, the one in front draws with an ordered 4×4 screen door: a fixed share of its pixels,
body and face alike, is left out, and the one behind shows through.

## What follows

- This is the default for any scene where characters overlap on one plane.
- The dither lives in `characters/cubio_dither.gdshaderinc`, included by Cubio's tint and the
  face part shader, and defaults to drawing everything, so other scenes are unchanged.
- `Cubio3D.set_dither` gives a dithered Cubio its own tint material, leaving others of its
  colour whole.
- The share left out and the slot depth are tuning values; the look is settled in captures.
