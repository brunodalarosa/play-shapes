# Play Shapes development

This is the compact implementation manual for the current checkout. It records how the project works now, how to run and verify it, and operational caveats that are easy to rediscover. It is not the planning system or the task history.

## Current status

- Godot 4.7.2 is the authoritative host; phone controllers are bundled HTML/CSS/JavaScript clients over local HTTP and WebSockets.
- The lobby opens a shared ready screen for **Bubbles and Jellyfishes** with 2–10 registered players. Bubbles starts after every current participant is ready.
- Registered players appear as Squircle v1 characters in the Playground lobby and steer them from a portrait phone stick and jump button. Squircle v1 is also the current character in Minigame 002 and phone setup.
- F12 provides a one-real-player Bubbles debug scenario and the Squircle Animation Lab. It creates no simulated player; Bubbles labels its debug round on the host and phone.
- The host defaults to a responsive 1920×1080 GL Compatibility presentation.
- **Project > Tools > Build Standalone Host** creates a portable Windows x86_64 release ZIP. Linux is deliberately deferred.
- Bubbles still needs the owner's two-phone and game-feel review; automated evidence does not establish device, browser, network, accessibility, or feel approval.

## Documentation

This repository contains the Godot project, browser client, bundled runtime assets, tests, and tooling. See [README.md](README.md) for setup, [AGENTS.md](AGENTS.md) for contributor guidance, and [Tuning/README.md](Tuning/README.md) for tuning.

## Project location and running

Run Git, Godot, browser build, and tests from this repository root. `project.godot` must remain at its root.

```powershell
godot --version
godot --path .
```

Use **F5** for the complete boot/lobby flow. Use **F6** only when an individual scene is designed for direct execution. Use `GODOT_BIN` when Godot is not on PATH.

In the lobby, choose a reachable Wi-Fi/Ethernet IPv4 address, then scan the QR or type the displayed URL on a phone on the same LAN. Discovery runs at launch and on Refresh; it prefers common `192.168.*` addresses but is not default-route detection. Loopback, link-local, and IPv6 addresses are excluded. VPNs, multiple adapters, guest Wi-Fi, and client isolation can require a manual choice or prevent access.

Normal play starts with 2–10 registered players. Choose a minigame from the lobby dropdown before starting. For debug, register exactly one phone, press F12, and choose the matching one-player scenario. Restart and lobby return preserve the running `SessionHost`, player registry, and LAN services.

## Runtime architecture and code map

