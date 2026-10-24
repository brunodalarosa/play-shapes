# 0043. Cubio's face is the shape face system, drawn on an anchor in the model

Decided by the owner on 2026-10-23.

## Situation

Cubio's face was a quad in its model with two painted images, neutral and blinking, on host
and phone. The Tilt Shift paddles already used the shape face system
([0037](0037-shape-face-system.md)): faces composed from shared parts, with seventy presets and
an expression stack. A painted face can only blink, and every new model would need its own.

The owner wants one dynamic face system that draws on top of many different models.

## Decision

Cubio has no face of its own. Its model carries an empty `FaceAnchor` on the body's front, and
the host and phone draw a shape face there: `ShapeFace3D` in Godot and its three.js
counterpart on the phone, showing `face_neutral` and blinking naturally.

How the face sits on the anchor, an offset and a height in source units, is in
`face_anchor.json` beside the model. Host and phone read the same file, and the Shape
Characters lab saves to it.

## What follows

- A new model needs only a `FaceAnchor` and a `face_anchor.json` to wear every face.
- Gameplay can show any preset on a Cubio through its `ShapeFaceExpressions`.
- The painted face images, their routes and the face shader are gone. Blender has no shape
  face, so source renders show a blank front.
- A face part uses the body's front push, so scenery near a character covers neither.
- A neutral face is three quads instead of one per Cubio: about twenty more draws with ten
  players, an estimate.
