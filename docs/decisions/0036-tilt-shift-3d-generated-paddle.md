# 0036. Tilt Shift 3D builds its paddles in code with a rounded convex collider

Chosen on 2026-10-18 for minigame 005; the owner reviews it with that minigame.

## Situation

In Tilt Shift 3D each player becomes the paddle they control, so the paddle is the player's
character: their colour, a cream gap ring, a team outline and a face. Layouts set each
paddle's length and thickness, and the owner tunes both in the workshop.

A library model would stretch its rounded ends when its length changes, and a box collider
under a rounded drawing would catch balls on corners nobody can see.

## Decision

`RoundedBar`, in `components/rounded_bar/`, builds a bar's outline, mesh and convex collider
from its length, thickness, depth and corner radius, never from node scale. The corner radius
is a share of the thickness, so a longer paddle never stretches its ends, and the collider is
exactly the outline the player sees.

The rings are larger bars behind the body. A hit squashes only the drawing; the collider keeps
its size. The phone builds the same outline in TypeScript, checked against one shared fixture.

## What follows

- Balls roll off the visible rounded ends and rest on the visible top.
- Changing a layout's thickness changes the collider, the drawing and the face together.
- No paddle model needs authoring or licensing; the look lives in tuning.
- Later shape characters can reuse the builder for other bars.
