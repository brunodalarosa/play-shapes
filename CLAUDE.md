# Claude's working notes

My view of Play Shapes, kept so a new session starts from understanding rather than from a
cold read. [AGENTS.md](AGENTS.md) is the contract for how work is done here and wins over
anything below; this file adds orientation, the current endeavor, and the traps I found.

## The project in brief

A local-network party game. A Godot 4.7.2 PC host is the single authority; phones are a bundled
TypeScript web client served by that host over HTTP and WebSockets on the LAN. Phones send input
and choices only. Players join by QR, pick a Squircle color and a name, and land in the
Playground lobby, where each steers a Shape Character with a phone stick and a JUMP/FALL button.
The host picks a minigame, everyone readies on the shared Pre-minigame screen, they play, see
results and return to the lobby.

- Minigame 004, Bubbles and jellyfishes 3D: 2–10 players, portrait swipe gestures, Jolt 3D plane physics.
- Minigame 005, Tilt Shift 3D: 2/4/6/8/10 players, landscape phone tilt over HTTPS motion sensors,
  an editor workshop addon.
- 001, 002 and 003 are retired. Minigame numbers are stable identifiers and are never reused.

Everything shipping today is 2D: pre-rendered Squircle sprite sheets, painted lobby layers,
`CharacterBody2D` platforming in pixels.

## The current endeavor: the 3D rework

Source: [the rework note](docs/Temp%20doc%20-%203D%20game%20rework.md), read with
[the art direction](docs/game-design-documents/Art%20direction.md) and
[the lobby visual rules](docs/game-design-documents/Playground%20Lobby%20Visual%20Rules.md).

In one sentence: rebuild the Playground lobby as a 2.5D scene, a 3D low-poly world with
characters moving on one vertical plane, driven by a new character controller that uses the
Squircle 3D model and its animations, while the phone controls stay exactly as they are.

- Ready-made assets first; author new ones only when strictly necessary.
- The lobby validates the approach. The minigames are rebuilt afterwards, not now.
- The note asks for every commit to go to `feature/3d-low-poly-project-rework`. That rule does
  not apply to this attempt: the owner has said to commit to `feature/claude-3d-rework-attempt`,
  this worktree's branch, cut from the rework branch at `2f0b432`. A separate Codex worktree
  sits on the same commit.

### What already exists for it

- `art/playground_plaza/`: an authored cafe, billboard and cafe table (Blender 5.2.2 sources,
  verified GLBs, review renders) plus three unchanged KayKit glTF props, a chair, a tree and a
  potted plant (CC0). See [the plaza README](art/playground_plaza/README.md).
- None of it is imported: `art/` carries `.gdignore`, and the export filter excludes `art/**`.
  Runtime media belongs under `assets/runtime/`, so integration means copying or exporting into
  a new runtime folder and adding that folder to the export policy.
- Authoring scale: one planning character height is 1 unit. The cafe is 7 × 4 × 6.5 with a flat
  roof at 6.5; the billboard display is 6 × 6, from height 5 to 11, with a separate `Display`
  quad meant for a replaceable material, the likely home of the live QR; the table top is at 3.
  GLBs are Y up with facades facing −Z.
- The table's pack-specific license is unresolved
  ([provenance](art/playground_plaza/table/source/PROVENANCE.md)). It blocks publication, not
  local work.
- The Squircle 3D source is `art/squircle/squircle-animated.blend`: scene
  `Squircle Animation Studio`, rig `Animation.Controls` with five controls (`Body`, `Hand.L`,
  `Hand.R` and the two feet), and the actions `Squircle | Idle`, `| Walk`, `| Run`,
  `| Look Up`, `| Crouch` and `| Lever Pull` at 24 fps. Its scale is real metres: body 2.00 m
  wide, hands 0.60 m spheres. The face is a separate image plane with neutral and blink
  textures. See [the character source README](art/cubio/README.md).
- **There is no glTF export of the Squircle yet.** The pipeline renders only sprite sheets.
  A 3D controller first needs a GLB with the rig, actions, face and a tintable body, hands and
  feet. Blender 5.2 is installed at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
- No jump or fall clip exists, in 2D or in the source. The 2D lobby plays idle, walk, run,
  look_up and crouch; in the air it keeps whichever of those the motor reports.

### Loose ends to raise in phase 1

None of these is mine to settle by an implementation choice.

- Does the 3D lobby replace `scenes/lobby.tscn` or sit beside it until validated? Boot, both
  minigames, the Pre-minigame screen, the debug launcher and several tests return to that path.