- `scenes/boot.*` starts services and presents Retry after startup failure.
- `host/session_host.gd` persists services and the registry across scene changes. It discovers addresses, constructs URLs, and rolls HTTP back if WebSocket binding fails.
- `host/http_service.gd` serves a fixed asset allowlist with bounded requests; it never serves a client-selected filesystem path.
- `host/websocket_service.gd` owns bounded protocol-1 peers/messages and resolves each connection to a host-owned player before forwarding gameplay input.
- `host/player_registry.gd` owns session/player/token identities, names, validated character shape/color, capacity, reconnect grace, resume, and explicit leave.
- `scenes/lobby.*` places live QR/address controls and minigame selection/start on the Playground's board and calendar. There is no visible roster; `SessionHost.players_changed` still refreshes the shared 2–10 player launch gate. The FHD control positions and `PanelBackings` sprite transforms are the main UI tuning points; Godot's `canvas_items` stretch scales them to the 1152×648 host size.
- `scenes/lobby_playground_world.tscn` is the reusable 1920×1080 toy-shelf world. It imports selected layers, props, blank QR board/calendar, and a separate logo under `assets/runtime/lobby_playground/`. `PanelBackings` sits behind `CharactersFrontOfPanels`; characters draw over the live QR and other lobby controls, while `Foreground` draws over characters. `scenes/lobby_playground_world.gd` reconciles registered players to ten seat-indexed `FutureCharacterAnchors`. `characters/lobby_squircle.tscn` owns host-side platform and player collision, a modest landing bounce, and a readable nameplate. Its script exposes speed, acceleration, gravity, jump impulse, player bounce settings, visual scale, run threshold, and fall-reset height in the Inspector. One-way shelves and block tops use physics layer 8 (bit 128); characters use layer 9 (bit 256) and mask both layers.
- `host/pre_minigame_readiness.gd` owns one selected round's ordered roster and player-ID keyed ready state. `SessionHost` starts or cancels it and closes registration before the single launch transition. `WebsocketService` admits final joins only from onboarding sockets already open at Start, resolves ready actions through each registered connection, and sends personalized ready snapshots on resume. `scenes/pre_minigame_screen.tscn` uses editable Bubbles content in `scenes/bubbles_pre_minigame_content.tres` and a curated gameplay capture in `assets/runtime/pre_minigame/bubbles_preview.png`.
- `minigames/bubbles_round_controller.gd` owns the Bubbles entrance/countdown/active/results lifecycle, score and pop state, host-time finish freeze, and snapshots keyed by player ID. `bubbles_gesture_classifier.gd` validates and classifies one completed normalized trace. The gameplay shared-screen scene is `minigames/bubbles_and_jellyfishes.tscn`.
- `minigames/bubbles_player_bubble.tscn` reuses `SquircleV1Playback` in a procedural translucent bubble with a per-instance circle collider, capped approved small-jellyfish art, and readable name. `bubbles_player_visual.gd` draws the iridescent rim, live directional drag pull, charge glow/wobble, authoritative spin surface and particles, and pop fragments; `bubbles_player_bubble.gd` animates the audience-facing character from accepted swipe events and keeps the charge cue on the bubble. Visual deformation and burst radius never drive collision. `bubbles_player_arena.gd` creates 1–10 bodies and steps movement, invisible bounds, and player pairs in sorted player-ID order. Call `setup(controller, npc_bounds, optional_wall_bounds)`, then `add_bubble(player_id, position)` from the controller's participant snapshot; call `simulate_step(fixed_delta, host_time_msec)` from the host physics loop (normally 1/60 second, maximum 0.05). `bounds` retains the logical NPC play area; player bubbles use the optional wall bounds. The arena settles the controller clock before movement, so exact-zero results freeze first. Bodies consume only the controller's accepted swipe/spin/pop signals and score snapshots.
- `BubblesPresentation` derives player-bubble wall bounds from the visible viewport rectangle at launch and on resize. Wall padding uses each bubble's transformed radius so its visible edge meets the viewport edge; NPC boundary behavior remains separate.
- `minigames/bubbles_creature_arena.gd` owns free jellyfish and pufferfish scenes, initial safe spawns, alternating waves, warning/crossing paths, and host-time collection/hit checks. The shared-screen scene creates player bodies, then calls `setup(controller, player_arena)` before `complete_entrance()`. Each fixed host step calls the player arena first, then `creature_arena.simulate_step(fixed_delta, host_time_msec)` with the same time. The controller alone accepts collections and pops; creature sprites never decide rules. Free jellyfish obey the tuning cap, including scatter after a pop; overflow is reported by `jellyfish_scattered` and discarded.
- `host/bubbles_protocol.gd` validates completed normalized traces and makes personalized Bubbles snapshots. For the current authenticated touch sequence it accepts four coarse charge steps plus up to 48 quantized drag updates, spaced at least 60 ms apart; no pointer positions are sent. These drive only transient shared-screen deformation and glow and reset after 1.2 seconds without updates. The host records touch start; live drag stretch settles once `swipe_max_hold_seconds` passes, and a late swipe applies no impulse. Completed spins still use the existing classifier and cooldown. `WebsocketService` keeps one active protocol at a time. `BubblesPresentation` consumes the prepared host launch, observes registry reconnect/leave changes, registers its controller for the round, and unregisters it on exit. The scene owns fixed-order arena stepping, entrance, countdown, timer, approved background layers, semantic audio, debug labeling, results, and the host return button. The in-game instruction card is gone on normal and F12 launches. The browser never supplies player ID or host time.
- `characters/character_selection.gd` normalizes missing and legacy shapes to Squircle while preserving selected colors; `web/src/character_selection.ts` offers colors and sends `squircle`. `characters/squircle_v1_playback.tscn` plays manifest-owned sheets in the lobby, Bubbles, and results.
- `debug/` contains the non-pausing F12 scenario catalog and debug scenes. The launcher remains present in development exports. **Animation Lab** opens `debug/animation_lab/animation_lab.tscn` to inspect all six approved Squircle v1 clip/view pairs at 256 and 128 pixels, with color, face and pause controls; run its focused check with `godot --headless --path . --script res://tests/squircle_animation_lab_test.gd`. The lab uses `debug/animation_lab/rendered_sample.gd` for sheet alignment, frame tiles and tint. The canonical editable model and actions are in `art/experiments/squircle-animation/squircle-animated.blend`; 18 runtime sheets and their frame/anchor manifest live in `assets/runtime/animated_characters/squircle/v1/`. The Playground lobby, Bubbles shared screen, and phone consume that same v1 set. After exporting and packing, run `art/experiments/squircle-animation/review_ps064.py` to refresh the runtime set.
- `Tuning/` contains the active selector, named resources, guide, and experiment template. There is no runtime tuning UI.
- `web/src/` is TypeScript source. `web/public/` is the committed offline runtime bundle served by Godot; normal play needs neither Node nor Internet. `npm.cmd run build` in `web/` compiles TypeScript and copies pinned NippleJS into `web/public/vendor/`. The phone onboarding keeps the socket available while players choose a Squircle color and enter a name; the host creates the player record only on the final join submission. Ready-up shows one host-confirmed READY/CANCEL toggle without gameplay controls, preview, or booklet. `web/src/squircle_v1.ts` draws manifest-owned front idle sheets in setup and in the player's personalized Bubbles snapshot.
- `assets/runtime/` is the curated runtime-media boundary. Source/archive art remains outside it and is excluded from Godot import/export.
- Bubbles static art lives in `assets/runtime/minigames/bubbles_and_jellyfishes/`; its [asset guide](assets/runtime/minigames/bubbles_and_jellyfishes/README.md) records scale, filtering, layer composition and provenance. [GIMP regeneration and isolated export-pack checks](art/bubbles/README.md) remain separate from gameplay implementation.
- `addons/standalone_build/` is the editor-only Windows builder. `addons/kenyoni/qr_code/` is the required vendored runtime QR dependency.
- `tests/` holds focused headless, integration, policy, and render checks; generated evidence belongs under ignored `test-results/`.

