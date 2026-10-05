# Architecture

Which script or scene owns what. Use it to find where a behavior lives before changing it.
Messages and limits are in [protocol.md](protocol.md).

## Boot and host services

- `scenes/boot.*` starts the services and presents Retry after a startup failure.
- `host/session_host.gd` persists the services and the registry across scene changes. It
  discovers addresses, constructs URLs, and rolls HTTP back if WebSocket binding fails.
- `host/http_service.gd` serves a fixed asset allowlist with bounded requests. It never serves
  a client-selected filesystem path.
- `host/websocket_service.gd` owns bounded protocol-1 peers and messages. It resolves each
  connection to a host-owned player before forwarding gameplay input, and keeps one active
  protocol at a time.
- `host/player_registry.gd` owns session, player and token identities, names, validated
  character shape and color, capacity, reconnect grace, resume and explicit leave.

## Lobby

- `scenes/lobby.*` places the live QR and address controls, and minigame selection and start,
  on the Playground's board and calendar.
  - There is no visible roster. `SessionHost.players_changed` still refreshes the shared 2–10
    player launch gate.
  - The FHD control positions and the `PanelBackings` sprite transforms are the main UI tuning
    points. Godot's `canvas_items` stretch scales them to the 1152×648 host size.
- `scenes/lobby_playground_world.tscn` is the reusable 1920×1080 toy-shelf world.
  - It imports selected layers, props, a blank QR board and calendar, and a separate logo under
    `assets/runtime/lobby_playground/`.
  - `PanelBackings` sits behind `CharactersFrontOfPanels`. Characters draw over the live QR and
    the other lobby controls, while `Foreground` draws over characters.
  - One-way shelves and block tops use physics layer 8 (bit 128). Characters use layer 9
    (bit 256) and mask both layers.
- `scenes/lobby_playground_world.gd` reconciles registered players to ten seat-indexed
  `FutureCharacterAnchors`.
- `characters/lobby_squircle.tscn` composes the shared `PlatformMotor` with Squircle playback,
  the player lifecycle and a nameplate.

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
- `scenes/pre_minigame_screen.tscn` uses editable Bubbles content in
  `bubbles_pre_minigame_content.tres`, in the minigame's folder, and a curated gameplay capture
  in `assets/runtime/pre_minigame/bubbles_preview.png`.

## Bubbles and Jellyfishes

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
export policy's list of required paths.

Every file named in this section is in `minigames/002_bubbles_and_jellyfishes/`. The gameplay
shared-screen scene is `bubbles_and_jellyfishes.tscn`.

### Round

- `bubbles_round_controller.gd` owns the entrance, countdown, active and results
  lifecycle, the score and pop state, the host-time finish freeze, and snapshots keyed by
  player ID.
- `bubbles_gesture_classifier.gd` validates and classifies one completed normalized trace.

### Player bubbles

- `bubbles_player_bubble.tscn` reuses `SquircleV1Playback` in a procedural
  translucent bubble with a per-instance circle collider, capped approved small-jellyfish art,
  and a readable name.
- `bubbles_player_visual.gd` draws the iridescent rim, the live directional drag pull, the
  charge glow and wobble, the authoritative spin surface and particles, and the pop fragments.
- `bubbles_player_bubble.gd` animates the audience-facing character from accepted swipe events
  and keeps the charge cue on the bubble.
- Visual deformation and burst radius never drive collision.
- `bubbles_player_arena.gd` creates 1–10 bodies. It steps movement, invisible bounds and
  player pairs in sorted player-ID order.
  - Call `setup(controller, npc_bounds, optional_wall_bounds)`, then
    `add_bubble(player_id, position)` from the controller's participant snapshot.
  - Call `simulate_step(fixed_delta, host_time_msec)` from the host physics loop: normally
    1/60 second, at most 0.05.
  - `bounds` retains the logical NPC play area. Player bubbles use the optional wall bounds.
  - The arena settles the controller clock before movement, so exact-zero results freeze
    first.
  - Bodies consume only the controller's accepted swipe, spin and pop signals, and score
    snapshots.

