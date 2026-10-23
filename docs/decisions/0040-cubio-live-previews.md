# 0040. Cubio uses one animated model in gameplay and setup

Chosen on 2026-10-23.

## Situation

The character becomes a cube named Cubio while keeping its rig, motion, face and floating
limbs. Ready-up and phone setup still depend on the Animation Lab's rendered sheets.
Removing those sheets requires a shared live representation for those screens.

## Decision

Export the canonical Cubio blend as one rigidly animated GLB. The host's `Cubio3D` and
the phone's three.js character use the same geometry, clips and neutral/blink textures.
Keep the five control bones and limb transforms; only the body mesh and face depth change.

The Ready-screen tray puts its characters in one isolated viewport. Phone setup mounts
one visible preview at a time, cancels pending mounts on navigation and caches model and
texture downloads with gameplay. No new game state or WebSocket messages are introduced.

## What follows

- Geometry and animation corrections apply to every consumer through the same export.
- Setup downloads the separate 3D module before gameplay. Joining remains available when
  3D cannot be created; no rendered animation sheets are retained as a fallback.
- Current selections use `cubio`. Legacy `squircle` input remains accepted by the host.
- Animation Lab, sprite playback, sheet routes and their export requirements are removed.
- Physics, collisions, input and host authority retain their existing owners and behavior.