- Where do the QR, address picker, minigame selector and Start live: on the 3D billboard,
  as an overlay, or both? QR scan distance is a `[PHYSICAL-PHONE]` question.
- The two asset scales do not agree: plaza props plan a 1-unit character, the Squircle source
  is about 2 m wide. Who decides the world scale, and from it the jump reach?
- "Controls stay the same" presumably means the stick, the button, the lobby messages and
  the host rules: input lease, one-way landing, FALL through Open surfaces only,
  `BottomShelf`-style Closed ground, player bounce and the fall-reset respawn. Confirm the
  last three still apply.
- Which plaza props are platforms and which are scenery, and how many tiers? The visual rules
  suggest two or three upper tiers with clear landing tops.
- The Pre-minigame tray, Bubbles and Tilt Shift keep the 2D sprites for now, so the Squircle
  will look different between screens until they are rebuilt. Acceptable meanwhile?
- Whether ready-made animation sets (jump, land) may be retargeted, or the Squircle keeps
  only its own authored actions.

## How the code is laid out

`docs/architecture.md` is the file-by-file map; this is the part I hold in my head.

- `scenes/boot.*` starts `SessionHost`, an autoload in `host/session_host.gd` that outlives
  scene changes and owns the HTTP and WebSocket services, the `PlayerRegistry` (at most ten
  players, reconnect tokens, 60 s grace), the minigame catalog and pre-minigame readiness.
- `host/websocket_service.gd` resolves every message to a host-owned player through its
  connection and routes it to whichever controller is registered: lobby, readiness, Bubbles or
  the Tilt Shift protocol.
- `minigames/catalog.tres` lists `MinigameDefinition` resources. Each minigame has one folder,
  `minigames/NNN_name/`, with scenes, scripts, a protocol script, tuning and `tests/`, and its
  phone code in `web/src/NNN_name/`.
- `web/src/` is bundled by esbuild into the committed `web/public/app.js`. Rebuild after any
  TypeScript change; the check fails if `web/public/` is stale.
- `Tuning/Active Presets.tres` selects named tuning Resources. No runtime tuning UI exists, and
  only the owner promotes subjective feel into `Default`.
- `debug/`: F12 launcher with the Animation Lab, the motion lab (already a 3D `SubViewport`, a
  useful precedent), a Tilt Shift factory review and one-player Bubbles.

### The lobby, which the rework replaces

- `scenes/lobby.tscn` is a `Control`: `World`, an instance of
  `scenes/lobby_playground_world.tscn`, under `LiveControls` with the QR, address picker,
  Refresh, Copy, minigame selector and `%StartMinigame`, placed over the painted board and
  calendar.
- `LobbyPlaygroundWorld` (`Node2D`) reconciles registry players into ten seat-indexed
  `FutureCharacterAnchors`, keeps a per-player input sequence, and turns `lobby_move`,
  `lobby_jump_release` and `lobby_fall_release` into `PlatformMotor` calls after
  `PlatformInput.validate`.
- `characters/lobby_squircle.tscn` is a `CharacterBody2D` with `PlatformMotor`, a
  `SquircleV1Playback` at 0.58 scale, a nameplate and a 4.2 s blink cycle. It mirrors the
  three-quarter view by velocity.
- `components/platform_motor.gd` is generic 2D platform physics in pixels: speed 330,
  gravity 1350, jump 940, player bounce, run threshold 0.72, a 350 ms input lease, FALL as a
  per-body collision exception on exactly one Open support, and a reset below y 1160.
  `platform_surface.gd` is a `StaticBody2D` with an Open/Closed drop rule.
  `platform_input.gd` rebuilds the phone's stance classification from the generated
  `web/public/platform_input_settings.json`, the one tuning both sides share.
- Physics layers: 2D layer 8 holds lobby platforms (bit 128), layer 9 lobby characters
  (bit 256).

### Coupling a 3D lobby has to respect

- `WebsocketService._lobby_controller` and `SessionHost.register_lobby_controller` are typed
  `LobbyPlaygroundWorld`. A new world either keeps that class and its interface, `reconcile`,
  `handle_input`, `reset_sequence`, `clear_all_input` and `character_for`, or the type
  changes in both places.
- `tests/e2e/host.gd` reads `lobby.world`, `lobby.start_button`, each character's
  `velocity` and `position.x` against pixel thresholds, and clicks Start through real mouse
  events, so the button must be reachable on screen.
