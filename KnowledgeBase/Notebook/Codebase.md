---
area: Notebook
tags: [system]
code: [host, scenes, characters, components, minigames/catalog.tres, web/src, workshop, debug, Tuning, assets/runtime, tests, tools]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Codebase

Hub: [[Notebook]]. Where each part of the game lives, so a task starts in the right folder.
The notes of each area say which script owns what; messages and limits are in
[[Message Protocol]].

## Top-level map

| Folder | Holds | Area |
| --- | --- | --- |
| `host/` | boot steps, `SessionHost`, HTTP and WebSocket services, registry, readiness | [[Host and Session]] |
| `scenes/` | boot, lobby, plaza world, billboard, Pre-minigame screen | [[Playground Lobby]], [[Minigames]] |
| `characters/` | `Cubio3D`, the lobby body, character selection, Ready-screen previews | [[Cubio Runtime]] |
| `components/` | shared 3D and gameplay parts, listed below | here |
| `minigames/` | `catalog.tres` and one `NNN_name/` folder per minigame | [[Minigames]] |
| `web/` | the phone client: `src/` TypeScript, `public/` the served page and committed bundle | [[Phone Client]] |
| `workshop/` | the shared minigame workshop window, left out of exports | [[Workshops and Tuning]] |
| `Tuning/` | `Active Presets.tres` and the shared tuning Resources | [[Workshops and Tuning]] |
| `debug/` | the F12 launcher and labs | [[Debug Menu]] |
| `art/` | Blender and vector sources, ignored by Godot and the export | [[Art Pipeline]] |
| `assets/runtime/` | every model, texture and face the game loads | [[Art Pipeline]] |
| `tests/`, `tools/` | shared Godot tests; the Node check, format, lint and docs tools | [[Tooling and Verification]] |
| `addons/` | vendored QR, godot-wry and godot_mcp, plus the editor-only builder and Tilt Shift workshop | below |
| `KnowledgeBase/` | this vault, ignored by Godot through `.gdignore` | [[Home]] |

## Look-alike names

- Platform input exists twice: `PlatformInput` in `components/platform_input.gd` rebuilds on
  the host the stance the phone classified in `web/src/platform_input.ts`. **The TypeScript
  `DEFAULT_PLATFORM_SETTINGS` is the source**: the build writes
  `web/public/platform_input_settings.json` from it, and the host reads that file.
- `addons/tilt_shift_3d_workshop/` is the older Tilt Shift editor workshop; Flappy Race's
  workshop is the first on the shared window in `workshop/`.
- `LobbyController` is a small base class, not the lobby scene's controller node: services
  name it so that naming the lobby loads no model.

## Shared 3D components

These live outside any minigame folder so later 3D scenes can use them.

- `components/plane_3d/`: `PlaneLock3D` locks a body's depth and rotation; `PlaneWalls3D`
  builds invisible edge walls on their own physics layer.
- `components/bubble_shell/`: `BubbleShell3D`, a translucent shader sphere with stretch, pop
  droplets and re-form.
- `components/underwater_environment/`: the water backdrop, god rays, seabed with caustics,
  depth haze and air bubbles, plus a recolouring prop material with optional sway.
- `components/screen_follow_label.gd`: screen text that follows a 3D node.
- `components/race_camera/`: `RaceCamera3D` keeps a race's leader at a share of the width and
  zooms between two visible heights to fit the pack; `OffscreenBubbles` shows racers behind
  its left edge as bubbles with face and name.
- `components/rounded_bar/`: `RoundedBar` builds a bar's rounded outline, mesh and convex
  collider from its length, thickness, depth and corner radius.
- `components/flappy_flight/`: the flappy shape gameplay, plain typed GDScript with no
  nodes. `FlappyFlight` steps one player's flight at 60 Hz over a `FlappyFlightCourse`;
  `HeartRow` holds the hearts; `FlappyFlightTuning` holds the values the phone also receives.
  `web/src/flappy_flight/` is the same step in TypeScript, line for line
  ([[0047-shared-deterministic-simulation|0047]]). `FlappyFlightAutopilot` flies a
  course with no hit, for tests and simulated players.
- `components/shape_face/`: the shape character face. `ShapeFaceManifest` reads the shared
  face parts and presets, `ShapeFaceExpressions` keeps timed expressions with priorities and
  natural blinks, and `ShapeFace3D` and `ShapeFace2D` draw a face in 3D or in a Control.

## Assets, addons and tests

- `assets/runtime/` is the curated runtime-media boundary. Source and archive art remains
  outside it and is excluded from Godot import and export.
- The models of minigame 004, Bubbles and jellyfishes 3D, live in
  `assets/runtime/minigames/bubbles_3d/`. Their sources and provenance are in
  [[004 Art Assets|art/bubbles_3d]].
- The face parts shared by every minigame, 8× PNGs and the preset manifest that composes them
  into the twelve original faces and fifty-two faces drawn in their style, live in
  `assets/runtime/shape_faces/`. Their vector masters
  and provenance are in
  [[Shape Face Parts|art/shape_characters_face_system_assets]].
- The bin, factory props, trash emblem and booklet preview of minigame 005, Tilt Shift 3D,
  live in `assets/runtime/minigames/tilt_shift_3d/`. Their sources and provenance are in
  [[005 Art Assets|art/tilt_shift_3d]]. The host serves the face parts to the
  phone from `assets/runtime/shape_faces/`.
- `addons/standalone_build/` is the editor-only Windows builder.
  `addons/kenyoni/qr_code/` is the required vendored runtime QR dependency.
  `addons/godot_wry/` is the vendored Windows web view the workshops use; it is not exported.
- `tests/` holds focused headless, integration, policy and render checks of the shared code. A
  minigame's own are in its `tests/` folder. Generated evidence belongs under ignored
  `test-results/`.
