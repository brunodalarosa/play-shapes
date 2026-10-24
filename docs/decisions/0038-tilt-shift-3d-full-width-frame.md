# 0038. Tilt Shift 3D fills the full width and raises its floor for the bins

Chosen on 2026-10-18 for minigame 005; the owner reviews it with that minigame.

## Situation

2D Tilt Shift's arena is one width wide and 0.5625 widths tall, with operator stations and
rails on both sides. Tilt Shift 3D has no stations, and its bins are 3D crates whose front
panels must show below the mouths. Two frames were possible: keep 2D Tilt Shift's geometry
inside slim side margins, or fill the screen's width and make room for the bins.

## Decision

The arena fills the frame edge to edge at 16:9: 19.2 by 10.8 world units, one world unit for
100 pixels of a 1920 by 1080 frame. The floor and the bin mouths sit 0.4925 widths below the
top, leaving a 0.07-width bin band. The starting layouts keep 2D Tilt Shift's x positions and
scale every y by 0.4925 / 0.5625.

The bin band is a physics tuning value, because it moves where catches resolve.

## What follows

- The rules and the workshop keep measuring in arena widths from the top-left.
- A screen narrower than 16:9 shows more space above the arena, never below the bins.
- Paddles sit closer together vertically than in 2D Tilt Shift; the owner re-spaces them.
