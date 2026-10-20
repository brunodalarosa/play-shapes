# Architecture

Which script or scene owns what. Use it to find where a behavior lives before changing it.
Messages and limits are in [protocol.md](protocol.md).

## Boot and host services

- `scenes/boot.*` starts the services and presents Retry after a startup failure.
- `host/session_host.gd` persists the services and the registry across scene changes. It
  discovers addresses, constructs URLs, and rolls HTTP back if WebSocket binding fails.
- A catalog definition may name a `session_script`. SessionHost creates that session on first
  use and lets it prepare players, gate READY and the launch, and follow the roster, from the
  Pre-minigame screen into play ([decision 0039](decisions/0039-minigame-session-scripts.md)).
  Tilt Shift 3D uses one; Tilt Shift keeps its own branch until it is retired.
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
  - `Simulation` is a hidden 2D plane, 96 pixels per unit, where the world builds one one-way
    `PlatformSurface` per landing on physics layer 8 (bit 128). Characters use layer 9
    (bit 256). See [decision 0033](decisions/0033-plaza-lobby-plane-simulation.md).
  - Two invisible side walls on the same layer keep characters in view. `fit_walls()` places
    them from the camera whenever the view resizes, so a character stops with its centre on
    the screen edge, half out of view. The ground runs past both walls.
  - `scenes/plaza_billboard.*` draws the logo and the live join QR in a `SubViewport` that
    renders only when they change, shown unshaded on the billboard's `Display` surface.
- `scenes/lobby_playground_world.gd` reconciles registered players to ten seat-indexed
  `SpawnPoints` and places each body's 3D Squircle every frame.
- `characters/lobby_squircle.tscn` is the host body: the shared `PlatformMotor`, a capsule and
  the player lifecycle. It drives its `Squircle3D` and frees it on exit.
- `Tuning/Shared/Lobby/Default.tres` holds the movement preset, in character heights, selected
  in `Active Presets.tres`.

## Platform movement

