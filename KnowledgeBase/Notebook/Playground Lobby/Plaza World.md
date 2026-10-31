---
area: Playground Lobby
tags: [system, stub]
code: [scenes/lobby_playground_world.tscn, assets/runtime/playground_plaza, PlazaLanding, PlatformSurface, scenes/lobby_playground_world.gd, characters/lobby_cubio.tscn, PlatformMotor, Cubio3D]
verified:
branch:
---

# Plaza World

Hub: [[Playground Lobby]].

Which scene and script own the Playground lobby.


- `scenes/lobby.*` holds the address picker, Refresh, Copy, the join address, the minigame
  selector and Start in `ControlPanel`, a container panel 32 pixels in from the top-right
  corner. It hands the join URL to the billboard.
  - There is no visible roster. `SessionHost.players_changed` still refreshes the shared 2–10
    player launch gate.
- `scenes/lobby_playground_world.tscn` is the 3D café plaza, laid out from the approved
  mockup with the models in `assets/runtime/playground_plaza/`. Its fixed `Camera3D` frames
  the plaza with a gentle downward tilt.
  - Characters move on the action plane at depth zero. One world unit is one character height.
  - Each landing is a `PlazaLanding` marker inside its prop: the ground (Closed), three chair
    seats, two tabletops and the café roof (Open). Moving a prop moves its landing.
  - `PlatformSurfaces` holds the invisible collision: the world builds one one-way
    `PlatformSurface` box per landing on 3D physics layer 8 (bit 128). Characters are
    plane-locked Jolt bodies on layer 9 (bit 256). See
    [[0042-plaza-lobby-jolt-plane|decision 0042]].
  - Two invisible side walls on the same layer keep characters in view. `fit_walls()` places
    them from the camera whenever the view resizes, so a character stops with its centre on
    the screen edge, half out of view. The ground runs past both walls.
  - `scenes/plaza_billboard.*` draws the live join QR across the whole display in a
    `SubViewport` that renders only when it changes, shown unshaded on the `Display` surface.
  - `Plaza/Cafe/LogoSign` is the logo as 3D letters on posts on the café roof, scenery with no
    collision ([[0041-rooftop-logo-sign|decision 0041]]).
- `scenes/lobby_playground_world.gd` reconciles registered players to ten seat-indexed
  `SpawnPoints` and spawns their bodies under `Characters`.
- `characters/lobby_cubio.tscn` is the host body: a `CharacterBody3D` with the shared
  `PlatformMotor`, a capsule, the player lifecycle and its `Cubio3D` as a child.
- `Tuning/Shared/Lobby/Default.tres` holds the movement preset, in character heights, selected
  in `Active Presets.tres`.
