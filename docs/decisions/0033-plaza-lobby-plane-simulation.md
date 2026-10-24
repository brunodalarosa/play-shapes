# 0033. The 3D Playground lobby simulates its characters on a 2D plane

Chosen on 2026-10-17 for the 3D Playground lobby; the owner reviews it with that change.

Replaced by [0042](0042-plaza-lobby-jolt-plane.md).

## Situation

The lobby moves to a 3D plaza in which characters move only left, right and up, on one
plane. The phone controls and their host rules had to stay as they were: one-way landings,
FALL through Open surfaces only, player bounce, the input lease and the fall-reset respawn.

Godot's 3D physics has no one-way collision shapes. Those rules already exist, and are tested,
in the 2D `PlatformMotor`, `PlatformSurface` and `PlatformInput`.

## Decision

Each lobby character is a hidden `CharacterBody2D` on the action plane, driven by the same
`PlatformMotor`. A 3D Cubio mirrors its position at depth zero in the plaza.

One world unit is one character height and 96 plane pixels, the motor body's height, so the
earlier speed and gravity carry over. `PlazaLanding` markers on the 3D props are the only
placement of each landing; the world builds the 2D surfaces from them at runtime.

## What follows

- The phone client, the lobby messages and the motor need no change. Host authority is
  unchanged.
- Scenery cannot block a character. Only the ground, chair seats, tabletops and the café roof
  collide, all as one-way tops.
- A later minigame that plays on a plane can reuse the same split. One that needs true depth
  uses Godot's 3D physics instead, and needs its own answer for one-way landings.
