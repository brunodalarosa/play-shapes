# Claude's working notes

My view of Play Shapes, kept so a new session starts from understanding rather than from a
cold read. [AGENTS.md](AGENTS.md) is the contract for how work is done here and wins over
anything below; this file adds orientation, the current endeavor, and the traps I found.

## The project in brief

A local-network party game. A Godot 4.7.2 PC host is the single authority; phones are a bundled
TypeScript web client served by that host over HTTP and WebSockets on the LAN. Phones send input
and choices only. Players join by QR, pick a Cubio color and a name, and land in the
Playground lobby, where each steers their Cubio with a phone stick and a JUMP/FALL button.
The host picks a minigame, everyone readies on the shared Pre-minigame screen, they play, see
results and return to the lobby.

- Minigame 004, Bubbles and jellyfishes 3D: 2–10 players, portrait swipe gestures, Jolt 3D
  physics on one locked plane, a three.js view of each bubble on the phone.
- Minigame 005, Tilt Shift 3D: 2/4/6/8/10 players, landscape phone tilt over HTTPS motion
  sensors, plane-locked Jolt physics, an editor workshop addon.
- Minigame 006, Flappy Race: 1–10 players, the only minigame with `min_players = 1`
  ([0049](docs/decisions/0049-minimum-players-per-minigame.md)).
  - The host runs the race in `FlappyRaceController`, settling taps one window behind its
    clock ([0048](docs/decisions/0048-predicted-input-carries-a-tick.md)).
  - Each phone predicts its own flight on the shared step in `components/flappy_flight/` and
    its TypeScript twin, proven bit-identical by `tests/fixtures/flappy_flight_runs.json`.
  - The shared screen follows the leader with `RaceCamera3D` and dithers overlaps
    ([0051](docs/decisions/0051-dithered-overlap-on-a-shared-plane.md)).
  - The course is placeholder boxes; cave art, flight clips, podium and results are to come.
  - Its workshop, `minigames/006_flappy_race/workshop/`, is the first on the shared window in
    `workshop/`. Presets are one file each; `FlappyRaceAutopilot` taps through the protocol.
- 001, 002 and 003 are retired. Minigame numbers are stable identifiers and are never reused.

## The 3D rework

The game has been rebuilt as a 3D low-poly world where characters move on one vertical plane.
The lobby, both minigames, the Ready screen and phone setup all share the live 3D Cubio.
Sources: [the rework note](docs/Temp%20doc%20-%203D%20game%20rework.md),
[the art direction](docs/game-design-documents/Art%20direction.md) and
[the lobby visual rules](docs/game-design-documents/Playground%20Lobby%20Visual%20Rules.md).

- Commits for this work go to `feature/3d-low-poly-project-rework`, as the owner asked.
- Ready-made assets first; author new ones only when strictly necessary.
- Every gameplay scene runs on Jolt with bodies locked to one plane, so the controls feel 2D.
  The lobby's motor makes its own one-way landings
  ([0042](docs/decisions/0042-plaza-lobby-jolt-plane.md)). The exception is a character the
  phone predicts: it runs a shared deterministic step written in GDScript and TypeScript,
  proven identical by a fixture ([0047](docs/decisions/0047-shared-deterministic-simulation.md)).

### Cubio

- Cubio is the one player character: a 2 m cube with a small bevel, floating 0.60 m hands
  and two feet, standing 2.62 m tall. Joins send `character_shape: "cubio"`, the only body.
- Source: `art/cubio/cubio-animated.blend`, scene `Cubio Animation Studio`, rig
  `Animation.Controls` with five controls, actions Idle, Walk, Run, Look Up, Crouch and
  Lever Pull at 24 fps. See [the Cubio README](art/cubio/README.md).
- Runtime: `assets/runtime/animated_characters/cubio/model/cubio.glb`, played by
  `characters/cubio_3d.tscn` (`Cubio3D`), tinted body, hands and feet. Its face is a
  `ShapeFace3D` on the model's `FaceAnchor`, placed by `cubio/face_anchor.json`, on host and
  phone alike ([0043](docs/decisions/0043-cubio-shape-face.md)).
- No jump or fall clip exists. In the air the lobby keeps whichever clip the motor reports.

### The plaza

- `art/playground_plaza/`: an authored café, billboard, table and rooftop logo sign (Blender
  sources, verified GLBs) plus KayKit glTF props (CC0). Runtime copies are in
  `assets/runtime/playground_plaza/`. See [the plaza README](art/playground_plaza/README.md).
- `art/` carries `.gdignore`, and the export filter excludes `art/**`.
- One world unit is one character height. GLBs are Y up with facades facing −Z.
- The table's pack-specific license is unresolved
  ([provenance](art/playground_plaza/table/source/PROVENANCE.md)). It blocks publication, not
  local work.

## How the code is laid out

`docs/architecture.md` is the file-by-file map; this is the part I hold in my head.

- Every launch runs one boot of Essential and Optional steps (`host/boot_steps.gd`,
  [0053](docs/decisions/0053-boot-steps-and-entry-points.md)); a scene asks for steps with an
  exported `boot_request`. `scenes/boot.*` asks for all of them and starts `SessionHost`,
  an autoload in `host/session_host.gd` that outlives scene changes and owns the HTTP and
  WebSocket services, the `PlayerRegistry` (at most ten players, reconnect tokens, 60 s
  grace), the minigame catalog and pre-minigame readiness.
- `host/websocket_service.gd` resolves every message to a host-owned player through its
  connection and routes it to whichever controller is registered: lobby, readiness, or a
  minigame's `MinigameProtocol`.
