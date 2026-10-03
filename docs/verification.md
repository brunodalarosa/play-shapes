# Verification

## Verification

During this early development phase, controller connection/protocol errors appear in a selectable red panel with the failing step, endpoint, error text, browser version and WebSocket close details. It remains visible across retries and clears on successful welcome, including on Safari and standalone app layouts. Browser-hidden TLS causes remain explicitly unknown. Restart the host after rebuilding browser output so its startup-cached assets refresh; reload/relaunch the controller. See [development error reporting](controller-app-and-touch.md#development-error-reporting).

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
