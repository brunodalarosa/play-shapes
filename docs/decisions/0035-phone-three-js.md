# 0035. The phone draws 3D with three.js, loaded only when a 3D screen needs it

Chosen on 2026-10-18 for minigame 004; the owner reviews it with that minigame.

## Situation

Bubbles and jellyfishes 3D shows each player their own bubble on the phone, in real time, with
the same Squircle and jellyfish models as the shared screen. The phone client is a bundled
TypeScript app ([0016](0016-bundle-the-phone-client.md)) with no 3D renderer.

three.js reads the project's GLB files directly and runs in every browser the project tests.
It is large compared with the rest of the client.

## Decision

The phone uses three.js `0.186.1`, pinned exactly. A reusable module in `web/src/three_view/`
holds the viewport, the GLB loader, the 3D Squircle and the bubble shader port; it builds into
its own minified `three_view.js`, which `app.js` imports only when a 3D screen first starts.

The web build copies the GLB files the phone needs into `web/public/models/`. Godot keeps those
copies as plain files, so the Windows export carries them unchanged and the host serves them.

## What follows

- Phones that never play a 3D screen never download three.js.
- The models exist twice in the repository; the build-freshness check keeps the copies identical.
- A browser without WebGL shows a flat fallback instead of the 3D view.
- Later phone screens build on the same module instead of adding another renderer.