## Host authority and protocol reference

The host owns session state, player identity, round timing, score, results, and receipt time. Phones send UI actions and controller input only.

Defaults in `Tuning/Shared/Networking/Default.tres`:

- HTTP `8080`; WebSocket `8081`
- 32 transport connections per service; at most 10 registered players per session (designer setting may be lower)
- five-second request/handshake timeout; 60-second reconnect grace

`GET /session.json` returns protocol and WebSocket port. The browser uses the page hostname for `ws://HOST:PORT`. Fixed HTTP routes are `/`, `/app.js`, `/lobby_controls.js`, `/lobby_input.js`, `/vendor/nipplejs.mjs`, `/immersive.js`, `/bubbles_gesture.js`, `/character_selection.js`, `/squircle_v1.js`, `/squircle-v1/manifest.json`, `/squircle-v1/idle-front-colorable.png`, `/squircle-v1/idle-front-neutral.png`, `/squircle-v1/idle-front-blink.png`, `/bubbles-jellyfish.png`, `/bubbles-phone-background.png`, `/style.css`, and `/session.json`. Unknown routes return 404; non-GET methods return 405; headers beyond 8192 bytes are rejected with 431 or a TCP reset when unread bytes remain on Windows. Responses close after the final bytes have time to flush, so larger PNGs load completely.

