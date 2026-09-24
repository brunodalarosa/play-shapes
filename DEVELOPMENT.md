# Play Shapes development

This is the compact implementation manual for the current checkout. It records how the project works now, how to run and verify it, and operational caveats that are easy to rediscover. It is not the planning system or the task history.

## Current status

- Godot 4.7.2 is the authoritative host; phone controllers are bundled HTML/CSS/JavaScript clients over local HTTP and WebSockets.
- The lobby selects **Flash? Pose!** or **Bubbles and Jellyfishes**. Both support 2–10 registered players; the lobby supports 20.
- F12 provides separate one-real-player debug scenarios for both games. They create no simulated player; Flash? Pose! keeps its debug lives and Bubbles labels the round on the host and phone.
- The host defaults to a responsive 1920×1080 GL Compatibility presentation.
- **Project > Tools > Build Standalone Host** creates a portable Windows x86_64 release ZIP. Linux is deliberately deferred.
- Existing iPhone/Android human-play evidence covers Flash? Pose!. Bubbles still needs the owner's two-phone and game-feel review; do not generalize evidence across games or to every device, browser, network, accessibility setup, or feel call.

## Documentation boundaries

The parent `Play Shapes/` directory is the Markdown planning and game-design vault. This nested `play-shapes/` directory is the Git repository and Godot project root. Do not move material between those layers merely for convenience.

Canonical sources:

- Repository execution rules: [AGENTS.md](AGENTS.md)
- Human + AI workflow: [Workflow](../Project/Workflow.md)
- Task types, lifecycle, frontmatter, and gates: [Task System](../Project/Task%20System.md)
- Product context: [Project Overview](../Project/Project%20Overview.md)
- Durable choices: [Decision Log](../Decisions/Decision%20Log.md)
- Current tasks: [Task board](../Management/Task%20board.md)
- Task-specific scope and evidence: notes under `../Management/Tasks/`
- Player setup and use: [README.md](README.md)
- Tuning workflow: [Tuning/README.md](Tuning/README.md)

Completed task notes are immutable historical records. Their old terminology or then-current limitations must not be treated as active instructions. Current work does not create exploration or validation tasks; it uses `asset-import` for new development media, includes human validation in the implementation flow, and waits for explicit human approval before remote publication. Refer to the canonical sources above instead of duplicating those rules here.

## Project location and running

Run Git, Godot, browser build, and tests from this `play-shapes/` repository, not from the parent vault. `project.godot` must remain at its root.

```powershell
godot --version
godot --path .
```

Use **F5** for the complete boot/lobby flow. Use **F6** only when an individual scene is designed for direct execution. The user shim is `C:\Users\backup pc\.local\bin\godot.cmd`; see `AGENTS.md` for the installed GUI path and optional MCP/OpenCode setup.

In the lobby, choose a reachable Wi-Fi/Ethernet IPv4 address, then scan the QR or type the displayed URL on a phone on the same LAN. Discovery runs at launch and on Refresh; it prefers common `192.168.*` addresses but is not default-route detection. Loopback, link-local, and IPv6 addresses are excluded. VPNs, multiple adapters, guest Wi-Fi, and client isolation can require a manual choice or prevent access.

Normal play starts with 2–10 registered players. Choose a minigame from the lobby dropdown before starting. For debug, register exactly one phone, press F12, and choose the matching one-player scenario. Restart and lobby return preserve the running `SessionHost`, player registry, and LAN services.

## Runtime architecture and code map

