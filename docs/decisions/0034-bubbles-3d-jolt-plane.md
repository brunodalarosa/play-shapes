# 0034. Bubbles and jellyfishes 3D simulates on Jolt with plane-locked bodies

Chosen on 2026-10-18 for minigame 004; the owner reviews it with that minigame.

## Situation

The 3D lobby mirrors a hidden 2D simulation onto a 3D plane
([0033](0033-plaza-lobby-plane-simulation.md)), because its one-way landings exist only in 2D.
The 2D Bubbles game moves its bubbles with its own kinematics and pair checks.

The owner chose 3D physics for 004. It has no one-way surfaces to lose: bubbles bump, rebound
off walls and touch creatures, all of which Jolt resolves directly.

## Decision

Bubbles are `RigidBody3D` spheres locked to depth zero with no rotation (`PlaneLock3D`). Their
radius is the drawn radius, their mass grows with the catch, and water drag and the speed cap
act each physics step. A swipe is an impulse, so heavier bubbles move less.

Invisible `PlaneWalls3D` on their own layer stop bubbles only. Jellyfishes and pufferfishes are
`Area3D` sensors that watch for bubble bodies; only the round controller changes a score.

Godot adds the bounce of the two bodies in a contact, capped at 1. Each bubble therefore carries
half the bump bounciness and the walls the rest, and the tuning requires the wall bounciness to
be at least half the bump bounciness.

## What follows

- Contacts resolve on the physics tick, about 16 ms later than code-driven checks. Tests step
  real physics frames instead of calling an arena step.
- The 2D distances and speeds carry over divided by 100: one world unit is 100 arena pixels.
- A body that should bounce off a static wall needs the wall's layer in its own mask under Jolt.
- Later plane games can reuse the plane lock, the walls and the sensors.
