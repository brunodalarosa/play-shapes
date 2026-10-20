# Verification

How to check a change: the command for default and full automated coverage, end-to-end journeys,
the render helpers a person inspects, and the labels that say what kind of evidence a check
gives.

## Evidence labels

Every claim that something was verified carries one label. One label never implies another.

| Label | What was done |
| --- | --- |
| `[AUTO]` | An automated check ran and its result is quoted. |
| `[EDITOR]` | The project was opened in the Godot editor. |
| `[GODOT-RUNTIME]` | The game ran in Godot and was observed or captured. |
| `[DESKTOP-BROWSER]` | The phone client ran in a desktop browser. |
| `[PHYSICAL-PHONE]` | The phone client ran on a real phone. |
| `[EXPORTED-BUILD]` | The exported package ran. |
| `[HUMAN-PLAY]` | People played it. |

Render captures establish technical composition. They do not establish couch-distance
readability, accessibility, comfort, motion feel, fairness or creative approval. Those need a
person; what is waiting for one is in [pending-reviews.md](pending-reviews.md).

## The check command

```powershell
node tools/check.mjs
```

This is the default `[AUTO]` check. In order, it runs:

1. Default `*_test.gd` scripts in `tests/` and in the `tests/` folder of each minigame, and
   `tests/foundation.gd`, each in its own headless Godot process. New test scripts are picked
   up by name. [Test scripts](#test-scripts) says how
   one is written.
2. `node tools/format.mjs --check`, `node tools/lint.mjs` and `node tools/docs.mjs`. See
   [formatting-and-linting.md](formatting-and-linting.md).
3. The `tools/tests/` suite.
4. `npm run check` in `web/`, which type-checks the phone client and, with Node types, the
   end-to-end test files.
5. `npm test` in `web/`.
6. A rebuild of the browser bundle, which fails if `web/public/` changed.
7. The two-phone Bubbles and jellyfishes 3D and Tilt Shift 3D end-to-end
   journeys described below.

`--full` adds the 4/6/8/10-phone Tilt Shift 3D journeys and
`tilt_shift_3d_rotation_contact_test.gd`. The default retains the shorter Tilt Shift 3D
physics checks. Full coverage also keeps the full-length Bubbles and jellyfishes 3D round;
Windows export remains a separate `--release` option. Name filters do not override these
coverage options.

How it reports:

- One line per failure and a one-line summary.
- Full output for each check is in ignored `test-results/check/`.
- A Godot script fails on a non-zero exit code, on any `ERROR` line, and on any line Godot
  prints at exit about something still held, whether Godot calls it an error or a warning.
- The export test that runs with `--release` is excused the lines about things held at exit.
  It quits the editor, and the editor always holds a great deal when a script quits it.

Options and single runs:

```powershell
node tools/check.mjs bubbles_3d web-tests # only checks whose name contains a filter
node tools/check.mjs --full               # extended coverage and full-length Bubbles 3D
node tools/check.mjs --release            # also run the Windows export test
godot --headless --path . --script res://tests/player_registry_test.gd   # one script, full output
godot --headless --editor --path . --quit-after 30                        # editor import scan
```

Before running:

- Close any interactive host. The browser suite refuses to run over an existing host.
- The browser suite uses ports `18080`/`18081` for its startup lifecycle checks.
- `GODOT_BIN` overrides the Godot executable for the check command and the browser tests.

## The end-to-end test

`web/e2e/bubbles_3d_two_phones.spec.ts` runs the real phone client in two emulated Pixel 7
Chromium contexts against the real host on ports 18200/18201. The phones join, walk in the
lobby, ready up, swipe on the 3D phone screen (which loads `/three_view.js` and the models from
the host) through a Bubbles and jellyfishes 3D round and return to the lobby.

The host side is `tests/e2e/host.gd`:

- It sets the ports and loads the project's main scene, so the game's own boot starts the host
  and opens the lobby. A boot that cannot start the host fails the test at once with its
  message.
- It clicks Start once every character has moved and stood still, and Return to lobby after
  results have been up for 3 s.
- It clicks with mouse events injected at the button's place on screen, so Godot's hit testing
  applies. A button that is covered, off screen, disabled or ignoring the mouse stops the run
  with a message naming what was under the mouse. That covers reachability, not appearance.
- It prints one `E2E ...` line per event for the test to wait on.
- By default it shortens only the Bubbles and jellyfishes 3D round, to 10 s and in memory.
  `E2E_ROUND=full` keeps every default.
- `E2E_MINIGAME` names the catalog id it picks in the lobby before Start; the fixture sets it
  from the test's `game` option.
- It prints `E2E round ending` two seconds before the round ends, and the phones stop swiping
  then. A swipe that reaches the host after the round has ended is rejected as
  `stale_or_unavailable`, and the phone shows that rejection in its error panel.

The test fails on a missing step, a phone without an accepted swipe, a page error, a visible
phone error panel, or a host `ERROR` line.

`web/e2e/tilt_shift_3d_phones.spec.ts` runs the real boot/catalog/gameplay journey through
Tilt Shift 3D with `tests/e2e/tilt_shift_3d_host.gd` and synthetic sensors. Every phone loads
`/three_view.js` and the face parts and shows its own paddle, spectators included, and the test
also limits each phone's snapshot size and rate. Its two-phone scenario runs by default,
including delayed permission, portrait readiness revocation and reconnect; it ends after Tilt
Shift 3D returns to the lobby. Its 4/6/8/10-phone scenarios carry the `@full` tag and run only
with full coverage.

- Each phone saves a screenshot per step in `test-results/e2e/`, with a Playwright trace when
  the test fails.
- It is `[AUTO]` evidence from desktop Chromium. It never stands in for `[PHYSICAL-PHONE]`.

```powershell
cd web
npm run e2e                                    # the test alone
$env:E2E_ROUND = "full"; npm run e2e; Remove-Item env:E2E_ROUND   # all journeys, full Bubbles
$env:E2E_WINDOWED = "1"; npm run e2e; Remove-Item env:E2E_WINDOWED   # show the host and save its screenshots
npx playwright show-trace ../test-results/e2e/<test>/trace.zip    # inspect a failure
cd ..
```

## Test scripts

A test or a render helper extends `TestScript`, in `tests/test_script.gd`, and puts its body
in `_run()`, which may `await`:

```gdscript
extends TestScript


func _run() -> void:
	var registry := PlayerRegistry.new(10, 60.0)

	check(registry.player_count() == 0, "A new registry is empty")
```

- `check(condition, description)` records a failure when the condition is false and goes on.
  It returns the condition, so `if not check(...): return` stops a test where going on makes
  no sense. The description says what should be true.
- The script fails on a failed check, on a script error, and on any error the code under test
  logs. All three print an `ERROR` line.
- A script error ends `_run()` where it happened. The base still reports and quits.
- The script does not call `quit()`. The base frees what the test put in the tree, prints
  `<script name>: <count> failures` and exits with 0 or 1.
- A test that holds something at exit fails. The usual cause is two objects that hold each
  other, such as an object and a callback connected to its own signal that uses it.
  Disconnect the callback at the end of the test.
- `tests/test_script_test.gd` tests the base with the small scripts in `tests/fixtures/`.

Seven scripts do not use the base:

- `pre_minigame_server.gd`, `motion_lab_server.gd`, `e2e/host.gd` and
  `e2e/tilt_shift_3d_host.gd` in `tests/`, and
  `bubbles_3d_phone_preview.gd` in the Bubbles 3D `tests/` folder, are hosts that a browser test
  starts and stops. They never reach an end.
- `tests/multiplayer_motion_server.gd` is the ten-socket calibrated-control fixture;
  its browser test starts and stops it.
- `standalone_build_editor_integration_test.gd` runs inside the editor, where freeing the
  tree would free the editor.

## Which tests go through boot

End-to-end tests go through the game's boot scene. Unit, integration and single-minigame tests
start only what they need, so they stay fast.

## Export tests

- `tests/standalone_build_editor_integration_test.gd` performs a real Windows export and writes
  `builds/`. It needs matching installed export templates and runs only with `--release`.
  Without templates the command names the missing folder.
- `tests/standalone_build_test.gd` needs no templates and runs by default.
- After a local Windows release export, run
  `godot --headless --path . --script res://tests/lobby_export_pack_check.gd`. It verifies that
  the external PCK includes the offline phone modules, the Squircle metadata and sheets, and
  the required runtime paths.

## Focused checks by area

- Bubbles and jellyfishes 3D: the `tests/` folder of `minigames/004_3d_bubbles/` covers the
  round rules, Jolt arenas on real physics frames (plane locks, swipes, speed cap, wall and bump
  rebounds, catching, pops, scatter, caps, the zero freeze), the protocol, the shared-screen
  scene and the absence of spin. The shared 3D components have `plane_3d_test.gd`,
  `bubble_shell_3d_test.gd` and `underwater_environment_test.gd` in `tests/`. Run
  `node tools/check.mjs bubbles_3d plane_3d bubble_shell underwater`.

- Tilt Shift 3D assets: `shape_faces_test.gd` and `tilt_shift_3d_models_test.gd` in `tests/`
  check the face parts and presets and the bin against their verified exports. Run
  `node tools/check.mjs shape_faces tilt_shift_3d_models`. The exports themselves are verified
  by `export_faces.mjs` in
  [art/shape_characters_face_system_assets](../art/shape_characters_face_system_assets/README.md)
  and `export_and_verify.py` in [art/tilt_shift_3d](../art/tilt_shift_3d/README.md).

- Tilt Shift 3D: the `tests/` folder of `minigames/005_3d_tilt_shift/` covers the rules,
  allocation, delivery, presets, journeys, flow, preparation, motion, negative balls, Jolt
  physics on the plane (plane locks, rounded contacts, the turning bound, raised-floor catches,
  contact speeds), the expression rules, the presentation, the protocol and the workshop.
  `tilt_shift_3d_rotation_contact_test.gd` adds extended full turns and reversal with
  `node tools/check.mjs --full tilt_shift_3d_rotation_contact`.
- In `tests/`, `rounded_bar_test.gd`, `shape_face_test.gd`, `plane_3d_test.gd`,
  `tilt_shift_3d_props_test.gd` and `tilt_shift_3d_review_test.gd` cover the shared pieces,
  the copied assets and the F12 review. Run `node tools/check.mjs tilt_shift_3d rounded_bar
  shape_face plane_3d`. The phone's tests are in `web/tests/005_3d_tilt_shift/`.
- Run `node tools/verify_tilt_shift_3d_workshop.mjs` with other project editors closed to
  drive Tilt Shift 3D's workshop in the real editor; captures and logs are under
  `test-results/tilt-shift-3d/workshop/`.
- `web/tests/screen_wake_lock.test.mjs` checks page-level acquisition, refusal, external
  release, visibility, cached-page restoration, cleanup and pending-request races.
  The Tilt Shift 3D browser journey uses a synthetic wake lock across preparation, gameplay
  and lobby return. It does not prove the physical phone avoids automatic screen lock.
- Traffic and coordination costs are described in
  [flow tuning](../minigames/005_3d_tilt_shift/tuning/FLOW.md); motion and physics measurement
  boundaries are in [MOTION.md](../minigames/005_3d_tilt_shift/tuning/MOTION.md#measurement-boundaries)
  and [PHYSICS.md](../minigames/005_3d_tilt_shift/tuning/PHYSICS.md#measurement).
- `E2E_WINDOWED=1` enables real-host captures for those scenarios. It does not supply
  physical-phone evidence. The quick Tilt Shift 3D fixture maps two eight-second rounds;
  Bubbles and jellyfishes 3D retains its existing quick/full behavior.
- Set `E2E_EXPORTED_PACK` to the absolute Windows package PCK to run the same browser
  journey against exported resources in Godot. The driver remains an external test script;
  it rejects a package run that can see the workspace's test resources. This loads the
  exported boot, browser bundle, scenes and art. The release executable ignores external
  script drivers, so its startup/served-assets check is separate from this PCK journey.
- `debug_launcher_test.gd` checks the separately labeled simulated factory, ten synthetic
  players, automatic readiness/countdown, active paddle motion and ball delivery across
  every mapped round, results, no registered phones/subscriptions, restart and clean lobby return.
- Calibrated motion: `tilt_shift_3d_motion_test.gd` in `minigames/005_3d_tilt_shift/tests/`,
  `web/tests/motion_stream.test.mjs` and `web/tests/multiplayer_motion_host.test.mjs` cover
  repeated turns/reversal, calibration/gain, autorotation, capture failure states, ten real
  sockets, forged identity/subscription, replaced-tab resume and arena teardown.

- Local HTTPS: `godot --headless --path . --script tests/controller_tls_test.gd` generates
  disposable ignored fixture material. `node --test tests/tls.test.mjs` in `web/` verifies
  HTTPS asset loading, WSS join and resume, rejection of untrusted and wrong-host certificates,
  and service availability alongside stalled handshakes.
- Test clients explicitly trust only their fixture certificate. They never disable
  verification.
- Motion input: `tests/motion_input_channel_test.gd` and `web/tests/motion_input.test.mjs`.
- Motion lab: `tests/motion_lab_test.gd`, `tests/motion_input_channel_test.gd`,
  `tests/debug_launcher_test.gd`, `web/tests/motion_lab_host.test.mjs` and
  `web/tests/motion_lab_controller.test.mjs`.
- Ready-up over WebSocket: `web/tests/ready_flow.test.mjs`.
- Platform controls: see
  [platform-phone-controller.md](platform-phone-controller.md#harness-and-tests).

## Render helpers

Run a render helper only when its output will be inspected. Each writes ignored captures
under `test-results/`. All need `--rendering-method gl_compatibility`.

```powershell
godot --path . --rendering-method gl_compatibility --script res://tests/<helper>.gd
```

The helpers whose names start with `bubbles_3d_` are in `minigames/004_3d_bubbles/tests/`; use
that folder in place of `tests/`. Those starting with `tilt_shift_3d_` are in
`minigames/005_3d_tilt_shift/tests/`.

| Helper | What it saves | Folder |
| --- | --- | --- |
| `bubbles_3d_scene_visual_check` | Bubbles and jellyfishes 3D mid-round with five and ten players, catches of several sizes, free jellyfishes and two pufferfishes. | `bubbles-3d/` |
| `bubbles_3d_performance_check` | No capture: prints the frame time and draw calls of ten players with every jellyfish cap reached, vsync off. Run it on the target PC. | none |
| `tilt_shift_3d_presentation_visual_check` | Tilt Shift 3D with layout A and four players and layout B and six, through preparation, countdown, play with and without names and the round's end, then every colour on both teams. | `tilt-shift-3d/presentation/` |
| `tilt_shift_3d_performance_check` | Writes `performance.txt`: frame time, physics step and draw calls of ten players with the round's whole ball budget in 20 seconds, vsync off. Run it on the target PC. | `tilt-shift-3d/` |
| `shape_face_visual_check` | The twelve face presets drawn in 2D beside their references, compared within one pixel, and in 3D on paddles. In `tests/`. | `shape-face/` |
| `bubble_shell_visual_check` | Bubble shells of several sizes around tinted Squircles, one stretched and one bursting. | `bubble-shell/` |
| `underwater_environment_visual_check` | The underwater environment behind bubble shells through the 004 camera. | `underwater-environment/` |
| `pre_minigame_visual_check` | The ready screen with two and ten players at 1920×1080 and 1280×720. | `pre-minigame/` |
| `lobby_playground_world_visual_check` | The plaza lobby empty, and with ten players on the ground and every landing tier, some walking, crouching and looking up. | `lobby-playground-world/` |
| `lobby_layout_visual_check` | The lobby before and after two players join, and a character jumping in front of the billboard QR. | `lobby-layout/` |
| `motion_lab_visual_check` | A synthetic desktop capture of the motion lab. Not physical sensor evidence. | `motion-lab/` |

- A normal-profile editor load may print forced-shutdown RID and ObjectDB cleanup warnings
  after a successful scan. Treat exit zero with no script or import error as the result. Do
  not confuse cache or profile permission failures with product failures.

## Phone preview in a desktop browser

Run the preview host, then join at `http://127.0.0.1:8080`:

```powershell
$preview = "res://minigames/004_3d_bubbles/tests/bubbles_3d_phone_preview.gd"
godot --headless --path . --script $preview
```

- It starts a one-player Bubbles and jellyfishes 3D protocol fixture with eight collected
  jellyfish and the explicit debug label.
- Stop it before starting normal play.
- The browser and host suite runs the same fixture on separate ports.
- Neither preview is a playable arena or a physical-phone check.

## After rebuilding the phone client

Restart the host after rebuilding the browser output, so its startup-cached assets refresh.
Then reload or relaunch the controller. The phone's development error panel is described in
[phone-client.md](phone-client.md#development-error-panel).