### Creatures

- `bubbles_creature_arena.gd` owns the free jellyfish and pufferfish scenes, the
  initial safe spawns, the alternating waves, the warning and crossing paths, and the host-time
  collection and hit checks.
- The shared-screen scene creates player bodies, then calls `setup(controller, player_arena)`
  before `complete_entrance()`.
- Each fixed host step calls the player arena first, then
  `creature_arena.simulate_step(fixed_delta, host_time_msec)` with the same time.
- The controller alone accepts collections and pops. Creature sprites never decide rules.
- Free jellyfish obey the tuning cap, including scatter after a pop. Overflow is reported by
  `jellyfish_scattered` and discarded.

### Presentation

- `BubblesPresentation` consumes the prepared host launch, observes registry reconnect and
  leave changes, registers its controller for the round, and unregisters it on exit.
- It derives the player-bubble wall bounds from the visible viewport rectangle at launch and on
  resize. Wall padding uses each bubble's transformed radius, so its visible edge meets the
  viewport edge. NPC boundary behavior remains separate.
- The scene owns fixed-order arena stepping, entrance, countdown, timer, approved background
  layers, semantic audio, debug labeling, results and the host return button.
- There is no in-game instruction card, on normal or F12 launches.

### Protocol

- `bubbles_protocol.gd` validates completed normalized traces and makes personalized
  Bubbles snapshots. The messages are in [protocol.md](protocol.md#bubbles-input).
- The browser never supplies a player ID or host time.

## Tilt Shift rules

`minigames/003_tilt_shift/tilt_shift_shift_controller.gd` owns equal teams, frozen
shift content, rounds, deadlines, cumulative scores, ball resolution, assignments
and held angles. The [rules contract](../minigames/003_tilt_shift/README.md)
describes its typed host calls and signals for later consumers.

The allocator returns inspectable neighbor/conflict diagnostics. Selected Resources
are in the [field guide](../minigames/003_tilt_shift/tuning/README.md). The arena,
motion, workshop, phone presentation and catalog/lobby launch are not integrated yet.

## Characters

- `characters/character_selection.gd` normalizes missing and legacy shapes to Squircle while
  preserving selected colors. `web/src/character_selection.ts` offers colors and sends
  `squircle`.
- `characters/squircle_v1_playback.tscn` plays manifest-owned sheets in the lobby, Bubbles and
  results.
- The canonical editable model and actions are in `art/squircle/squircle-animated.blend`.
  30 runtime sheets and their frame and anchor manifest live in
  `assets/runtime/animated_characters/squircle/v1/`. The Playground lobby, the Bubbles shared
  screen and the phone consume that same v1 set.
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
- Ready-up shows one host-confirmed READY/CANCEL toggle, without gameplay controls, preview or
  booklet.
- `web/src/squircle_v1.ts` draws manifest-owned front idle sheets in setup and in the player's
  personalized Bubbles snapshot.
- What the phone screens do is in [phone-client.md](phone-client.md).

## Assets, addons and tests

- `assets/runtime/` is the curated runtime-media boundary. Source and archive art remains
  outside it and is excluded from Godot import and export.
- Bubbles static art lives in `assets/runtime/minigames/bubbles_and_jellyfishes/`. Its
  [asset guide](../assets/runtime/minigames/bubbles_and_jellyfishes/README.md) records scale,
  filtering, layer composition and provenance.
- [GIMP regeneration and isolated export-pack checks](../art/bubbles/README.md) remain
  separate from gameplay implementation.
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
  `minigames/002_bubbles_and_jellyfishes/tuning/Default.tres` and
  `Tuning/Shared/Networking/Default.tres`.
- Restart to apply a changed selection.
- Bubbles field descriptions are in the `README.md` beside its `Default.tres`.
- Only the human owner promotes subjective feel into `Default`. Tests establish configuration
  safety, not fun or comfort.

For Inspector help in a tuning script:

- Put a `##` documentation comment directly before the property and its export annotation.
- Use `@export_group`, not `@export_category`, because categories can break the property help
  that follows them.
- `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.
