# 0037. Shape character faces are composed from parts, with expressions in a stack

Chosen on 2026-10-18 for minigame 005; the owner reviews it with that minigame.

## Situation

Tilt Shift 3D gives each paddle a face that blinks and reacts: dizzy when turned fast,
startled when hit, determined during the countdown, confident or sad at the results. The
owner supplied twelve reference faces drawn from fourteen parts, and the idea may reach other
characters later.

Twelve whole face images would need a new image for every new expression and a blink variant
of each.

## Decision

`components/shape_face/` reads `assets/runtime/shape_faces/face_presets.json`, which places
the parts of each reference face. A face is drawn from its layers, as flat quads in 3D or in a
Control; a blink swaps open eyes for a closed one. `ShapeFaceExpressions` keeps a base face and
timed expressions with priorities, so the highest-priority expression shows until it ends.

The phone composes the same faces from the same manifest and parts, which the host serves.

## What follows

- A new expression is a preset in the manifest, not a new image.
- Blinking needs no extra art and skips eyes that are shut or crossed out.
- Which face a moment shows, and every threshold and duration, is tuning.
- The lobby's and 004's Cubio keep their own face until the owner decides otherwise.
