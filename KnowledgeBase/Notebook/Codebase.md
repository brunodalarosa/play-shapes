---
area: Notebook
tags: [system, stub]
code: [PlatformSurface, PlatformMotor, web/src/flappy_flight, ShapeFaceExpressions, ShapeFace3D, assets/runtime/shape_faces]
verified:
branch:
---

# Architecture

Hub: [[Notebook]].

Which script or scene owns what. Use it to find where a behavior lives before changing it.
Messages and limits are in [[Message Protocol]].

## Boot and host services

- Every launch runs one boot ([[0053-boot-steps-and-entry-points|0053]]).
  `host/boot_steps.gd` names the steps, their order and what each needs. Presets is the one
  Essential step; the others run only when an entry lists them.
- An entry lists its steps in a `BootRequest` (`host/boot_request.gd`), exported as
  `boot_request` on its scene root. `SessionHost` boots the launched scene once it is in the
  tree and logs a failed step. A scene that lists nothing runs the Essential steps only.
- `scenes/boot.*` is the full game. It asks for every step through
  `host/full_game_boot_request.tres`, boots itself and presents Retry after a failure.
- `servers_this_pc` starts HTTP and WebSocket on 127.0.0.1 without TLS or the network file.
- `host/session_host.gd` persists the services and the registry across scene changes. It
  discovers addresses, constructs URLs, and rolls HTTP back if WebSocket binding fails. The
  registry and catalog load on first use, and `steps_run` lists the steps that have run.
- `host/lobby_controller.gd` is what the services call on the lobby world, so naming the
  lobby loads none of its scenes or models.
- A catalog definition may name a `session_script`. SessionHost creates that session on first
  use and lets it prepare players, gate READY and the launch, and follow the roster, from the
  Pre-minigame screen into play ([[0039-minigame-session-scripts|decision 0039]]).
  Tilt Shift 3D uses one.
- `host/http_service.gd` serves a fixed asset allowlist with bounded requests. It never serves
  a client-selected filesystem path.
- `host/websocket_service.gd` owns bounded protocol-1 peers and messages. It resolves each
  connection to a host-owned player before forwarding gameplay input, and keeps one active
  protocol at a time. A minigame can register a `MinigameProtocol` subclass
  (`host/minigame_protocol.gd`): the service then routes the message types it handles to it and
  sends what it asks for, with no minigame-specific code in the service.
- `host/player_registry.gd` owns session, player and token identities, names, validated
  character shape and color, capacity, reconnect grace, resume and explicit leave.

## Lobby

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

## Platform movement

