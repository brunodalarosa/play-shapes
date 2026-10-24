# 0044. Every shape face is named for its emoji and drawn to the originals' measurements

Decided by the owner on 2026-10-24.

## Situation

The face manifest held the owner's twelve original faces, `face_a` to `face_l`, and fifty-eight
expressions drawn later from emoji. The later faces used smaller eyes set further apart, thin
outlines, blush hatching and coloured accents, so they read as a different set. Six of them
closely matched an original. Cubio showed `face_neutral`, one of the later faces.

## Decision

- The originals are named for the emoji they read as, such as `face_slightly_smiling` for A.
  Where one closely matched a later face, the original takes that name and the later face is
  removed.
- Cubio's default face is `face_slightly_smiling`, at the painted face's height of 0.725 m.
- The remaining fifty-two faces are redrawn to the originals' measurements: 40-pixel eyes 60
  pixels apart, 8-pixel round-capped lines, the supplied brow slabs and mouths 31 pixels below
  the eye line. They are navy and white; only the tongue is pink.

## What follows

- Names say what a face shows, so gameplay and tuning read without a lookup table.
- Tears, sweat, drool, sleep marks and the halo are white and lie outside the face box, so they
  read on every character colour and do not shrink the face.
- A face's box is still its own ink, so faces with brows draw their features smaller than faces
  without them at the same face height.
- A new face follows the drawing rules in the face parts' README.
