---
area: Minigames
tags: [system, stub]
code: [MinigameDefinition, minigames/catalog.tres]
verified:
branch:
---

# 004 Code Map

Hub: [[004 Bubbles and Jellyfishes]].

Where minigame 004 lives in the code. The catalog every minigame joins is in [[Minigame Catalog]].

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