The reusable parts behind the lobby characters. Setup and reuse are in
[[Platform Controller#Host components and platform setup]].

- `PlatformMotor` exposes speed, acceleration, gravity, jump impulse, player bounce, run
  threshold, input lease, fall-reset height and drop timing in its Inspector.
- `PlatformSurface` carries an independent **Drop Rule: Open/Closed** for each landing. Only
  the ground is Closed.
- Select a prop's `Landing` marker in the world scene to change its rule without touching the
  model or its placement.

## Ready screen

- `host/pre_minigame_readiness.gd` owns one selected round's ordered roster and its ready
  state, keyed by player ID.
- `SessionHost` starts or cancels it, and closes registration before the single launch
  transition.
- `WebsocketService` admits final joins only from onboarding sockets already open at Start,
  resolves ready actions through each registered connection, and sends personalized ready
  snapshots on resume.
- `scenes/pre_minigame_screen.tscn` uses editable Bubbles and jellyfishes 3D content in
  `bubbles_3d_pre_minigame_content.tres`, in the minigame's folder, and a four-player gameplay
  capture in `assets/runtime/minigames/bubbles_3d/bubbles_3d_preview.png`.
- Every normal catalog launch uses this screen. Journey requirements and plan warnings are
  in [[Journey Change Rules|player journeys]].

## Minigame workshops

The shared parts of every workshop live in `workshop/`, outside any minigame folder, as
[[Minigame Workshops|Minigame workshops]] designs them. Workshops and
`workshop/` are left out of the exported game.

- `workshop_window.gd` (`WorkshopWindow`) is the window: the top bar and the four panels. A
  minigame's workshop scene calls `setup` with its presets and its Active Presets field, fills
  the first three panels and restarts its game on `restart_requested`.
- `workshop_dockable_panel.gd` pops a panel out into its own window and docks it back;
  `workshop_layout.gd` remembers the layout in `user://workshops/`.
- `workshop_tuning.gd` (`WorkshopTuning`) holds the preset as saved, as edited and as running,
  with undo. A tuning Resource lists its live export groups in `LIVE_GROUPS`; other edits wait
  for a restart. `workshop_tunable.gd` is one value, found from the Resource's exports.
- `workshop_tunables_panel.gd` and `workshop_tunable_row.gd` draw the Tunables panel.
- `workshop_presets.gd` reads and writes a minigame's preset files, and
  `workshop_game_preset.gd` changes its one line of `Tuning/Active Presets.tres`.
- `workshop_phone_view.gd` shows the phone page in godot-wry, signed in as the designer
  ([[0054-workshop-phone-view-in-godot-wry|0054]]).
- `workshop_boot_request.tres` asks the boot for the servers bound to this PC only.
- `workshop_theme.gd` (`WorkshopTheme`) builds the Material Design 3 theme the window wears
  ([[0055-material-design-3-for-workshops|0055]]), with the fonts in `fonts/`.

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

## Characters

- `characters/character_selection.gd` normalizes missing and legacy shapes to Cubio while
  preserving selected colors. `web/src/character_selection.ts` offers colors and sends
  `cubio`.
- `characters/cubio_3d.tscn` is the real-time Cubio used by the Playground lobby: the
  exported rig and clips, the player tint, a shape face, held stances, turning toward
  travel and a nameplate.
  - The face is a `ShapeFace3D` on the model's `FaceAnchor`, placed by
    `assets/runtime/animated_characters/cubio/face_anchor.json` and driven by a
    `ShapeFaceExpressions` that shows `face_slightly_smiling` and blinks.
  - Its tint shader and the face's parts draw the character in front of any
    scenery within `front_push` (2 units) of it. Each vertex moves toward the camera along
    its view ray, so its place on screen and the character's own layering are unchanged.
    Shadow passes are left alone. Nothing in the plaza may stand in front of a character
    within that distance.
- `characters/cubio_preview.gd` renders a Ready-screen row of live Cubio instances in one
  isolated 3D viewport. Readiness and color updates reuse existing instances.
- The canonical model and six actions are in `art/cubio/cubio-animated.blend`. The body is
  a two-metre cube with a small bevel; the floating limbs and rig retain their transforms.
- `art/cubio/export_glb.py` exports the model and two face textures to
  `assets/runtime/animated_characters/cubio/model/`. Both host and phone consume that model.
  See the [[Cubio Source and Export|source workflow]].

### Loops and held stances

- Runtime clip metadata distinguishes `playback: loop` (idle, walk, run, lever pull) from
  `playback: held` (look_up, crouch).
- `Cubio3D.play(action)` enters a held stance once and sustains its final
  frame.
- Another request reverses current progress to the shared idle neutral before entering the
  latest requested action.
- Re-pressing the current stance cancels the release without restarting.
- Stances keep the feet and ground anchor fixed, with independent color and face or blink
  layers.
- The shared host motor chooses these stances only while grounded. Crouch retains the full
  upright collider and the same floor anchor.

## Debug menu

- `debug/` contains the non-pausing F12 scenario catalog and the debug scenes. The launcher
  remains present in development exports.
- **Flappy Race workshop** opens its workshop; see [[#Minigame workshops]].
- **Tilt Shift 3D factory · simulated controls** opens `debug/tilt_shift_3d_review.tscn`: ten
  synthetic players tilt through a whole shift, with no phones and no launch eligibility.
- **Shape Characters lab** opens `debug/shape_characters_lab/shape_characters_lab.tscn`. Three
  quarters of the width show a Cubio turned by mouse drag; a tabbed panel picks the model and
  join colour, plays each clip once with pause, restart, stop and speed, and picks any face.
- The lab's Face tab toggles blinking and moves and scales the face. Save writes the placement
  to Cubio's `face_anchor.json`, the game's default, which an export cannot write.
- The motion lab is described in [[Motion Input]].

## Phone client

- `web/src/` is the TypeScript source. The build bundles it into one script,
  `web/public/app.js`, which is committed and served by Godot with the page, the styles and
  the icons beside it. Normal play needs neither Node nor Internet. See
  [[Browser Build]].
- The phone onboarding keeps the socket available while players choose a Cubio color and
  enter a name. The host creates the player record only on the final join submission.
- Ordinary ready-up shows one host-confirmed READY/CANCEL toggle. Preview and instructions
  remain on the shared screen.
- Tilt Shift 3D additionally exposes permission and neutral calibration, and shows the player's
  own paddle in 3D through `web/src/005_3d_tilt_shift/`, with a flat drawing without WebGL.
  `web/src/shape_paddle/` holds the rounded outline and the face composition;
  `web/src/three_view/shape_paddle.ts` draws them with three.js.
- Flappy Race flies the player's own Cubio through `web/src/006_flappy_race/`. `race_clock.ts`
  reads the host's clock, `prediction.ts` predicts the flight on `web/src/flappy_flight/` and
  corrects it from host state, `view.ts` draws it with three.js and `fallback.ts` flat,
  `hud.ts` shows the hearts and text, and `phone.ts` ties them to the surface.
- `web/src/character_preview.ts` mounts a live 3D Cubio only in the visible setup canvas.
  Its renderer is in `web/src/three_view/character_preview.ts`; model and face downloads are
  cached with gameplay's assets. Hidden setup screens release their renderer.
- `web/src/screen_wake_lock.ts` owns one visible-page wake lock across every phone screen,
  independent of the active minigame or socket. It adds no host state or messages.
- What the phone screens do is in [[Phone Web App]].

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

## Tuning

`Tuning/` contains the active selector, the shared named resources, a guide and an experiment
template. A minigame's named resources are in its own `tuning/` folder. The game has no
runtime tuning UI; a minigame's workshop edits its presets.

- Open `Tuning/Active Presets.tres` to select named resources. The current front doors are
  `minigames/004_3d_bubbles/tuning/Default.tres`,
  `minigames/005_3d_tilt_shift/tuning/Default.tres`,
  `minigames/006_flappy_race/tuning/Default.tres` and `Tuning/Shared/Networking/Default.tres`.
- Restart to apply a changed selection.
- Field descriptions for Bubbles and jellyfishes 3D, Tilt Shift 3D and Flappy Race are in the
  `README.md` beside each `Default.tres`.
- Only the human owner promotes subjective feel into `Default`. Tests establish configuration
  safety, not fun or comfort.

For Inspector help in a tuning script:

- Put a `##` documentation comment directly before the property and its export annotation.
- Use `@export_group`, not `@export_category`, because categories can break the property help
  that follows them.
- `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.
