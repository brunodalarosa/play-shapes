# 0042. The Playground lobby simulates its characters on Jolt with plane-locked bodies

Decided by the owner on 2026-10-23. Replaces
[0033](0033-plaza-lobby-plane-simulation.md).

## Situation

The 3D plaza lobby moved its characters on a hidden 2D plane and mirrored each one into the
plaza, because Godot's 3D physics has no one-way collision shapes
([0033](0033-plaza-lobby-plane-simulation.md)). It was the last 2D gameplay code once Bubbles
and Tilt Shift moved to Jolt on a locked plane.

The owner wants the lobby on Jolt as well, with the plane locked so the controls still feel 2D.
The phone controls and their host rules stay: one-way landings, FALL through Open landings
only, player bounce, the input lease and the fall-reset respawn.

## Decision

Each lobby character is a `CharacterBody3D` whose depth axis `PlaneLock3D` locks at zero, moved
by the 3D `PlatformMotor` in world units with Y up. The Cubio rides along as a child of its
body; nothing is mirrored.

The motor makes landings one-way itself. Before each move it adds a collision exception, for
its own body only, with every one-way `PlatformSurface` in the step's path whose top is above
the body's feet, and removes it once the feet are above that top. FALL adds the one Open
support underneath until the body clears it, times out or lands elsewhere.

## What follows

- The phone client, the lobby messages and the tuning values need no change. Host authority is
  unchanged.
- The 2D `PlatformMotor`, `PlatformSurface` and the 2D physics layers are gone; the lobby
  layers are 3D layers 8 and 9.
- Scenery still cannot block a character: only the landings and the two side walls collide.
- Any later minigame played on one plane can reuse the motor and its one-way landings.
- Ten characters cost about 0.14 ms a physics step on the development PC, measured by
  `tests/lobby_physics_cost_check.gd`.