- `scenes/boot.*` starts services and presents Retry after startup failure.
- `host/session_host.gd` persists services and the registry across scene changes. It discovers addresses, constructs URLs, and rolls HTTP back if WebSocket binding fails.
- `host/http_service.gd` serves a fixed asset allowlist with bounded requests; it never serves a client-selected filesystem path.
- `host/websocket_service.gd` owns bounded protocol-1 peers/messages and resolves each connection to a host-owned player before forwarding gameplay input.
- `host/player_registry.gd` owns session/player/token identities, names, capacity, reconnect grace, resume, and explicit leave.
- `scenes/lobby.*` owns the responsive lobby, QR/address controls, roster, temporary minigame dropdown, selected launch, and shared 2–10 player gate. The roster switches to two columns above ten players and fits the supported 20 without page scrolling.
- `minigames/flash_pose_round_controller.gd` owns phases, timing, targets, two normal-play lives, elimination, withdrawal, and ranking. It delegates pose truth to `host/pose_evaluation_rules.gd`.
- `minigames/bubbles_round_controller.gd` owns the separate Bubbles instructions/countdown/active/results lifecycle, score and pop state, host-time finish freeze, and snapshots keyed by player ID. `bubbles_gesture_classifier.gd` validates and classifies one completed normalized trace. The shared-screen scene is `minigames/bubbles_and_jellyfishes.tscn`.
- `minigames/bubbles_player_bubble.tscn` reuses `ShapeCharacter` in a code-drawn translucent bubble with a per-instance circle collider, capped approved small-jellyfish art, and readable name. `bubbles_player_arena.gd` creates 1–10 bodies and steps movement, invisible bounds, and player pairs in sorted player-ID order. Call `setup(controller, npc_bounds, optional_wall_bounds)`, then `add_bubble(player_id, position)` from the controller's participant snapshot; call `simulate_step(fixed_delta, host_time_msec)` from the host physics loop (normally 1/60 second, maximum 0.05). `bounds` retains the logical NPC play area; player bubbles use the optional wall bounds. The arena settles the controller clock before movement, so exact-zero results freeze first. Bodies consume only the controller's accepted swipe/spin/pop signals and score snapshots.
- `BubblesPresentation` derives player-bubble wall bounds from the visible viewport rectangle at launch and on resize. Wall padding uses each bubble's transformed radius so its visible edge meets the viewport edge; NPC boundary behavior remains separate.
- `minigames/bubbles_creature_arena.gd` owns free jellyfish and pufferfish scenes, initial safe spawns, alternating waves, warning/crossing paths, and host-time collection/hit checks. The shared-screen scene creates player bodies, then calls `setup(controller, player_arena)` before `complete_entrance()`. Each fixed host step calls the player arena first, then `creature_arena.simulate_step(fixed_delta, host_time_msec)` with the same time. The controller alone accepts collections and pops; creature sprites never decide rules. Free jellyfish obey the tuning cap, including scatter after a pop; overflow is reported by `jellyfish_scattered` and discarded.
- `minigames/flash_pose_presentation.gd` owns shared-screen animation, audio, flash, feedback, and the persistent `WINNERS`/`LOSERS` results view. It consumes semantic outcomes and never infers rules from sprite transforms.
- `host/flash_pose_protocol.gd` is the narrow gameplay protocol adapter.
- `host/bubbles_protocol.gd` validates completed normalized traces and makes personalized Bubbles snapshots. `WebsocketService` keeps one active protocol at a time. `BubblesPresentation` consumes the prepared host launch, observes registry reconnect/leave changes, registers its controller for the round, and unregisters it on exit. The scene owns fixed-order arena stepping, instructions/entrance, countdown, timer, approved background layers, semantic audio, debug labeling, results, and the host return button. The browser never supplies player ID or host time.
- `characters/hybrid_character_animator.gd` consumes semantic dance, pose, reaction, elimination, and result states. Gameplay must not manipulate child sprites or inspect animation frames to decide outcomes.
- `debug/` contains the non-pausing F12 scenario catalog and debug scenes. The launcher remains present in development exports.
- `Tuning/` contains the active selector, named resources, guide, and experiment template. There is no runtime tuning UI.
- `web/src/` is TypeScript source. `web/public/` is the committed offline runtime bundle served by Godot; normal play needs neither Node nor Internet.
- `assets/runtime/` is the curated runtime-media boundary. Source/archive art remains outside it and is excluded from Godot import/export.
- Bubbles static art lives in `assets/runtime/minigames/bubbles_and_jellyfishes/`; its [asset guide](assets/runtime/minigames/bubbles_and_jellyfishes/README.md) records scale, filtering, layer composition and provenance. [GIMP regeneration and isolated export-pack checks](art/bubbles/README.md) remain separate from gameplay implementation.
- `addons/standalone_build/` is the editor-only Windows builder. `addons/kenyoni/qr_code/` is the required vendored runtime QR dependency.
- `tests/` holds focused headless, integration, policy, and render checks; generated evidence belongs under ignored `test-results/`.