Protocol 1 begins with `hello`/`welcome`, then supports join, resume, leave, and personalized lobby/gameplay state. Before join, the phone shows Squircle color selection followed by name entry; `join` submits `name`, `character_shape: "squircle"`, and `character_color` together. The host accepts missing and legacy body-shape values as Squircle, rejects unknown body-shape values, and validates the ten approved player colors. A join with no style uses Squircle and the existing `#598DF2` blue fallback; a valid color without a shape keeps that color. The registry stores Squircle, and lobby rosters, Bubbles snapshots, and resume state carry it forward. The Squircle v1 tint colors its body, hands, and feet while its face remains neutral. The registry deliberately separates transport `connection_id`, host-owned session-scoped `player_id`, host-owned `session_id`, and opaque browser-held reconnect token. The browser stores only the session ID, token, last-used name, and monotonically increasing gameplay sequence needed to resume safely. A client-supplied player ID has no authority. New joins are lobby-only except for final submissions from onboarding sockets already open before Start; valid resumes remain available during ready-up and gameplay. Disconnect clears an unfinished Bubbles trace; resume requires a new gesture. During a Bubbles touch, the browser may send `bubbles_charge` with `input_seq` and `stage`: `start`/`progress`/`cancel` carry integer `step` (0–4), while `motion` carries a two-axis quantized `drag` vector (integers -4 to 4). The browser throttles motion to 70 ms, sends a 600 ms heartbeat while held, and caps a gesture at 48 motion packets; no pointer positions or client timestamps are sent. Bubbles sends one `bubbles_trace` (at most 128 normalized points, 8192-byte packet ceiling) on touch release with the same gesture sequence. The host replies with `bubbles_trace_result` and a `bubbles_snapshot`; `bubbles_feedback` carries collection, spin, and pop cues. Reconnect embeds the latest personalized snapshot in `welcome.gameplay`.

During ready-up, a registered phone sends `{"type":"pre_minigame_ready","ready":true|false}`. The host derives its player ID from the connection and replies with a personalized `pre_minigame_snapshot` containing that player's ready value and the ordered roster. New phone handshakes cannot begin onboarding in this phase; previously open onboarding sockets may finish joining, and registered phones may resume. Disconnect and resume clear ready state. Host cancel restores lobby state on connected phones. This is the sole exception to the lobby-only new-join rule in the preceding protocol description.

The lobby uses Squircle v1 movement clips; setup and Bubbles use its front idle clip. The colorable layer uses the same tint treatment on host and phone; the neutral and blink faces stay untinted.

After join, the portrait Playground controls send `{"type":"lobby_move","horizontal":-1.0..1.0,"input_seq":N}` while the fixed NippleJS stick is held, including a zero on release, or `{"type":"lobby_jump_release","input_seq":N}` once when the jump button is released. The host resolves the registered connection, validates numeric range and increasing sequence, and accepts these messages only while the lobby is active. A new resume connection resets that player's lobby sequence and clears old intent; the displaced connection no longer owns the player. Horizontal intent expires after 350 ms without a refresh; disconnect, leave, and minigame launch also clear it. A jump release succeeds only from the floor. The registry reuses the lowest free seat, so seats 1–10 remain tied to the ten editor anchors across leave, expiry, and resume.

## Tuning and content boundaries

Open `Tuning/Active Presets.tres` to select named resources. Current front doors are `Tuning/Minigames/Bubbles/Default.tres` and `Tuning/Shared/Networking/Default.tres`. Restart to apply a changed selection. Bubbles field descriptions are in `Tuning/Minigames/Bubbles/README.md`. Only the human owner promotes subjective feel into `Default`; tests establish configuration safety, not fun or comfort.