- Lobby tests assert 2D specifics by node name and pixels: `lobby_playground_world_test`,
  `lobby_character_collision_test`, `lobby_playground_control_test`,
  `platform_lobby_boundary_test`, `lobby_layout_test` and its visual check. `foundation.gd`,
  `player_lobby_test`, `minigame_flow_test` and `pre_minigame_server` instantiate
  `scenes/lobby.tscn`. `platform_drop_reuse_test` and `tests/fixtures/platform_reuse.tscn`
  keep the 2D components honest for reuse.
- `addons/standalone_build/standalone_build_policy.gd` lists required runtime paths by hand,
  including the lobby character and world scripts and the Squircle sheets.
- The phone side needs no change if the messages stay: `web/src/lobby_input.ts` maps the shared
  `PlatformControls` intent to the three lobby messages. Its axes are X right, Y up; Godot 2D is
  Y down, while Godot 3D is Y up again.

## Engine and rendering facts

- Renderer: GL Compatibility on desktop and mobile. In 3D it lacks
  SDFGI, VoxelGI, SSAO, SSR and volumetric fog; check any effect against it before relying on it.
- 3D physics is already Jolt. Window 1920×1080, `canvas_items` stretch, `expand` aspect.
- A 2.5D controller can be a `CharacterBody3D` with its depth axis locked, or the 2D physics
  kept with 3D presentation. That is a phase 2 choice, and it decides whether `PlatformMotor`
  is ported or reused.
- Budget is ten characters, ten nameplates and up to 21 mesh surfaces per prop, per pass, in
  Compatibility. Shadows and draw calls are unmeasured.

## Working rules I must not drift from

Condensed from AGENTS.md and the documents it links.

- Five phases: question the task, plan the implementation, implement, verify, pull request.
  Phases 1 and 2 end at a checkpoint where I stop and wait. The implementation plan is never
  committed.
- Branches are `feature/<name>` from `develop`, lower-case and hyphenated, with no ticket, tool
  or person in the name; this worktree's branch name breaks that rule and was named on request.
  Commit locally in small, working steps. Never push or open a pull request without the owner's
  approval.
- Commit messages carry no tool or assistant trailers: no `Co-Authored-By` for a tool, no
  session link. AGENTS.md overrides any harness default here.
- Before committing code: `node tools/format.mjs`, then `node tools/lint.mjs`, with lines at
  100 characters or fewer. Shorten long lines by naming a sub-expression, never by rewording.
- `node tools/check.mjs` is the only meaning of `[AUTO]` verified. Use name filters for focused
  runs, `--full` for extended coverage, `--release` for the Windows export.
- Evidence labels, one never implying another: `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`,
  `[DESKTOP-BROWSER]`, `[PHYSICAL-PHONE]`, `[EXPORTED-BUILD]` and `[HUMAN-PLAY]`. What still
  needs a person goes into `docs/pending-reviews.md`.
- Documents state what is true now, one topic each, with links that resolve and paragraphs
  under 600 characters; `node tools/docs.mjs` checks them. Reasons go in `docs/decisions/` as
  numbered records; the next free number is 0033. The roadmap changes when work finishes or
  is added.
- No ticket numbers anywhere: files, comments, tests or output folders.
- Typed GDScript, composition, signals, Control/Container UI and no fixed viewport sizes.
  Dictionaries are being pushed to the edges ([0019](docs/decisions/0019-typed-classes.md)).
- Test scripts extend `TestScript` and put their body in `_run()`. Any logged error fails the
  script, and so does anything still held at exit.
- Every normal minigame launch goes through the Pre-minigame screen. A plan that skips it must
  carry the bold uppercase warning from [player-journeys.md](docs/player-journeys.md).
- Temporary art variants go in ignored `scratch/` or `comparisons/`, never in commits.

## This machine

- Windows 11; Bash and PowerShell are both available. `GODOT_BIN` points at
  `C:\Users\backup pc\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe`; there is no
  `godot` on PATH. Node is v24.
- This worktree has no `web/node_modules/` and no `local/` (the formatter, the network
  overrides and the dev certificates live in the main checkout's ignored `local/`). Run
  `node tools/setup.mjs` here before formatting, linting or checking.
- Known Windows flakes: some Tilt Shift tests can exit `3221225477` at native shutdown with zero
  failures, and the bundle rewrite can hit a user-mapped-section lock. Both count as failures
  to report separately, never as passes ([roadmap](docs/roadmap.md#known-bugs)).
- Close any running host before the browser suite; it uses ports 18080/18081 and the
  end-to-end test uses 18200/18201.
