# Play Shapes development

This is the compact implementation manual for the current checkout. It records how the project works now, how to run and verify it, and operational caveats that are easy to rediscover.

## Current status

- Godot 4.7.2 is the authoritative host; phone controllers are bundled HTML/CSS/JavaScript clients over local HTTP and WebSockets.
- The lobby opens a shared ready screen for **Bubbles and Jellyfishes** with 2–10 registered players. Bubbles starts after every current participant is ready.
- Registered players appear as Squircle v1 characters in the Playground lobby and steer them from a portrait phone stick and release-action button; near-vertical input reaches/crouches, and FALL descends Open supports. Squircle v1 is also the current character in Minigame 002 and phone setup.
- F12 provides a one-real-player Bubbles debug scenario, the Squircle Animation Lab, and the Gyroscope and Accelerometer Lab. It creates no simulated player; Bubbles labels its debug round on the host and phone.
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
- `scenes/lobby_playground_world.tscn` is the reusable 1920×1080 toy-shelf world. It imports selected layers, props, blank QR board/calendar, and a separate logo under `assets/runtime/lobby_playground/`. `PanelBackings` sits behind `CharactersFrontOfPanels`; characters draw over the live QR and other lobby controls, while `Foreground` draws over characters. `scenes/lobby_playground_world.gd` reconciles registered players to ten seat-indexed `FutureCharacterAnchors`. `characters/lobby_squircle.tscn` composes the shared `PlatformMotor` with Squircle playback, player lifecycle and a nameplate. The motor exposes speed, acceleration, gravity, jump impulse, player bounce, run threshold, input lease, fall-reset height and drop timing in its Inspector. `PlatformSurface` exposes an independent **Drop Rule: Open/Closed** on all eleven surfaces; only `BottomShelf` is Closed. Select `PlatformSurfaces/<name>` in the world scene to change one rule without touching art, shape alignment or one-way collision. See [component setup and reuse](docs/platform-phone-controller.md#host-components-and-platform-setup). One-way shelves and block tops use physics layer 8 (bit 128); characters use layer 9 (bit 256) and mask both layers.
- `host/pre_minigame_readiness.gd` owns one selected round's ordered roster and player-ID keyed ready state. `SessionHost` starts or cancels it and closes registration before the single launch transition. `WebsocketService` admits final joins only from onboarding sockets already open at Start, resolves ready actions through each registered connection, and sends personalized ready snapshots on resume. `scenes/pre_minigame_screen.tscn` uses editable Bubbles content in `scenes/bubbles_pre_minigame_content.tres` and a curated gameplay capture in `assets/runtime/pre_minigame/bubbles_preview.png`.
- `minigames/bubbles_round_controller.gd` owns the Bubbles entrance/countdown/active/results lifecycle, score and pop state, host-time finish freeze, and snapshots keyed by player ID. `bubbles_gesture_classifier.gd` validates and classifies one completed normalized trace. The gameplay shared-screen scene is `minigames/bubbles_and_jellyfishes.tscn`.
- `minigames/bubbles_player_bubble.tscn` reuses `SquircleV1Playback` in a procedural translucent bubble with a per-instance circle collider, capped approved small-jellyfish art, and readable name. `bubbles_player_visual.gd` draws the iridescent rim, live directional drag pull, charge glow/wobble, authoritative spin surface and particles, and pop fragments; `bubbles_player_bubble.gd` animates the audience-facing character from accepted swipe events and keeps the charge cue on the bubble. Visual deformation and burst radius never drive collision. `bubbles_player_arena.gd` creates 1–10 bodies and steps movement, invisible bounds, and player pairs in sorted player-ID order. Call `setup(controller, npc_bounds, optional_wall_bounds)`, then `add_bubble(player_id, position)` from the controller's participant snapshot; call `simulate_step(fixed_delta, host_time_msec)` from the host physics loop (normally 1/60 second, maximum 0.05). `bounds` retains the logical NPC play area; player bubbles use the optional wall bounds. The arena settles the controller clock before movement, so exact-zero results freeze first. Bodies consume only the controller's accepted swipe/spin/pop signals and score snapshots.
- `BubblesPresentation` derives player-bubble wall bounds from the visible viewport rectangle at launch and on resize. Wall padding uses each bubble's transformed radius so its visible edge meets the viewport edge; NPC boundary behavior remains separate.
- `minigames/bubbles_creature_arena.gd` owns free jellyfish and pufferfish scenes, initial safe spawns, alternating waves, warning/crossing paths, and host-time collection/hit checks. The shared-screen scene creates player bodies, then calls `setup(controller, player_arena)` before `complete_entrance()`. Each fixed host step calls the player arena first, then `creature_arena.simulate_step(fixed_delta, host_time_msec)` with the same time. The controller alone accepts collections and pops; creature sprites never decide rules. Free jellyfish obey the tuning cap, including scatter after a pop; overflow is reported by `jellyfish_scattered` and discarded.
- `host/bubbles_protocol.gd` validates completed normalized traces and makes personalized Bubbles snapshots. For the current authenticated touch sequence it accepts four coarse charge steps plus up to 48 quantized drag updates, spaced at least 60 ms apart; no pointer positions are sent. These drive only transient shared-screen deformation and glow and reset after 1.2 seconds without updates. The host records touch start; live drag stretch settles once `swipe_max_hold_seconds` passes, and a late swipe applies no impulse. Completed spins still use the existing classifier and cooldown. `WebsocketService` keeps one active protocol at a time. `BubblesPresentation` consumes the prepared host launch, observes registry reconnect/leave changes, registers its controller for the round, and unregisters it on exit. The scene owns fixed-order arena stepping, entrance, countdown, timer, approved background layers, semantic audio, debug labeling, results, and the host return button. The in-game instruction card is gone on normal and F12 launches. The browser never supplies player ID or host time.
- `characters/character_selection.gd` normalizes missing and legacy shapes to Squircle while preserving selected colors; `web/src/character_selection.ts` offers colors and sends `squircle`. `characters/squircle_v1_playback.tscn` plays manifest-owned sheets in the lobby, Bubbles, and results.
- `debug/` contains the non-pausing F12 scenario catalog and debug scenes. The launcher remains present in development exports. **Animation Lab** opens `debug/animation_lab/animation_lab.tscn` to inspect the manifest's ten Squircle v1 action/view pairs at 256, 128 and actual lobby scale (0.58), with color, natural/forced blink, pause, speed and release/re-enter controls. It uses `SquircleV1Playback` directly; run its focused check with `godot --headless --path . --script res://tests/squircle_animation_lab_test.gd`. The canonical editable model and actions are in `art/squircle/squircle-animated.blend`; 30 runtime sheets and their frame/anchor manifest live in `assets/runtime/animated_characters/squircle/v1/`. The Playground lobby, Bubbles shared screen, and phone consume that same v1 set. After exporting and packing, run `art/squircle/sync_runtime.py` to refresh the runtime set. See [source workflow and pose tuning](art/squircle/README.md) and [PS-080 evidence](docs/ps-080-squircle-animations.md).
- Runtime clip metadata distinguishes `playback: loop` (idle/walk/run) from `playback: held` (look_up/crouch). `SquircleV1Playback.play(action, view)` enters held stances once and sustains their final frame; another request reverses current progress to shared idle neutral before entering the latest requested action. Re-pressing the current stance cancels release without restarting. `advance_playback(delta)` drives normal and slowed review, while `seek_clip(action, view, milliseconds)` inspects an exact clip time. Stances keep the feet and ground anchor fixed, with independent color and face/blink layers. The shared host motor chooses these stances only while grounded; crouch retains the full upright collider and the same floor anchor.
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

`ControllerNetworkConfig` is the endpoint source for both services, lobby/QR and `/session.json`. It pairs HTTP/WS or HTTPS/WSS, separates bind interface from advertised hostname/IP, and keeps certificate paths private. `GET /session.json` returns protocol, session ID, HTTP/WS schemes and WebSocket port. `web/src/network_config.ts` validates the pair against the page protocol and uses the page hostname; mixed-content combinations fail. Local overrides are optional `local/network.json` beside the project (editor) or executable (export), or an explicit `PLAY_SHAPES_NETWORK_CONFIG` path; the environment value `off` intentionally ignores local overrides for tests. Ports still default from the active NetworkingTuning Resource. Fixed joining remains `/`; no room system or mDNS is present. Fixed HTTP routes additionally include `/pwa.js`, `/manifest.webmanifest` and `/app-icon-180.png`, `/app-icon-192.png`, `/app-icon-512.png`. Other fixed routes are `/`, `/app.js`, `/lobby_controls.js`, `/lobby_input.js`, `/vendor/nipplejs.mjs`, `/immersive.js`, `/bubbles_gesture.js`, `/character_selection.js`, `/squircle_v1.js`, `/squircle-v1/manifest.json`, `/squircle-v1/idle-front-colorable.png`, `/squircle-v1/idle-front-neutral.png`, `/squircle-v1/idle-front-blink.png`, `/bubbles-jellyfish.png`, `/bubbles-phone-background.png`, `/style.css`, and `/session.json`. Unknown routes return 404; non-GET methods return 405; headers beyond 8192 bytes are rejected with 431 or a TCP reset when unread bytes remain on Windows. Responses close after the final bytes have time to flush, so larger PNGs load completely.

Protocol 1 begins with `hello`/`welcome`, then supports join, resume, leave, and personalized lobby/gameplay state. Before join, the phone shows Squircle color selection followed by name entry; `join` submits `name`, `character_shape: "squircle"`, and `character_color` together. The host accepts missing and legacy body-shape values as Squircle, rejects unknown body-shape values, and validates the ten approved player colors. A join with no style uses Squircle and the existing `#598DF2` blue fallback; a valid color without a shape keeps that color. The registry stores Squircle, and lobby rosters, Bubbles snapshots, and resume state carry it forward. The Squircle v1 tint colors its body, hands, and feet while its face remains neutral. The registry deliberately separates transport `connection_id`, host-owned session-scoped `player_id`, host-owned `session_id`, and opaque browser-held reconnect token. The browser stores only the session ID, token, last-used name, and monotonically increasing gameplay sequence needed to resume safely. A client-supplied player ID has no authority. New joins are lobby-only except for final submissions from onboarding sockets already open before Start; valid resumes remain available during ready-up and gameplay. Disconnect clears an unfinished Bubbles trace; resume requires a new gesture. During a Bubbles touch, the browser may send `bubbles_charge` with `input_seq` and `stage`: `start`/`progress`/`cancel` carry integer `step` (0–4), while `motion` carries a two-axis quantized `drag` vector (integers -4 to 4). The browser throttles motion to 70 ms, sends a 600 ms heartbeat while held, and caps a gesture at 48 motion packets; no pointer positions or client timestamps are sent. Bubbles sends one `bubbles_trace` (at most 128 normalized points, 8192-byte packet ceiling) on touch release with the same gesture sequence. The host replies with `bubbles_trace_result` and a `bubbles_snapshot`; `bubbles_feedback` carries collection, spin, and pop cues. Reconnect embeds the latest personalized snapshot in `welcome.gameplay`.

During ready-up, a registered phone sends `{"type":"pre_minigame_ready","ready":true|false}`. The host derives its player ID from the connection and replies with a personalized `pre_minigame_snapshot` containing that player's ready value and the ordered roster. New phone handshakes cannot begin onboarding in this phase; previously open onboarding sockets may finish joining, and registered phones may resume. Disconnect and resume clear ready state. Host cancel restores lobby state on connected phones. This is the sole exception to the lobby-only new-join rule in the preceding protocol description.

The lobby uses Squircle v1 movement clips; setup and Bubbles use its front idle clip. The colorable layer uses the same tint treatment on host and phone; the neutral and blink faces stay untinted.

After join, the portrait Playground mounts reusable `PlatformControls` and `PlatformInputState` through `createLobbyContext`. NippleJS is unlocked: X is right-positive and Y up-positive, with unit-disk analog axes, a radial dead zone and hysteresis, and narrow up/down sectors. Near-down selects FALL; other directions select JUMP. Release sends one explicit attempt with the latest two-axis snapshot, including locally observed changes suppressed by the movement throttle. `lobby_move`, `lobby_jump_release` and the new `lobby_fall_release` carry `horizontal`, `vertical`, `stance` and increasing `input_seq`; releases also carry `action`. See [shared intent, tuning, lifecycle, adapter harness and host handoff](docs/platform-phone-controller.md). Build generates `web/public/platform_input_settings.json` from the same browser defaults; it and `/platform_controls.js`, `/platform_input.js` are fixed HTTP routes and required export assets.

The host validates complete finite unit-disk axes, consistent stance hints, matching release action and safe increasing sequence. `PlatformInput` reads the generated browser settings and reconstructs radial/angular hysteresis so coalesced snapshots remain valid. Release axes apply atomically before host eligibility. Both axes, stances, queued jumps and temporary exclusions expire after 350 ms without refresh. Registered socket identity and lobby/active-protocol gates remain authoritative; no client player ID, grounding or platform choice is used.

FALL requires grounded contact with exactly one Open `PlatformSurface`, never another character or Closed ground. `PlatformMotor` excludes only that support for that body, suspends its floor snap, keeps every other collider active, then restores contact after clearance, a lower landing, edge exit or 0.65-second timeout. Repeated FALL while held down is rejected even after landing; leave the down sector before another deliberate descent. Rejected attempts never become queued drops or jumps. Disconnect/resume, despawn, component/scene exit, input expiry and fall reset clear transient contact/intent. [PS-082 technical and live-render evidence](docs/ps-082-platform-stances.md) remains separate from phone responsiveness, owner animation/game-feel and publication approval.


## Tuning and content boundaries

Open `Tuning/Active Presets.tres` to select named resources. Current front doors are `Tuning/Minigames/Bubbles/Default.tres` and `Tuning/Shared/Networking/Default.tres`. Restart to apply a changed selection. Bubbles field descriptions are in `Tuning/Minigames/Bubbles/README.md`. Only the human owner promotes subjective feel into `Default`; tests establish configuration safety, not fun or comfort.

For Inspector help, put a `##` documentation comment immediately before the export annotation and variable declaration. Use `@export_group`, not `@export_category`, because categories can break subsequent property help. `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.

## Formatting and linting

`node tools/format.mjs` formats every GDScript file outside `addons/` with the GDQuest GDScript formatter, and the TypeScript, JavaScript, HTML and CSS sources of `web/` and `tools/` with Prettier, both wrapping at 100 characters. `--check` changes nothing and lists the unformatted files; the check command runs it as its `format` step. `.editorconfig` states the same rules for editors, and `.prettierignore` keeps an editor's format-on-save away from compiled and generated files. Markdown, JSON, Godot's `.tscn`/`.tres` files, the compiled `.js` in `web/public/` and the Python art tools are not formatted.

Godot has no formatter of its own. `node tools/setup.mjs` downloads the pinned formatter version into ignored `local/tools/` and verifies it against the SHA-256 recorded in `tools/gdscript_formatter.mjs`; changing the version means recording a new checksum for every platform there, then reformatting. The formatter runs with its structure check and refuses a file whose wrapped form it cannot prove equivalent. It names only the file; so far the cause has always been a long chained call or an inline `if`/`else` inside a longer expression, and splitting that statement into shorter ones fixes it. One pass does not always reach its own fixed point, so the command repeats until a pass changes nothing.

`node tools/lint.mjs` prints one finding per line and fails when there is any; the check command runs it as its `lint` step. It runs the GDScript formatter's own linter over the same GDScript files, ESLint with the recommended JavaScript and typescript-eslint rules over the TypeScript and JavaScript of `web/` and `tools/`, and reports every line over 100 characters. The ESLint rules are in `web/eslint.rules.mjs`, next to the packages they import; `eslint.config.mjs` at the root re-exports them so the linter and editors also cover `tools/`. `tools/sources.mjs` decides which files both commands cover, from the files git tracks or would add: a folder git ignores, such as an editor's plugins, is never read. A TypeScript or JavaScript file that git knows about and no rule covers is reported as `uncovered-source`, so code in a new folder cannot go unformatted and unlinted unnoticed; the fix is to add the folder to `tools/sources.mjs`, or to the places it leaves alone on purpose (`web/public/`, `web/src/vendor/`, `addons/`, `art/`).

Three exceptions are deliberate. The linter's `private-access` rule is off for `tests/`, where the tests reach into private members of the code they test; that is temporary and marked in `tools/lint.mjs`. A line of an HTML file may exceed 100 characters, because an attribute value cannot continue on another line. So may the line that opens a test with its title, because splitting the title makes Prettier indent the whole test body a level deeper.

`.git-blame-ignore-revs` lists the commits that only changed layout. GitHub's blame view skips them; locally run `git config blame.ignoreRevsFile .git-blame-ignore-revs` once.

## Browser build

Node 22+ is required for development and not for play. `node tools/setup.mjs` checks it with the other required tools and installs `web/` dependencies; [README.md](README.md#requirements) lists every tool. After any TypeScript edit, rebuild and commit all affected modules under `web/public/`:

```powershell
cd web
npm.cmd run check
npm.cmd run build
npm.cmd test
cd ..
```

Every top-level module imported by `app.js` must also appear in the explicit `HttpService` allowlist and release filter. A 200 response for `/app.js` does not prove its module graph works: a missing imported module can leave phones at `Connecting to the host…`. The export presets include `web/public/*.js` and the Squircle v1 manifest; served tests request the imported modules and front idle Squircle sheets.

The Bubbles surface is a full-screen portrait touch area with exact host score, capped decorative jellyfish, and its personalized character preview; the Squircle v1 body, hands, and feet share the player's chosen color. Onboarding offers **Run Play Shapes as an app** before new-player registration, with platform guidance, a real native install prompt only when available, and **Continue in browser**. Standalone/resumed players skip the prompt; tab-session dismissal prevents recurring play interruptions. Browser continuation optionally attempts fullscreen/portrait lock; denial is playable. Gameplay input never requests fullscreen or consumes the motion-permission gesture. Controller surfaces scope zoom/scroll/selection prevention and cancel gestures on viewport/orientation/background changes; onboarding remains scrollable and zoomable. The manifest and local icons are bundled in exports. No service worker or static cache is added; the reachable LAN host still serves all content, and installation does not establish certificate trust. See [optional controller app and touch review](docs/controller-app-and-touch.md) for actual Safari limits, installation steps, origin/session/storage handling, update procedure, synthetic timing and pending physical Safari/Android evidence.

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

The `Play Shapes Windows Release` preset includes the committed browser runtime while excluding browser source/dependencies, tests/results, tools, source art, runtime asset manifests, build output, editor addons, and package configuration. Do not broaden filters just to silence a policy failure. `addons/kenyoni/qr_code/` must remain included.

The editor polls a separate headless export process. Cancel terminates that owned process or removes only its partial ZIP. Success opens the extracted folder but never launches the game. For builder UI maintenance, set `Window.size` before parameterless `popup_centered()`; Godot treats a size passed to `popup_centered(size)` as a minimum and may retain an oversized native window. Keep the target path single-line/ellipsized because early wrapping can create an extreme minimum height.

## Verification

During this early development phase, controller connection/protocol errors appear in a selectable red panel with the failing step, endpoint, error text, browser version and WebSocket close details. It remains visible across retries and clears on successful welcome, including on Safari and standalone app layouts. Browser-hidden TLS causes remain explicitly unknown. Restart the host after rebuilding browser output so its startup-cached assets refresh; reload/relaunch the controller. See [development error reporting](docs/controller-app-and-touch.md#development-error-reporting).

Keep evidence labels separate: `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, `[DESKTOP-BROWSER]`, `[PHYSICAL-PHONE]`, `[EXPORTED-BUILD]`, and `[HUMAN-PLAY]`. One never implies another. Render captures establish technical composition, not couch-distance readability, accessibility, comfort, or creative approval.

Close any interactive host before integration tests; the browser suite refuses to run over an existing host. It uses `18080`/`18081` for startup lifecycle checks. `GODOT_BIN` can override the executable used by `web/tests/host.test.mjs`.

```powershell
node tools/check.mjs
```

This is the default `[AUTO]` check. It runs every `tests/*_test.gd` script and `tests/foundation.gd`, each in its own headless Godot process, then `node tools/format.mjs --check`, `node tools/lint.mjs` and the `tools/tests/` suite, then `npm run check` (which type-checks the phone client and, with Node types, the end-to-end test files) and `npm test` in `web/`, then rebuilds the browser bundle and fails if `web/public/` changed, then runs the end-to-end test described below. New test scripts are picked up by name. It prints one line per failure and a one-line summary; full output for each check is in ignored `test-results/check/`. A Godot script fails on a non-zero exit code or on any `ERROR` line. Shutdown lines about objects still held at exit are ignored for now, because three passing scripts print them; that exception is temporary and is marked in `tools/check.mjs`.

```powershell
node tools/check.mjs bubbles web-tests   # only checks whose name contains a filter
node tools/check.mjs --full              # end-to-end round with every default
node tools/check.mjs --release           # also run the Windows export test
godot --headless --path . --script res://tests/player_registry_test.gd   # one script, full output
godot --headless --editor --path . --quit-after 30                        # editor import scan
```

The end-to-end test, `web/e2e/bubbles_two_phones.spec.ts`, runs the real phone client in two emulated Pixel 7 Chromium contexts against the real host on ports 18200/18201. `tests/e2e/host.gd` sets the ports and loads the project's main scene, so the game's own boot starts the host and opens the lobby; a boot that cannot start the host fails the test at once with its message. End-to-end tests go through boot; unit, integration and single-minigame tests start only what they need, so they stay fast. The phones join, walk in the lobby, ready up, swipe through a Bubbles round and return to the lobby. The host script clicks Start once every character has moved and stood still, and Return to lobby after results have been up for 3 s. It clicks with mouse events injected at the button's place on screen, so Godot's hit testing applies: a button that is covered, off screen, disabled or ignoring the mouse stops the run with a message naming what was under the mouse. That covers reachability, not appearance. It prints one `E2E ...` line per event for the test to wait on. By default it shortens only the Bubbles round, to 10 s and in memory; `E2E_ROUND=full` keeps every default. The host script prints `E2E round ending` two seconds before the round ends and the phones stop swiping then: a swipe that reaches the host after the round has ended is rejected as `stale_or_unavailable`, and the phone shows that rejection in its error panel. The test fails on a missing step, a phone without an accepted swipe, a page error, a visible phone error panel or a host `ERROR` line. Each phone saves a screenshot per step in `test-results/e2e/`, with a Playwright trace when the test fails. It is `[AUTO]` evidence from desktop Chromium; it never stands in for `[PHYSICAL-PHONE]`.

```powershell
cd web
npm run e2e                                    # the test alone
$env:E2E_WINDOWED = "1"; npm run e2e; Remove-Item env:E2E_WINDOWED   # show the host and save its screenshots
npx playwright show-trace ../test-results/e2e/<test>/trace.zip    # inspect a failure
cd ..
```

`tests/standalone_build_editor_integration_test.gd` performs a real Windows export and writes `builds/`, so it needs matching installed export templates and runs only with `--release`; without templates the command names the missing folder. `tests/standalone_build_test.gd` needs no templates and runs by default.

After a local Windows release export, `godot --headless --path . --script res://tests/lobby_export_pack_check.gd` verifies that its external PCK includes the offline phone modules, squircle metadata/sheets, and required runtime paths.

Run visual helpers only when their output will be inspected; they write ignored artifacts under `test-results/`. A normal-profile editor load may emit forced-shutdown RID/ObjectDB cleanup warnings after a successful scan. Treat exit zero plus no script/import error as the result; do not confuse cache/profile permission failures with product failures.
For isolated Bubbles player-component review, `godot --path . --script res://tests/bubbles_player_visual_check.gd` uses the Compatibility renderer and saves small/grown/spinning, pop/re-form, and ten-player captures under ignored `test-results/bubbles-player/`. These are component renders, not a composed arena or human feel evidence.
For Bubbles player animation review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_animation_visual_check.gd` saves small/maximum idle, held left drag, accepted swipe, slow held/released drag, charge glow/wobble, active spin, burst, and reformed captures under ignored `test-results/bubbles-animation/`. Inspect the sequence in order; still images cannot establish motion feel.
For isolated Bubbles creature review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_creature_visual_check.gd` saves entrance/warning, active creatures, and white-blinking scatter captures under ignored `test-results/bubbles-creatures/`. These renders do not establish collision fairness or a complete scene.
For Bubbles creature telegraph review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_creature_motion_visual_check.gd` saves the offscreen bubble burst before reveal, the fish entering from that origin, pufferfish jiggle, warning-off, and jellyfish breathing captures under ignored `test-results/bubbles-telegraphs/`. Inspect the ordered stills; they show rendered size and states but do not establish motion feel or owner readability/fairness approval.
For Bubbles shared-screen review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_presentation_visual_check.gd` saves empty, entrance, ten-player FHD/HD, warning on/off, final-timer, tied-results, and two-player maximum-bubble captures under ignored `test-results/bubbles-presentation/`. Inspect those images; technical render evidence does not establish couch-distance readability, final audio mix, or game feel.
For ready-screen composition, `godot --path . --rendering-method gl_compatibility --script res://tests/pre_minigame_visual_check.gd` saves two- and ten-player captures at 1920×1080 and 1280×720 under ignored `test-results/pre-minigame/`. The committed tablet preview comes from an active Bubbles capture made by the presentation visual helper. The WebSocket ready journey runs in `web/tests/ready_flow.test.mjs`.
For Bubbles viewport-wall review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_viewport_visual_check.gd` saves player-bubble edge-contact captures at 1920×1080 and 1280×720 under ignored `test-results/bubbles-viewport/`.
For a local desktop-browser phone preview, run `godot --headless --path . --script res://tests/bubbles_phone_preview.gd`, then join at `http://127.0.0.1:8080`. It starts a one-player Bubbles protocol fixture with eight collected jellyfish and the explicit debug label. Stop it before starting normal play. The browser/host suite runs the same fixture on separate ports; neither preview represents a playable arena or physical-phone validation.

## Networking, export, and operational warnings

- Listeners bind the configured LAN interfaces. HTTP/WS defaults and explicitly provisioned HTTPS/WSS are supported; registry reconnect tokens authenticate player input. There is no public hosting or CORS API. Never forward ports 8080/8081 to the Internet.
- If a phone cannot connect, check the selected adapter, both TCP ports, same Wi-Fi, guest/client isolation, VPN LAN restrictions, and Windows Firewall. The user handles private-network permission prompts; tooling does not change firewall or VPN settings.
- A busy service port shows Retry in boot. WebSocket bind failure rolls HTTP back rather than leaving a partial host.
- Editor/runtime checks do not prove a package. Smoke the exported executable without Godot or Node, including lobby, HTTP routes, WebSocket, and a browser connection.
- Preserve `web/public/`, the Kenyoni QR addon, external-PCK output, and the curated runtime/source-archive boundary in export changes.
- A phone reload creates a new transport connection but may resume the same player during grace. Duplicate active-token resume gives the newest tab ownership and closes the old connection.

## Network audit

Godot SessionHost starts custom TCP HTTP and WebSocket services on all interfaces by default, with separate 8080/8081 ports. The lobby discovers IPv4 addresses and sends SessionHost.join_url directly to its QR/address display. Phones obtain session metadata then connect/resume over WebSocket protocol 1. There is no Node server, mDNS/Bonjour discovery, environment framework, or Internet dependency. Hard-coded HTTP/WS URLs outside the canonical path are test/preview fixtures or documentation; fixtures explicitly opt out of workstation overrides. Keep local networking/certificate configuration outside tracked Resources and standalone packages. TLS listeners use Godot StreamPeerTLS, shared by HTTP and WebSocket via ControllerStream; no extra server/runtime dependency is required.

## Secure LAN transport

In editor/development, create ignored `local/network.json` (or select a JSON file with `PLAY_SHAPES_NETWORK_CONFIG`). In a standalone build, use `local/network.json` beside the executable. Relative PEM paths resolve beside the JSON file. Example:

```json
{"tls_enabled":true,"bind_address":"*","advertised_host":"","http_port":8080,"websocket_port":8081,"certificate_path":"certificate.pem","private_key_path":"key.pem"}
```

Restart the host. The lobby QR/address uses HTTPS and session discovery selects WSS; an empty advertised hostname keeps explicit LAN-IP selection. Certificates must cover that IP or the advertised hostname and be trusted on the phone. ControllerTLS checks readable PEM material, leaf validity against the host clock, and matching private/public keys before either listener binds. Both listeners start or neither does. Slow TLS/HTTP/WebSocket handshakes remain bounded by the existing request timeout. There is no insecure fallback or browser verification bypass. To return to HTTP, set `tls_enabled` false (or remove this local override), then restart. Do not install or modify trust implicitly. Use `node tools/local_https.mjs setup --ip LAN_IP` for certificate provisioning; see [controlled-device HTTPS and motion testing](docs/local-https-and-motion-testing.md) for exact enable/regenerate/disable commands, optional explicit host trust, Chrome iPhone/Android root installation, and the physical-device checklist. No system trust changes occur during setup. mDNS advertisement is intentionally deferred; explicit IP/SAN alignment is the initial controlled-test discovery strategy.

Verification: `godot --headless --path . --script tests/controller_tls_test.gd` generates disposable ignored fixture material; `node --test tests/tls.test.mjs` in web verifies HTTPS asset loading, WSS join/resume, rejection of untrusted and wrong-host certificates, and service availability alongside stalled handshakes. Test clients explicitly trust only their fixture certificate; they never disable verification. Secret file patterns and local configuration are ignored and excluded from both export presets.

## Reusable motion input

`web/src/motion_input.ts` wraps capability detection, both gesture-triggered permission requests, nullable raw motion/orientation fields, per-event freshness, counts/frequency, and explicit start/stop/suspend/resume. Unknown permissions on browsers without requestPermission stay honestly unknown; no-event and partial data remain observable. Reconnect does not presume permission persistence. `host/motion_input_channel.gd` owns a host-selected player-ID subscription with a fresh opaque subscription ID on each connection/lifecycle, strict finite bounded samples, increasing sequences, 30 Hz receive limit and 1000 ms stale threshold. `WebsocketService.begin_motion/end_motion` routes status/latest samples through authenticated registry connections and existing sockets, never accepting a client-authored player ID. The F12 lab activates capture and phone diagnostics; no motion stream starts in normal gameplay.

Orientation angles are W3C intrinsic Z-X'-Y'' degrees, rotationRate is degrees/s, acceleration is m/s². `MotionOrientation` maps W3C Z-up reference to Godot Y-up and supplies screen-compensated or physical portrait-phone bases. Physical slab rendering undoes UI screen-axis compensation so autorotation alone cannot rotate the hardware representation. Missing orientation is never fabricated, relative yaw is not a guaranteed compass, and accelerometer readings do not determine position. Recenter/smoothing belong to the consuming lab, not raw samples. Focused checks: tests/motion_input_channel_test.gd and web/tests/motion_input.test.mjs.

## F12 motion lab

Choose **Gyroscope and Accelerometer Lab** from F12, before or after joining. It automatically pins the connected registry seat 1, never connection order; expired identities require explicit **Bind current Player 1**. Only that phone receives a developer panel with **Request Motion Permission**, raw values and capability diagnostics. Return to lobby restores ordinary controls; restart/exit stops capture and clears old subscriptions. Reconnect rotates the subscription and shows the permission action again.

`debug/motion_lab/motion_lab.tscn` owns an isolated 3D SubViewport, marked toy phone, recenter/reset, optional quaternion smoothing (default 0 seconds), three reusable signed-axis/history plots (120 samples), and host receipt/phone transmission/event rates. Unavailable angles hold the last pose with a label; stale data is never presented as live. Plot ranges are exported (acceleration 20 m/s squared; rotation 180 degrees/s) and clamp drawing only. Raw data stays unchanged. Phone status heartbeats recover transitions coalesced by the bounded host channel; network backpressure skips samples rather than building a delayed queue.

Focused checks: `tests/motion_lab_test.gd`, `tests/motion_input_channel_test.gd`, `tests/debug_launcher_test.gd`, `web/tests/motion_lab_host.test.mjs` and `web/tests/motion_lab_controller.test.mjs`. `tests/motion_lab_visual_check.gd` produces a synthetic desktop capture under ignored `test-results/motion-lab/`; it is not physical sensor evidence. Use [the device checklist](docs/local-https-and-motion-testing.md) for the owner's Chrome iPhone/Android review.