## Host authority and protocol reference

The host owns session state, player identity, deadlines, lives, results, and receipt time. Phones send UI actions and controller input only.

Defaults in `Tuning/Shared/Networking/Default.tres`:

- HTTP `8080`; WebSocket `8081`
- 32 transport connections per service; 20 registered players
- five-second request/handshake timeout; 60-second reconnect grace

`GET /session.json` returns protocol and WebSocket port. The browser uses the page hostname for `ws://HOST:PORT`. Fixed HTTP routes are `/`, `/app.js`, `/controller_geometry.js`, `/bubbles_gesture.js`, `/bubbles-jellyfish.png`, `/style.css`, and `/session.json`. Unknown routes return 404; non-GET methods return 405; headers beyond 8192 bytes are rejected with 431 or a TCP reset when unread bytes remain on Windows. Responses close after the final bytes have time to flush, so the larger jellyfish PNG loads completely.

Protocol 1 begins with `hello`/`welcome`, then supports join, resume, leave, and personalized lobby/gameplay state. The registry deliberately separates transport `connection_id`, host-owned session-scoped `player_id`, host-owned `session_id`, and opaque browser-held reconnect token. The browser stores only the session ID, token, last-used name, and monotonically increasing gameplay sequence needed to resume safely. A client-supplied player ID has no authority. New joins are lobby-only; valid resumes remain available during gameplay. Disconnect clears a held pose or unfinished Bubbles trace; resume requires a new gesture. Bubbles sends one `bubbles_trace` (at most 128 normalized points, 8192-byte packet ceiling) on touch release. The host replies with `bubbles_trace_result` and a `bubbles_snapshot`; `bubbles_feedback` carries collection, spin, and pop cues. Reconnect embeds the latest personalized snapshot in `welcome.gameplay`.

The only phone-to-host Flash? Pose! gameplay payload is:

```json
{"type":"pose_down|pose_up","direction":"left|right|down|up","input_seq":1}
```

The adapter rejects client timestamps, player IDs, targets, deadlines, charge, lives, outcomes, malformed values, and stale sequences. JSON-decoded sequences may arrive as Godot floats, so validation accepts only finite, whole, non-negative values within JavaScript's exact integer range, then normalizes to `int`. The exact evaluation deadline is inclusive until resolution.

The host sends personalized `flash_pose_snapshot`, `flash_pose_challenge`, `flash_pose_result`, `flash_pose_results`, and `lobby` messages. Controls remain available throughout the round; only the host's genuine-stop deadline determines success. Direction availability progresses from two to three to four.

## Tuning and content boundaries

Open `Tuning/Active Presets.tres` to select named resources. Current front doors are `Tuning/Minigames/SimonSays/Default.tres`, `Tuning/Minigames/Bubbles/Default.tres`, and `Tuning/Shared/Networking/Default.tres`. Restart to apply a changed selection. Bubbles field descriptions are in `Tuning/Minigames/Bubbles/README.md`. Only the human owner promotes subjective feel into `Default`; tests establish configuration safety, not fun or comfort.

For Inspector help, put a `##` documentation comment immediately before the export annotation and variable declaration. Use `@export_group`, not `@export_category`, because categories can break subsequent property help. `tests/tuning_presets_test.gd` enforces this and recursively checks committed presets.

Shape Character runtime art is manifest-owned under `assets/runtime/shape_characters/`; production `.gd`, `.tscn`, and `.tres` files must reference that root, never `assets/Kenney_Shape_Characters/`. To change the curated set:

```powershell
python tools/assets/runtime_asset_pipeline.py sync
godot --headless --editor --path . --quit-after 30
python tools/assets/runtime_asset_pipeline.py sync
godot --headless --editor --path . --quit-after 30
python tools/assets/runtime_asset_pipeline.py check
python -m unittest tests/runtime_asset_pipeline_test.py
godot --headless --path . --export-pack "PS-021 Validation Pack" test-results/ps-021/curated.pck
python tools/assets/runtime_asset_pipeline.py check-export --pack test-results/ps-021/curated.pck
```