The reusable parts behind the lobby characters. Setup and reuse are in
[platform-phone-controller.md](platform-phone-controller.md#host-components-and-platform-setup).

- `PlatformMotor` exposes speed, acceleration, gravity, jump impulse, player bounce, run
  threshold, input lease, fall-reset height and drop timing in its Inspector.
- `PlatformSurface` exposes an independent **Drop Rule: Open/Closed** on all eleven surfaces.
  Only `BottomShelf` is Closed.
- Select `PlatformSurfaces/<name>` in the world scene to change one rule without touching art,
  shape alignment or one-way collision.

## Ready screen

- `host/pre_minigame_readiness.gd` owns one selected round's ordered roster and its ready
  state, keyed by player ID.
- `SessionHost` starts or cancels it, and closes registration before the single launch
  transition.
- `WebsocketService` admits final joins only from onboarding sockets already open at Start,
  resolves ready actions through each registered connection, and sends personalized ready
  snapshots on resume.
- `scenes/pre_minigame_screen.tscn` uses editable Bubbles and jellyfishes 3D content in
  `bubbles_3d_pre_minigame_content.tres`, in the minigame's folder, and a curated gameplay capture
  in `assets/runtime/pre_minigame/bubbles_preview.png`.
- Every normal catalog launch uses this screen. Journey requirements and plan warnings are
  in [player journeys](player-journeys.md).

## Minigame catalog and Bubbles and jellyfishes 3D

A minigame has one folder under `minigames/`, named with its number and name
([decision 0015](decisions/0015-one-folder-per-minigame.md)). It holds the minigame's scenes,
scripts, protocol script and tuning script, its presets in `tuning/` and its tests and render
helpers in `tests/`. Its phone code is in the folder of the same name under `web/src/`, and
its browser tests in the one under `web/tests/`. Art sources and runtime assets stay under
`art/` and `assets/runtime/`.

The shared code learns about a minigame from the catalog, `minigames/catalog.tres`
([decision 0024](decisions/0024-minigame-catalog.md)):

- The catalog lists one `MinigameDefinition` per minigame: its id, its name, the path of its
  scene, its largest number of players, the path of its ready-screen content, and whether the
  debug menu offers a one-player round.
- `SessionHost` owns the catalog. The lobby fills its picker from it in the catalog's order,
  the host takes the scene, the name and the player limit from it, the ready screen loads its
  content through it, and the debug menu derives its one-player scenarios from it.
- `tests/minigame_catalog_test.gd` checks that every definition names things that exist.

To add a minigame: make its folder, save a `MinigameDefinition` in it, and add that
definition to the catalog. Three places still name each minigame by hand: its slot in
`Tuning/Active Presets.tres`, the phone asset routes in `host/http_service.gd`, and the
export policy's list of required paths. A minigame whose protocol extends `MinigameProtocol`
needs no change to the WebSocket service.

Minigame 004, Bubbles and jellyfishes 3D, lives in `minigames/004_3d_bubbles/`. It has no spin
move; `tests/bubbles_3d_no_spin_test.gd` in its folder checks that. Its gameplay runs on Jolt
with plane-locked bodies ([decision 0034](decisions/0034-bubbles-3d-jolt-plane.md)).

- `bubbles_3d_round_controller.gd` owns the entrance, countdown, active and results phases,
  scores, pops and scatter counts, the zero-time freeze, ranking, disconnects and leaves.
- `bubbles_3d_player_arena.gd` creates up to ten `Bubbles3DPlayerBubble` rigid bodies inside
  `PlaneWalls3D` and reports bumps. Each bubble owns its shell, its Squircle with
  `Bubbles3DHandWobble`, and an instanced batch of caught jellyfishes.
- `bubbles_3d_creature_arena.gd` owns jellyfish waves, safe spawns, scatter, pufferfish
  crossings and their warnings. Jellyfishes and pufferfishes are `Area3D` sensors; free
  jellyfishes draw through one `Bubbles3DJellyfishSwarm`.
- `bubbles_3d_presentation.gd` and `3d_bubbles.tscn` frame the plane through a fixed 30 degree
  camera, dress the seabed, run the entrance, countdown, timer, nameplates, audio and results,
  register `Bubbles3DProtocol` for the round and step both arenas each physics frame.
- `bubbles_3d_protocol.gd` validates touches and releases, times holds on the host and pushes
  snapshots, feedback and visuals. The messages are in
  [protocol.md](protocol.md#bubbles-and-jellyfishes-3d).

## Tilt Shift 3D

Minigame 005 rebuilds Tilt Shift in 3D, in `minigames/005_3d_tilt_shift/`. Its rules are the
2D Tilt Shift's, copied and renamed; it shares no code, scene, resource, message or phone
module with 003, and `tests/tilt_shift_3d_independence_test.gd` in its folder checks that.
[Its README](../minigames/005_3d_tilt_shift/README.md) lists what each script owns.

- The arena simulates on Jolt with plane-locked bodies, as 004 does, and fills the frame with
  the floor raised for the bins ([decision 0038](decisions/0038-tilt-shift-3d-full-width-frame.md)).
- Paddles are rounded bars built in code with a matching convex collider
  ([decision 0036](decisions/0036-tilt-shift-3d-generated-paddle.md)), each with a composed face
  ([decision 0037](decisions/0037-shape-face-system.md)).
- `tilt_shift_3d_session.gd` is the catalog's session script; `tilt_shift_3d_protocol.gd` is a
  `MinigameProtocol`. The messages are in [protocol.md](protocol.md#tilt-shift-3d).
- `addons/tilt_shift_3d_workshop/` is its editor workshop, and `debug/tilt_shift_3d_review.tscn`
  its simulated F12 review.

## Shared 3D components

These live outside any minigame folder so later 3D scenes can use them.

- `components/plane_3d/`: `PlaneLock3D` locks a body's depth and rotation; `PlaneWalls3D`
  builds invisible edge walls on their own physics layer.
- `components/bubble_shell/`: `BubbleShell3D`, a translucent shader sphere with stretch, pop
  droplets and re-form.
- `components/underwater_environment/`: the water backdrop, god rays, seabed with caustics,
  depth haze and air bubbles, plus a recolouring prop material with optional sway.
- `components/screen_follow_label.gd`: screen text that follows a 3D node.
- `components/rounded_bar/`: `RoundedBar` builds a bar's rounded outline, mesh and convex
  collider from its length, thickness, depth and corner radius.
- `components/shape_face/`: the shape character face. `ShapeFaceManifest` reads the shared
  face parts and presets, `ShapeFaceExpressions` keeps timed expressions with priorities and
  natural blinks, and `ShapeFace3D` and `ShapeFace2D` draw a face in 3D or in a Control.

## Tilt Shift rules

`minigames/003_tilt_shift/tilt_shift_shift_controller.gd` owns equal teams, frozen
shift content, layout exposure history, participant selection, readiness, countdown,
round deadlines, cumulative scores, ball resolution, assignments and held angles.
The [rules contract](../minigames/003_tilt_shift/README.md)
describes its typed host calls and signals for later consumers.

The allocator returns inspectable neighbor/conflict diagnostics. Selected Resources
are in the [field guide](../minigames/003_tilt_shift/tuning/README.md).

`TiltShiftArena` owns shared physics and delivery beneath its rules controller.
`TiltShiftMotionController` owns capture preparation, calibration and active-consumer
lifecycle; each `TiltShiftTiltInput` holds one player's neutral and continuous input.
It consumes WebsocketService's keyed raw channels and supplies validated host angles
to the rules. See [motion input](motion-input.md#tilt-shift-control).

`TiltShiftPresentation` wraps the arena with imported factory artwork, physical-body
beam visuals, one cosmetic operator per participant and host-derived score/time/result
feedback. The editor workshop gameplay preview uses that same presentation scene.

`TiltShiftSession`, a SessionHost child, carries preparation into the gameplay wrapper,
attaches mapped rounds after shared all-player readiness, routes round readiness and retires
capture on results or exit.
Preparation transitions remain in the round controller. `TiltShiftProtocol`
copies accepted state into personalized snapshots. The catalog lists the normal
2/4/6/8/10-player entry; the separately labeled F12 review uses simulated controls.
See [player journeys](player-journeys.md).

## Characters

- `characters/character_selection.gd` normalizes missing and legacy shapes to Squircle while
  preserving selected colors. `web/src/character_selection.ts` offers colors and sends
  `squircle`.
- `characters/squircle_3d.tscn` is the real-time Squircle used by the Playground lobby: the
  exported rig and clips, the player tint, natural blinking, held stances, turning toward
  travel and a nameplate.
  - Its shaders, `squircle_tint` and `squircle_face`, draw the character in front of any
    scenery within `front_push` (2 units) of it. Each vertex moves toward the camera along
    its view ray, so its place on screen and the character's own layering are unchanged.
    Shadow passes are left alone. Nothing in the plaza may stand in front of a character
    within that distance.
- `characters/squircle_v1_playback.tscn` plays manifest-owned sheets in the ready screen,
  results and the Animation Lab.
- The canonical editable model and actions are in `art/squircle/squircle-animated.blend`.
  30 runtime sheets and their frame and anchor manifest live in
  `assets/runtime/animated_characters/squircle/v1/`. The ready screen and the phone consume
  that same v1 set. `art/squircle/export_glb.py` exports the rigged model to `model/` in that
  folder.
- After exporting and packing, run `art/squircle/sync_runtime.py` to refresh the runtime set.
  See the [source workflow and pose tuning](../art/squircle/README.md).

### Loops and held stances

- Runtime clip metadata distinguishes `playback: loop` (idle, walk, run) from
  `playback: held` (look_up, crouch).
- `SquircleV1Playback.play(action, view)` enters a held stance once and sustains its final
  frame.
- Another request reverses current progress to the shared idle neutral before entering the
  latest requested action.
- Re-pressing the current stance cancels the release without restarting.
- `advance_playback(delta)` drives normal and slowed review. `seek_clip(action, view,
  milliseconds)` inspects an exact clip time.
- Stances keep the feet and ground anchor fixed, with independent color and face or blink
  layers.
- The shared host motor chooses these stances only while grounded. Crouch retains the full
  upright collider and the same floor anchor.

## Debug menu

- `debug/` contains the non-pausing F12 scenario catalog and the debug scenes. The launcher
  remains present in development exports.
- **Tilt Shift 3D factory · simulated controls** opens `debug/tilt_shift_3d_review.tscn`: ten
  synthetic players tilt through a whole shift, with no phones and no launch eligibility.
- **Animation Lab** opens `debug/animation_lab/animation_lab.tscn`.
  - It inspects the manifest's ten Squircle v1 action and view pairs at 256, 128 and the actual
    lobby scale (0.58).
  - It has color, natural or forced blink, pause, speed, and release and re-enter controls.
  - It uses `SquircleV1Playback` directly.
  - Its focused check is
    `godot --headless --path . --script res://tests/squircle_animation_lab_test.gd`.
- The motion lab is described in [motion-input.md](motion-input.md).

## Phone client

- `web/src/` is the TypeScript source. The build bundles it into one script,
  `web/public/app.js`, which is committed and served by Godot with the page, the styles and
  the icons beside it. Normal play needs neither Node nor Internet. See
  [browser-build.md](browser-build.md).
- The phone onboarding keeps the socket available while players choose a Squircle color and
  enter a name. The host creates the player record only on the final join submission.
- Ordinary ready-up shows one host-confirmed READY/CANCEL toggle. Tilt Shift additionally
  exposes permission and neutral calibration; its phone shows one canonical team paddle
  as a movement guide. Preview and instructions remain on the shared screen.
- Tilt Shift 3D keeps the same preparation and shows the player's own paddle in 3D through
  `web/src/005_3d_tilt_shift/`, with a flat drawing without WebGL. `web/src/shape_paddle/`
  holds the rounded outline and the face composition; `web/src/three_view/shape_paddle.ts`
  draws them with three.js.
- `web/src/squircle_v1.ts` draws manifest-owned front idle sheets in setup.
- `web/src/screen_wake_lock.ts` owns one visible-page wake lock across every phone screen,
  independent of the active minigame or socket. It adds no host state or messages.
- What the phone screens do is in [phone-client.md](phone-client.md).

## Tilt Shift

Tilt Shift's [host contract](../minigames/003_tilt_shift/README.md) describes its separate
rules controller and shared gameplay/preview physics arena. The arena owns live bodies and
delivery; its controller owns rounds, assignments, deadlines and scores. Physics snapshots
copy the launch-frozen selected profile; no extra autoload or network message is involved.

`addons/tilt_shift_workshop/` owns editor-only deep-copied drafts and geometry guides.
Its separate preview process runs the same arena/controller with designer input; it
does not start phone services. [The workshop guide](../minigames/003_tilt_shift/tuning/WORKSHOP.md)
describes saving, explicit active selection and preview isolation.

## Assets, addons and tests

- `assets/runtime/` is the curated runtime-media boundary. Source and archive art remains
  outside it and is excluded from Godot import and export.
- The models of minigame 004, Bubbles and jellyfishes 3D, live in
  `assets/runtime/minigames/bubbles_3d/`. Their sources and provenance are in
  [art/bubbles_3d](../art/bubbles_3d/README.md).
- The face parts shared by every minigame, 8× PNGs and the preset manifest that composes them
  into the owner's twelve faces, live in `assets/runtime/shape_faces/`. Their vector masters
  and provenance are in
  [art/shape_characters_face_system_assets](../art/shape_characters_face_system_assets/README.md).
- The bin, factory props, trash emblem and booklet preview of minigame 005, Tilt Shift 3D,
  live in `assets/runtime/minigames/tilt_shift_3d/`. Their sources and provenance are in
  [art/tilt_shift_3d](../art/tilt_shift_3d/README.md). The host serves the face parts to the
  phone from `assets/runtime/shape_faces/`.
- `addons/standalone_build/` is the editor-only Windows builder.
  `addons/kenyoni/qr_code/` is the required vendored runtime QR dependency.
- `tests/` holds focused headless, integration, policy and render checks of the shared code. A
  minigame's own are in its `tests/` folder. Generated evidence belongs under ignored
  `test-results/`.

## Tuning

`Tuning/` contains the active selector, the shared named resources, a guide and an experiment
template. A minigame's named resources are in its own `tuning/` folder. There is no runtime
tuning UI.

- Open `Tuning/Active Presets.tres` to select named resources. The current front doors are
  `minigames/004_3d_bubbles/tuning/Default.tres`,
  `minigames/005_3d_tilt_shift/tuning/Default.tres` and `Tuning/Shared/Networking/Default.tres`.
- Restart to apply a changed selection.
- Field descriptions for Bubbles and jellyfishes 3D and Tilt Shift 3D are in the `README.md`
  beside each `Default.tres`.
- Only the human owner promotes subjective feel into `Default`. Tests establish configuration
  safety, not fun or comfort.

For Inspector help in a tuning script:

- Put a `##` documentation comment directly before the property and its export annotation.
- Use `@export_group`, not `@export_category`, because categories can break the property help
  that follows them.
- `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.
