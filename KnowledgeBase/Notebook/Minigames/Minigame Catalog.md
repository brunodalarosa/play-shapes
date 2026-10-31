---
area: Minigames
tags: [system]
code: [minigames/catalog.tres, MinigameDefinition, SessionHost, MinigameProtocol, tests/minigame_catalog_test.gd, host/http_service.gd, addons/standalone_build/standalone_build_policy.gd]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Minigame Catalog

Hub: [[Minigames]]. How the shared code learns about a minigame, and the steps to add one.
The why is in [[Minigame Contract]].

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
  `allowed_player_counts` narrows the range to listed counts (Tilt Shift: 2, 4, 6, 8, 10), and
  `session_script` names a session that follows the round from the Pre-minigame screen into
  play ([[0039-minigame-session-scripts|0039]]).
- `SessionHost` owns the catalog. The lobby fills its picker from it in the catalog's order,
  the host takes the scene, the name and the player limits from it, the ready screen loads its
  content through it, and the debug menu derives its one-player scenarios from it.
- `tests/minigame_catalog_test.gd` checks that every definition names things that exist.

To add a minigame: make its folder, save a `MinigameDefinition` in it, and add that
definition to the catalog. Three places still name each minigame by hand: its slot in
`Tuning/Active Presets.tres`, the phone asset routes in `host/http_service.gd`, and the
export policy's list of required paths. A minigame whose protocol extends `MinigameProtocol`
needs no change to the WebSocket service.