Do not hand-edit generated runtime copies. Preserve source archives after runtime removal. If GIMP displays false transparent stripes in indexed originals, do not overwrite them; use `tools/assets/prepare_gimp_inputs.py` to make verified RGBA working copies under ignored `test-results/`. If the normal uv cache is blocked, point `UV_CACHE_DIR` at an ignored subdirectory there.

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

Every top-level module imported by `app.js` must also appear in the explicit `HttpService` allowlist and release filter. A 200 response for `/app.js` does not prove its module graph works: a missing `/controller_geometry.js` previously left phones forever at `Connecting to the host…`. The export presets already include `web/public/*.js`; served tests request both imported modules and the Bubbles art route.

The Flash? Pose! phone surface remains fixed, non-scrolling, and landscape-oriented. The Bubbles surface is a full-screen portrait touch area with exact host score, capped decorative jellyfish, and a visual spin meter. The browser attempts fullscreen/orientation lock after a gesture eligible for that game, unlocks when returning to lobby, and adjusts the lock on game changes; denial or unsupported APIs are valid fallbacks. The opposite orientation shows a rotate prompt. Safari works, but Chrome currently provides the most consistent fullscreen/orientation behavior.

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
godot --headless --path . --script res://tests/pose_evaluation_rules_test.gd
godot --headless --path . --script res://tests/flash_pose_round_controller_test.gd
godot --headless --path . --script res://tests/bubbles_gesture_classifier_test.gd
godot --headless --path . --script res://tests/bubbles_round_controller_test.gd
godot --headless --path . --script res://tests/bubbles_player_physics_test.gd
godot --headless --path . --script res://tests/bubbles_creature_arena_test.gd
godot --headless --path . --script res://tests/bubbles_protocol_test.gd
godot --headless --path . --script res://tests/bubbles_presentation_test.gd
godot --headless --path . --script res://tests/active_minigame_protocol_test.gd
godot --headless --path . --script res://tests/flash_pose_protocol_test.gd
godot --headless --path . --script res://tests/flash_pose_presentation_test.gd
godot --headless --path . --script res://tests/flash_pose_flow_test.gd
godot --headless --path . --script res://tests/debug_launcher_test.gd
godot --headless --path . --script res://tests/tuning_presets_test.gd
godot --headless --path . --script res://tests/minigame_flow_test.gd
```

Builder checks require matching installed export templates:

```powershell
godot --headless --path . --script res://tests/standalone_build_test.gd
godot --headless --editor --path . --script res://tests/standalone_build_editor_integration_test.gd
```

Run visual helpers only when their output will be inspected; they write ignored artifacts under `test-results/`. A normal-profile editor load may emit forced-shutdown RID/ObjectDB cleanup warnings after a successful scan. Treat exit zero plus no script/import error as the result; do not confuse cache/profile permission failures with product failures.
For isolated Bubbles player-component review, `godot --path . --script res://tests/bubbles_player_visual_check.gd` uses the Compatibility renderer and saves small/grown/spinning, pop/re-form, and ten-player captures under ignored `test-results/ps-042/`. These are component renders, not a composed arena or human feel evidence.
For isolated Bubbles creature review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_creature_visual_check.gd` saves entrance/warning, active creatures, and white-blinking scatter captures under ignored `test-results/ps-043/`. These renders do not establish collision fairness or a complete scene.
For Bubbles shared-screen review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_presentation_visual_check.gd` saves empty, instruction, ten-player FHD/HD, warning on/off, final-timer, tied-results, and two-player maximum-bubble captures under ignored `test-results/ps-045/`. Inspect those images; technical render evidence does not establish couch-distance readability, final audio mix, or game feel.
For Bubbles viewport-wall review, `godot --path . --rendering-method gl_compatibility --script res://tests/bubbles_viewport_visual_check.gd` saves player-bubble edge-contact captures at 1920×1080 and 1280×720 under ignored `test-results/ps-047/`.
For a local desktop-browser phone preview, run `godot --headless --path . --script res://tests/bubbles_phone_preview.gd`, then join at `http://127.0.0.1:8080`. It starts a one-player Bubbles protocol fixture with eight collected jellyfish and the explicit debug label. Stop it before starting normal play. The browser/host suite runs the same fixture on separate ports; neither preview represents a playable arena or physical-phone validation.

