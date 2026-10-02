# PS-082 platform stance and drop evidence

Implemented on 2026-10-02 on `codex/ps-081-platform-phone-controller`. Publication and human approval remain pending.

## Result and component boundaries

The registered phone contract now drives grounded look-up/crouch and explicit release actions through the WebSocket boundary and Playground adapter. `PlatformInput` shares the generated PS-081 classification settings; `PlatformMotor` owns reusable physics, input lease, presentation selection, bounce and per-body drop cleanup. `LobbySquircle` retains player/nameplate/color/blink/spawn glue. `PlatformSurface` exposes Open/Closed on every authored surface, with BottomShelf Closed and all ten raised supports Open. Art, collider alignment, upright character dimensions and one-way underside behavior are preserved.

The same motor/surface scripts run in `tests/fixtures/platform_reuse.tscn` on generic `CharacterBody2D` capsules with no lobby controller or registry. See [setup, protocol, tuning and reuse](platform-phone-controller.md#host-components-and-platform-setup).

A deliberate descent excludes one supporting Open body only. It temporarily disables this body's floor snap and restores it on clearance, another landing, edge exit, timeout, expired input or lifecycle cleanup. Repeated FALL while crouch remains held cannot bypass a second support; leave the down sector to rearm. Support deletion restores its exception on `tree_exiting`, before the engine frees the physics RID. Rejected attempts never queue a later action or become a jump.

## Technical verification

[AUTO] Godot `4.7.2.stable.official.ed1daf0bf`, focused headless checks passed with no parse/runtime errors:

- `tests/platform_input_test.gd`: finite/range/unit-disk validation, sector/radial hysteresis, coalesced snapshots, consistent stance hints, JSON precision at radial/angular boundaries and explicit action dispatch.
- `tests/platform_drop_reuse_test.gd`: real Open-to-Open-to-Closed landings, unchanged support for another player, independent platform toggles, floor snap, diagonal/stance/expiry behavior, repeated attempts, close stacked surfaces, character support, rebound, edge clearance, timeout, input lease, disconnect/resume, component removal, fall reset and freed-support cleanup.
- `tests/platform_lobby_boundary_test.gd`: actual Playground integration, release axes applied before eligibility, registered identity despite forged player_id, stale/invalid sequences and hints, repeated attempts, one-support descent and registry/context lifecycle resets.
- `tests/active_minigame_protocol_test.gd`: existing Bubbles active-protocol routing still passes.
- Updated `tests/lobby_playground_control_test.gd`, `tests/lobby_playground_world_test.gd`, and `tests/squircle_animation_lab_test.gd`: existing movement/jump/travel-facing, authored flags/geometry and shared held-pose playback/anchor release.

[AUTO] In `web/`: `npm install --cache .npm-cache`, `npm run check`, `npm run build` and `npm test` passed. All **62** browser tests passed, including actual registered WebSocket two-axis/FALL routing, sequence ownership, invalid action/vector/hint rejection, resume, ready-up gating and FALL rejection during Bubbles. The rebuilt offline bundle is unchanged because its PS-081 source already supplies this contract.

[EDITOR] Live editor opened from the repository root with `godot --editor --path . --quit-after 120`; exit 0 with no script/import errors.

[GODOT-RUNTIME] Full game ran from the root with `godot --path . --quit-after 180`, reached HTTP 8080 / WebSocket 8081 readiness and exited 0. Both editor and game reported OpenGL 3.3 Compatibility on NVIDIA GeForce RTX 5070.

[GODOT-RUNTIME] An ignored review helper drove the real Playground adapter, then captured and asserted the support locations. Inspected captures: `test-results/ps-082/stances.png` shows pink look-up/reach and cyan grounded crouch; `test-results/ps-082/next-platform.png` shows the pink player on LowerShelf while cyan remains crouched on UpperShelf. These verify rendered composition and technical landing, not subjective animation approval. The initial sandbox-only editor run had local settings/log/cache access errors; normal-profile runs above completed cleanly.

## Tuning and remaining owner review

Shared sectors remain 20 degrees on entry / 28 on exit, radial dead zone 0.16 with 0.04 hysteresis. Edit `DEFAULT_PLATFORM_SETTINGS` in `web/src/platform_input.ts`, rebuild and restart to keep phone/host aligned. The browser harness exposes temporary threshold overrides; production uses the shared generated bundle. Host motor Inspector defaults: 350 ms input lease, 0.65 s drop timeout, 4 px full-body clearance and 80 px/s initial descent. Existing speed/gravity/jump/bounce controls moved to `LobbySquircle/PlatformMotor`; visual scale remains on the character.

[PHYSICAL-PHONE] Pending: simultaneous stick/action touches, sector jitter and diagonals, button direction changes at release, repeated FALL, background/rotation, disconnect/resume and responsiveness on real phones.

[HUMAN-PLAY] Pending: owner stance/animation and game-feel review, especially sector widths, rearm gesture, drop speed/clearance and stacked/edge behavior. Test two players on one Open surface; drop one to the next surface, then verify BottomShelf rejects FALL and independently toggle another platform to Closed in the Inspector. Confirm grounded feet and unchanged character interaction.

[EXPORTED-BUILD] No new standalone package was produced for this task. Existing offline assets were preserved and rebuilt; these checks do not establish exported-package validation.

Publication remains owner-gated: local commit only; no push or PR.
