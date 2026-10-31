---
area: Playground Lobby
tags: [system, stub]
code: [PlatformMotor, PlatformSurface]
verified:
branch:
---

# Platform Movement Parts

Hub: [[Playground Lobby]].

The reusable parts behind the lobby characters.


The reusable parts behind the lobby characters. Setup and reuse are in
[[Platform Controller#Host components and platform setup]].

- `PlatformMotor` exposes speed, acceleration, gravity, jump impulse, player bounce, run
  threshold, input lease, fall-reset height and drop timing in its Inspector.
- `PlatformSurface` carries an independent **Drop Rule: Open/Closed** for each landing. Only
  the ground is Closed.
- Select a prop's `Landing` marker in the world scene to change its rule without touching the
  model or its placement.