- `minigames/catalog.tres` lists `MinigameDefinition` resources. Each minigame has one folder,
  `minigames/NNN_name/`, with scenes, scripts, a protocol script, tuning and `tests/`, and its
  phone code in `web/src/NNN_name/`. Runtime art lives in `assets/runtime/minigames/<name>/`,
  including each booklet preview.
- `web/src/` is bundled by esbuild into the committed `web/public/app.js`. Rebuild after any
  TypeScript change; the check fails if `web/public/` is stale.
- `Tuning/Active Presets.tres` selects named tuning Resources. No runtime tuning UI exists, and
  only the owner promotes subjective feel into `Default`.
- `workshop/`: the shared minigame workshop window (presets, generated Tunables, live versus
  restart by each Resource's `LIVE_GROUPS`, pop-out panels). No pause or speed: the owner
  removed time controls because phones predict on their own clock. The phone view uses
  vendored `addons/godot_wry/` v1.0.2, which only draws in the main window, so that panel stays
  docked ([0054](docs/decisions/0054-workshop-phone-view-in-godot-wry.md)).
- `debug/`: F12 launcher with the Flappy Race workshop, the Shape Characters lab, the motion lab, a Tilt Shift factory
  review and one-player Bubbles.

### The lobby

- `scenes/lobby.tscn` is a `Control`: `World`, an instance of
  `scenes/lobby_playground_world.tscn`, and `ControlPanel` with the address picker, Refresh,
  Copy, minigame selector and `%StartMinigame`. The billboard shows the join QR.
- `LobbyPlaygroundWorld` (`Node3D`) reconciles registry players to ten seat-indexed spawn
  points, keeps a per-player input sequence, and turns `lobby_move`, `lobby_jump_release` and
  `lobby_fall_release` into motor calls after `PlatformInput.validate`.
- Each `PlazaLanding` marker inside a prop defines a landing: the ground (Closed), chair seats,
  tabletops and the café roof (Open).
- `characters/lobby_cubio.tscn` is the host body, a `CharacterBody3D` with `PlatformMotor`
  and its `Cubio3D` as a child.
- `components/platform_motor.gd` is generic plane-locked platform physics in world units:
  one-way landings and FALL as per-body collision exceptions, player bounce, run threshold, a
  350 ms input lease and a fall reset. `platform_surface.gd` is a `StaticBody3D` landing with
  the one-way flag and the Open/Closed drop rule. `platform_input.gd` rebuilds the phone's
  stance classification from `web/public/platform_input_settings.json`.
- Physics layers: 3D layer 8 holds lobby landings and walls (bit 128), layer 9 lobby
  characters (bit 256).

### Coupling the lobby has to respect

- `WebsocketService._lobby_controller` and `SessionHost.register_lobby_controller` are typed
  `LobbyController`, the small base of `LobbyPlaygroundWorld`, so naming the lobby loads no
  model. The lobby world provides `reconcile`, `handle_input`, `reset_sequence`,
  `clear_all_input` and `character_for`.
- `tests/e2e/host.gd` reads `lobby.world`, `lobby.start_button` and each character's motion,
  and clicks Start through real mouse events, so the button must be reachable on screen.
- `addons/standalone_build/standalone_build_policy.gd` lists required runtime paths by hand.
- The phone side needs no change while the lobby messages stay: `web/src/lobby_input.ts` maps
  the shared `PlatformControls` intent to them. Its axes are X right, Y up, as in Godot 3D.

## Engine and rendering facts

- Renderer: GL Compatibility on desktop and mobile. In 3D it lacks SDFGI, VoxelGI, SSAO, SSR
  and volumetric fog; check any effect against it before relying on it.
- 3D physics is Jolt. Window 1920×1080, `canvas_items` stretch, `expand` aspect.

## Working rules I must not drift from

Condensed from AGENTS.md and the documents it links.

- Five phases: question the task, plan the implementation, implement, verify, pull request.
  Phases 1 and 2 end at a checkpoint where I stop and wait. The implementation plan is never
  committed.
- Commit locally in small, working steps. Never push or open a pull request without the
  owner's approval.
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
  numbered records, never edited to change a decision; the next free number is 0055. The
  roadmap changes when work finishes or is added.
- No ticket numbers anywhere: files, comments, tests or output folders.
- Typed GDScript, composition, signals, Control/Container UI and no fixed viewport sizes.
  Dictionaries are being pushed to the edges ([0019](docs/decisions/0019-typed-classes.md)).
- Test scripts extend `TestScript` and put their body in `_run()`. Any logged error fails the
  script, and so does anything still held at exit.
- Every minigame has a workshop on the shared design, planned with the minigame
  ([0052](docs/decisions/0052-a-workshop-for-every-minigame.md)).
- Every normal minigame launch goes through the Pre-minigame screen. A plan that skips it must
  carry the bold uppercase warning from [player-journeys.md](docs/player-journeys.md).
- Temporary art variants go in ignored `scratch/` or `comparisons/`, never in commits.

## This machine

- Windows 11; Bash and PowerShell are both available. `GODOT_BIN` points at
  `C:\Users\backup pc\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe`; there is no
  `godot` on PATH. Node is v24. Blender 5.2 is at
  `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
- Run `node tools/setup.mjs` in a fresh worktree before formatting, linting or checking.
- Known Windows flakes: some Tilt Shift tests can exit `3221225477` at native shutdown with zero
  failures, and the bundle rewrite can hit a user-mapped-section lock. Both count as failures
  to report separately, never as passes ([roadmap](docs/roadmap.md#known-bugs)).
- Close any running host before the browser suite; it uses ports 18080/18081 and the
  end-to-end test uses 18200/18201.
