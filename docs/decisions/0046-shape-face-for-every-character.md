# 0046. Every Shape Character wears the shared shape face

Decided by the owner on 2026-10-24. Widens [0043](0043-cubio-shape-face.md) from Cubio to the
whole project.

## Situation

Cubio's face moved from painted artwork to the shape face system on a `FaceAnchor`
([0043](0043-cubio-shape-face.md)), with one drawing style and frame for every face
([0044](0044-one-face-style.md), [0045](0045-shared-face-frame.md)). Nothing yet said whether
later characters and models follow it.

## Decision

The shape face system is the project's one face system. Every Shape Character, on the host and
on the phone, shows its face as a `ShapeFace3D` (or its three.js counterpart) on its model's
`FaceAnchor`, placed by that model's `face_anchor.json`. Models carry no painted or modelled
faces of their own, and new expressions are presets in the shared manifest.

## What follows

- A new model needs a `FaceAnchor` empty and a `face_anchor.json`, nothing more, to wear every
  expression.
- Gameplay changes faces through `ShapeFaceExpressions`, never by swapping textures on a model.
- A character that needs a face the system cannot draw is a reason to extend the system, not to
  bypass it.