For Inspector help, put a `##` documentation comment immediately before the export annotation and variable declaration. Use `@export_group`, not `@export_category`, because categories can break subsequent property help. `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.

## Browser build

Node 22+ is development-only. After any TypeScript edit, rebuild and commit all affected modules under `web/public/`:

```powershell
cd web
npm.cmd ci --ignore-scripts
npm.cmd run check
npm.cmd run build
npm.cmd test
cd ..
```

Every top-level module imported by `app.js` must also appear in the explicit `HttpService` allowlist and release filter. A 200 response for `/app.js` does not prove its module graph works: a missing imported module can leave phones at `Connecting to the host…`. The export presets include `web/public/*.js` and the Squircle v1 manifest; served tests request the imported modules and front idle Squircle sheets.

The Bubbles surface is a full-screen portrait touch area with exact host score, capped decorative jellyfish, and its personalized character preview; the Squircle v1 body, hands, and feet share the player's chosen color. The browser attempts fullscreen/portrait lock after a gesture and unlocks when returning to lobby; denial or unsupported APIs are valid fallbacks. Safari works, but Chrome currently provides the most consistent fullscreen/orientation behavior.

## Windows standalone build

Install the exact Godot 4.7.2 Windows export templates with **Editor > Manage Export Templates**, then use **Project > Tools > Build Standalone Host**. Godot requires both release and debug x86_64 template files even though this action exports release only.

```text
builds/standalone/
├── Play-Shapes-windows-x86_64.zip
└── windows-x86_64/
    ├── Play Shapes.exe
    ├── Play Shapes.pck
    └── build-info.json
```

The ZIP contains one `Play-Shapes-windows-x86_64/` folder. The manifest records preset, architecture, Godot version, renderer, UTC time, and source revision when available. Before archiving, the builder verifies the external PCK, every browser module, boot/lobby scenes, QR dependency, Bubbles scenes/scripts, and Bubbles runtime art/audio. It never starts Node.

The `Play Shapes Windows Release` preset includes the committed browser runtime while excluding browser source/dependencies, tests/results, tools, planning notes, source art, runtime asset manifests, build output, editor addons, and package configuration. Do not broaden filters just to silence a policy failure. `addons/kenyoni/qr_code/` must remain included.

The editor polls a separate headless export process. Cancel terminates that owned process or removes only its partial ZIP. Success opens the extracted folder but never launches the game. For builder UI maintenance, set `Window.size` before parameterless `popup_centered()`; Godot treats a size passed to `popup_centered(size)` as a minimum and may retain an oversized native window. Keep the target path single-line/ellipsized because early wrapping can create an extreme minimum height.

## Verification

Keep evidence labels separate: `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, `[DESKTOP-BROWSER]`, `[PHYSICAL-PHONE]`, `[EXPORTED-BUILD]`, and `[HUMAN-PLAY]`. One never implies another. Render captures establish technical composition, not couch-distance readability, accessibility, comfort, or creative approval.

Close any interactive host before integration tests; the browser suite refuses to run over an existing host. It uses `18080`/`18081` for startup lifecycle checks. `GODOT_BIN` can override the executable used by `web/tests/host.test.mjs`.

```powershell
godot --headless --editor --path . --quit-after 30
godot --headless --path . --script res://tests/foundation.gd
godot --headless --path . --script res://tests/player_registry_test.gd
godot --headless --path . --script res://tests/player_lobby_test.gd
godot --headless --path . --script res://tests/lobby_layout_test.gd
godot --headless --path . --script res://tests/lobby_playground_world_test.gd
godot --headless --path . --script res://tests/lobby_playground_control_test.gd
godot --headless --path . --script res://tests/bubbles_gesture_classifier_test.gd
godot --headless --path . --script res://tests/bubbles_round_controller_test.gd
godot --headless --path . --script res://tests/bubbles_player_physics_test.gd
godot --headless --path . --script res://tests/bubbles_creature_arena_test.gd
godot --headless --path . --script res://tests/bubbles_protocol_test.gd
godot --headless --path . --script res://tests/bubbles_presentation_test.gd
godot --headless --path . --script res://tests/active_minigame_protocol_test.gd
godot --headless --path . --script res://tests/debug_launcher_test.gd
godot --headless --path . --script res://tests/tuning_presets_test.gd
godot --headless --path . --script res://tests/minigame_flow_test.gd
godot --headless --path . --script res://tests/pre_minigame_readiness_test.gd
godot --headless --path . --script res://tests/pre_minigame_screen_test.gd
```

Builder checks require matching installed export templates:

```powershell
godot --headless --path . --script res://tests/standalone_build_test.gd
godot --headless --editor --path . --script res://tests/standalone_build_editor_integration_test.gd
```

After a local Windows release export, `godot --headless --path . --script res://tests/lobby_export_pack_check.gd` verifies that its external PCK includes the offline phone modules, squircle metadata/sheets, and required runtime paths.

Run visual helpers only when their output will be inspected; they write ignored artifacts under `test-results/`. A normal-profile editor load may emit forced-shutdown RID/ObjectDB cleanup warnings after a successful scan. Treat exit zero plus no script/import error as the result; do not confuse cache/profile permission failures with product failures.
For isolated Bubbles player-component review, `godot --path . --script res://tests/bubbles_player_visual_check.gd` uses the Compatibility renderer and saves small/grown/spinning, pop/re-form, and ten-player captures under ignored `test-results/ps-042/`. These are component renders, not a composed arena or human feel evidence.
For Bubbles player animation review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_animation_visual_check.gd` saves small/maximum idle, held left drag, accepted swipe, slow held/released drag, charge glow/wobble, active spin, burst, and reformed captures under ignored `test-results/ps-050/`. Inspect the sequence in order; still images cannot establish motion feel.
For isolated Bubbles creature review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_creature_visual_check.gd` saves entrance/warning, active creatures, and white-blinking scatter captures under ignored `test-results/ps-043/`. These renders do not establish collision fairness or a complete scene.
For Bubbles creature telegraph review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_creature_motion_visual_check.gd` saves the offscreen bubble burst before reveal, the fish entering from that origin, pufferfish jiggle, warning-off, and jellyfish breathing captures under ignored `test-results/ps-052/`. Inspect the ordered stills; they show rendered size and states but do not establish motion feel or owner readability/fairness approval.
For Bubbles shared-screen review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_presentation_visual_check.gd` saves empty, entrance, ten-player FHD/HD, warning on/off, final-timer, tied-results, and two-player maximum-bubble captures under ignored `test-results/ps-045/`. Inspect those images; technical render evidence does not establish couch-distance readability, final audio mix, or game feel.
For ready-screen composition, `godot --path . --rendering-method gl_compatibility --script res://tests/pre_minigame_visual_check.gd` saves two- and ten-player captures at 1920×1080 and 1280×720 under ignored `test-results/ps-070/`. The committed tablet preview comes from an active Bubbles capture made by the presentation visual helper. The WebSocket ready journey runs in `web/tests/ready_flow.test.mjs`.
For Bubbles viewport-wall review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_viewport_visual_check.gd` saves player-bubble edge-contact captures at 1920×1080 and 1280×720 under ignored `test-results/ps-047/`.
For a local desktop-browser phone preview, run `godot --headless --path . --script res://tests/bubbles_phone_preview.gd`, then join at `http://127.0.0.1:8080`. It starts a one-player Bubbles protocol fixture with eight collected jellyfish and the explicit debug label. Stop it before starting normal play. The browser/host suite runs the same fixture on separate ports; neither preview represents a playable arena or physical-phone validation.

## Networking, export, and operational warnings

- Listeners bind all interfaces for LAN play. There is no TLS, authentication, public hosting, or CORS API. Never forward ports 8080/8081 to the Internet.
- If a phone cannot connect, check the selected adapter, both TCP ports, same Wi-Fi, guest/client isolation, VPN LAN restrictions, and Windows Firewall. The user handles private-network permission prompts; tooling does not change firewall or VPN settings.
- A busy service port shows Retry in boot. WebSocket bind failure rolls HTTP back rather than leaving a partial host.
- Editor/runtime checks do not prove a package. Smoke the exported executable without Godot or Node, including lobby, HTTP routes, WebSocket, and a browser connection.
- Preserve `web/public/`, the Kenyoni QR addon, external-PCK output, and the curated runtime/source-archive boundary in export changes.
- A phone reload creates a new transport connection but may resume the same player during grace. Duplicate active-token resume gives the newest tab ownership and closes the old connection.
