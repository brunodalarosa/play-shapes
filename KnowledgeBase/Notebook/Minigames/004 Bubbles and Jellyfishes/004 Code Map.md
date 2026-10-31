---
area: Minigames
tags: [system, stub]
code: [MinigameDefinition, minigames/catalog.tres]
verified:
branch:
---

# 004 Code Map

Hub: [[004 Bubbles and Jellyfishes]].

Where minigame 004 and the minigame catalog live in the code.

A minigame has one folder under `minigames/`, named with its number and name
([[0015-one-folder-per-minigame|decision 0015]]). It holds the minigame's scenes,
scripts, protocol script and tuning script, its presets in `tuning/` and its tests and render
helpers in `tests/`. Its phone code is in the folder of the same name under `web/src/`, and
its browser tests in the one under `web/tests/`. Art sources and runtime assets stay under
`art/` and `assets/runtime/`.

The shared code learns about a minigame from the catalog, `minigames/catalog.tres`
([[0024-minigame-catalog|decision 0024]]):

- The catalog lists one `MinigameDefinition` per minigame: its id, its name, the path of its
  scene, its fewest and largest numbers of players
  ([[0049-minimum-players-per-minigame|decision 0049]]), the path of its
  ready-screen content, and whether the debug menu offers a one-player round.
- `SessionHost` owns the catalog. The lobby fills its picker from it in the catalog's order,
  the host takes the scene, the name and the player limits from it, the ready screen loads its
  content through it, and the debug menu derives its one-player scenarios from it.
- `tests/minigame_catalog_test.gd` checks that every definition names things that exist.

To add a minigame: make its folder, save a `MinigameDefinition` in it, and add that
definition to the catalog. Three places still name each minigame by hand: its slot in
`Tuning/Active Presets.tres`, the phone asset routes in `host/http_service.gd`, and the
export policy's list of required paths. A minigame whose protocol extends `MinigameProtocol`
needs no change to the WebSocket service.

Minigame 004, Bubbles and jellyfishes 3D, lives in `minigames/004_3d_bubbles/`. It has no spin
move; `tests/bubbles_3d_no_spin_test.gd` in its folder checks that. Its gameplay runs on Jolt
with plane-locked bodies ([[0034-bubbles-3d-jolt-plane|decision 0034]]).

- `bubbles_3d_round_controller.gd` owns the entrance, countdown, active and results phases,
  scores, pops and scatter counts, the zero-time freeze, ranking, disconnects and leaves.
- `bubbles_3d_player_arena.gd` creates up to ten `Bubbles3DPlayerBubble` rigid bodies inside
  `PlaneWalls3D` and reports bumps. Each bubble owns its shell, its Cubio with
  `Bubbles3DHandWobble`, and an instanced batch of caught jellyfishes.
- `bubbles_3d_creature_arena.gd` owns jellyfish waves, safe spawns, scatter, pufferfish
  crossings and their warnings. Jellyfishes and pufferfishes are `Area3D` sensors; free
  jellyfishes draw through one `Bubbles3DJellyfishSwarm`.
- `bubbles_3d_presentation.gd` and `3d_bubbles.tscn` frame the plane through a fixed 30 degree
  camera, dress the seabed, run the entrance, countdown, timer, nameplates, audio and results,
  register `Bubbles3DProtocol` for the round and step both arenas each physics frame.
- `bubbles_3d_protocol.gd` validates touches and releases, times holds on the host and pushes
  snapshots, feedback and visuals. The messages are in
  [[004 Messages]].
