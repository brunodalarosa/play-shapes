# 0041. The logo is a 3D sign on the café roof, and the billboard shows only the QR

Chosen on 2026-10-23.

## Situation

The approved rounded Cut Paper logo stacks PLAY above SHAPES, so it is much taller than the
old one-line wordmark. Drawn on the billboard display, it left the join QR small. Moving it
above the billboard pushed the frame off screen or behind the trees in front of it.

## Decision

The logo stands on the back half of the café roof as a 3D sign, lifted slightly on four
metal posts. The billboard display shows only the join QR, enlarged to fill it.

The letters are not modeled by hand. A Blender script traces each color of the approved PNG
and extrudes the outlines, and adds a cream cut-paper backing and the posts. Changing the
artwork means exporting the sign again, not remodeling it.

## What follows

- The QR is about half as wide again on screen as before, which helps scanning from the couch.
- The sign is scenery: no collision and no new landing. Characters on the roof draw in front
  of it.
- The sign is about 5,000 triangles in four materials. Each export checks that count.
- The phone app icons use the same artwork, cut out from its cream background.
- The old two-color wordmark is no longer in the project.
