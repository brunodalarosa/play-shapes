# 0045. Every shape face shares one frame and scale

Decided by the owner on 2026-10-24. Replaces the face boxes of
[0044](0044-one-face-style.md); its names and drawing rules stand.

## Situation

Each face preset was measured in its own box: the ink of its eyes, brows and mouth. A face is
drawn at a given box height, so a face with brows drew its eyes smaller than one without, and
Cubio's eyes changed size and moved whenever its expression changed.

## Decision

Every preset uses `face_slightly_smiling`'s frame, 100 × 58 source pixels, with its eyes on that
face's eye line. A source pixel is the same size in every face. Brows, tears, the sleep marks and
the halo may reach outside the frame.

## What follows

- Changing expression keeps the eyes where they are and the same size.
- Cubio's face height is unchanged, because the default face already used this frame.
- Taller faces can reach past a thin Tilt Shift paddle; the owner accepts that for now.
- The export check places each original's reference image in the frame before comparing.