## Networking, export, and operational warnings

- Listeners bind all interfaces for LAN play. There is no TLS, authentication, public hosting, or CORS API. Never forward ports 8080/8081 to the Internet.
- If a phone cannot connect, check the selected adapter, both TCP ports, same Wi-Fi, guest/client isolation, VPN LAN restrictions, and Windows Firewall. The user handles private-network permission prompts; tooling does not change firewall or VPN settings.
- A busy service port shows Retry in boot. WebSocket bind failure rolls HTTP back rather than leaving a partial host.
- Editor/runtime checks do not prove a package. Smoke the exported executable without Godot or Node, including lobby, HTTP routes, WebSocket, and a browser connection.
- Preserve `web/public/`, the Kenyoni QR addon, external-PCK output, and the curated runtime/source-archive boundary in export changes.
- A phone reload creates a new transport connection but may resume the same player during grace. Duplicate active-token resume gives the newest tab ownership and closes the old connection.
- Controls intentionally remain active during countdown, dance, stops, and flash waits. Do not make phone UI visibility decide a host outcome.

## Historical implementation index

These are historical context, not active instructions. The linked note owns detailed scope, findings, evidence, and outcome.

| Task | Date | Result |
|---|---|---|
| [PS-004](../Management/Tasks/Done/PS-004%20-%20Define%20the%20Game-Feel%20Tuning%20Strategy.md) | 2026-09-14 | Approved the editor-first tuning and preset model. |
| [PS-005](../Management/Tasks/Done/PS-005%20-%20Define%20Multi-Phone%20and%20Agent%20Validation%20Strategy.md) | 2026-09-15 | Defined evidence labels and the MVP two-phone matrix. |
| [PS-006](../Management/Tasks/Done/PS-006%20-%20Implement%20Player%20Join%20and%20Host-Owned%20Registry.md) | 2026-09-14 | Added host-owned identity, join, resume, leave, and roster. |
| [PS-007](../Management/Tasks/Done/PS-007%20-%20Define%20the%20Gameplay%20Debug%20Suite.md) | 2026-09-13 | Approved the minimal F12 host scenario launcher. |
| [PS-009](../Management/Tasks/Done/PS-009%20-%20Create%20and%20Import%20Character%20Feet%20Assets.md) | 2026-09-13 | Added approved feet and the six-part character setup. |
| [PS-010](../Management/Tasks/Done/PS-010%20-%20Explore%20Character%20Animation%20Strategy.md) | 2026-09-13 | Selected hybrid detached-sprite animation. |
| [PS-011](../Management/Tasks/Done/PS-011%20-%20Implement%20Hybrid%20Character%20Animation%20Lab.md) | 2026-09-13 | Proved and visually approved the animation lab. |
| [PS-012](../Management/Tasks/Done/PS-012%20-%20Implement%20Milestone%201%20Character%20Animation%20System.md) | 2026-09-15 | Promoted semantic animation to production. |
| [PS-013](../Management/Tasks/Done/PS-013%20-%20Implement%20Pose%20Charge%20and%20Evaluation%20Rules.md) | 2026-09-17 | Added authoritative charge, deadlines, and evaluation. |
| [PS-014](../Management/Tasks/Done/PS-014%20-%20Implement%20Minimal%20Gameplay%20Debug%20Launcher.md) | 2026-09-13 | Implemented the persistent F12 launcher. |
| [PS-015](../Management/Tasks/Done/PS-015%20-%20Implement%20Shared%20Tuning%20Asset%20and%20Preset%20Workflow.md) | 2026-09-14 | Added active presets, validation, and guidance. |
| [PS-016](../Management/Tasks/Done/PS-016%20-%20Create%20Wireframe%20for%20001%20-%20Dancer%20Simon%20Says.md) | 2026-09-15 | Recorded shared-screen and phone wireframes. |
| [PS-017](../Management/Tasks/Done/PS-017%20-%20Find%20Better%20Environment%20Assets%20for%20001%20-%20Dancer%20Simon%20Says.md) | 2026-09-16 | Selected the Milestone 1 environment set. |
| [PS-018](../Management/Tasks/Done/PS-018%20-%20Create%20the%20001%20-%20Dancer%20Simon%20Says%20Minigame%20Scene.md) | 2026-09-17 | Added the editor-authored lead and ten-seat stage. |
| [PS-019](../Management/Tasks/Done/PS-019%20-%20Plan%20the%20001%20-%20Dancer%20Simon%20Says%20Minigame%20Implementation.md) | 2026-09-16 | Fixed the bounded implementation sequence and policies. |
| [PS-020](../Management/Tasks/Done/PS-020%20-%20Find%20Music%20and%20SFX%20for%20001%20-%20Dancer%20Simon%20Says.md) | 2026-09-16 | Selected music and flash candidates. |
| [PS-021](../Management/Tasks/Done/PS-021%20-%20Implement%20Curated%20Runtime%20Asset%20Pipeline.md) | 2026-09-16 | Added the manifest-owned runtime art boundary. |
| [PS-023](../Management/Tasks/Done/PS-023%20-%20Prepare%20Flash%20Pose%20Runtime%20Music%20and%20SFX.md) | 2026-09-17 | Added the runtime audio catalog and metadata. |
| [PS-024](../Management/Tasks/Done/PS-024%20-%20Implement%20Flash%20Pose%20Host%20Round%20Controller.md) | 2026-09-17 | Implemented authoritative round phases. |
| [PS-025](../Management/Tasks/Done/PS-025%20-%20Implement%20Flash%20Pose%20Phone%20Protocol%20and%20Controller.md) | 2026-09-17 | Added validated pose packets and phone states. |
| [PS-026](../Management/Tasks/Done/PS-026%20-%20Implement%20Flash%20Pose%20Shared%20Screen%20Feedback%20and%20Results.md) | 2026-09-17 | Added presentation, audio, flash, and results. |
| [PS-027](../Management/Tasks/Done/PS-027%20-%20Integrate%20Flash%20Pose%20Lobby%20and%20Debug%20Flow.md) | 2026-09-18 | Integrated normal/debug launch and return. |
| [PS-028](../Management/Tasks/Done/PS-028%20-%20Validate%20Flash%20Pose%20Technical%20Loop.md) | 2026-09-18 | Recorded owner verification of the integrated loop. |
| [PS-029](../Management/Tasks/Done/PS-029%20-%20Validate%20Flash%20Pose%20on%20Two%20Phones%20and%20in%20Human%20Play.md) | 2026-09-18 | Recorded working Android and iPhone play. |
| [PS-030](../Management/Tasks/Done/PS-030%20-%20Rework%20Flash%20Pose%20Phone%20Controller%20Layout.md) | 2026-09-18 | Added 2/3/4-region landscape controls and fixed module serving. |
| [PS-031](../Management/Tasks/Done/PS-031%20-%20Set%20FHD%20Host%20Resolution%20and%20Rework%20Lobby%20Layout.md) | 2026-09-19 | Set FHD defaults and a non-scrolling lobby. |
| [PS-032](../Management/Tasks/Done/PS-032%20-%20Clarify%20Results%20Labels%20and%20Return%20Button.md) | 2026-09-19 | Added `WINNERS`/`LOSERS` and clearer return. |
| [PS-033](../Management/Tasks/Done/PS-033%20-%20Design%20Standalone%20Windows%20and%20Linux%20Build%20Workflow.md) | 2026-09-19 | Chose Windows ZIP first and deferred Linux. |
| [PS-034](../Management/Tasks/Done/PS-034%20-%20Implement%20One-Click%20Windows%20Standalone%20Build%20Workflow.md) | 2026-09-19 | Implemented and smoke-tested the Windows package. |
