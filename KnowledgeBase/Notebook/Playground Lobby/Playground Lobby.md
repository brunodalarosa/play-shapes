---
area: Playground Lobby
tags: [hub]
code: [scenes/lobby.tscn, scenes/lobby_playground_world.tscn, LobbyPlaygroundWorld, characters/lobby_cubio.tscn, components/platform_motor.gd, components/platform_surface.gd, PlazaLanding, Cubio3D]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Playground Lobby

Area hub. Parent: [[Notebook]]. The 3D café plaza where players gather after joining and steer
their Cubio with a phone stick and a JUMP/FALL button, until the host starts a minigame.

## Notes

- [[Plaza World]]: the lobby scene, the plaza, landings, walls and the billboard.
- [[Platform Movement Parts]] and [[Platform Controller]]: the reusable motor and the phone
  controls behind it.
- [[Cubio Runtime]]: the one player character, shared by every scene.

## Rules

- **Physics layers: 3D layer 8 holds lobby landings and walls (bit 128), layer 9 lobby
  characters (bit 256).**
- Each `PlazaLanding` marker inside a prop defines a landing: the ground is Closed, chair
  seats, tabletops and the café roof are Open. Moving a prop moves its landing.
- The motor makes its own one-way landings on a plane-locked Jolt body
  ([[0042-plaza-lobby-jolt-plane|0042]]).
- One world unit is one character height. GLBs are Y up with facades facing −Z.

## Gotchas

- **`tests/e2e/host.gd` reads `lobby.world`, `lobby.start_button` and each character's
  motion, and clicks Start with real mouse events**: the button must stay reachable on screen.
- `addons/standalone_build/standalone_build_policy.gd` lists required runtime paths by hand;
  moving a lobby asset means updating it.
- Cubio has no jump or fall clip. In the air the lobby keeps whichever clip the motor reports.

Architecture: [[Lobby Platform Motor]], [[Lobby Visual Rules]], [[Lobby Journey]].
