# Verification

How to check a change: the one command that runs every automated check, the end-to-end test,
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

1. Every `*_test.gd` script in `tests/` and in the `tests/` folder of each minigame, and
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
7. The end-to-end test described below.

How it reports:

- One line per failure and a one-line summary.
- Full output for each check is in ignored `test-results/check/`.
- A Godot script fails on a non-zero exit code, on any `ERROR` line, and on any line Godot
  prints at exit about something still held, whether Godot calls it an error or a warning.
- The export test that runs with `--release` is excused the lines about things held at exit.
  It quits the editor, and the editor always holds a great deal when a script quits it.

Options and single runs:

```powershell
node tools/check.mjs bubbles web-tests   # only checks whose name contains a filter
node tools/check.mjs --full              # end-to-end round with every default
node tools/check.mjs --release           # also run the Windows export test
godot --headless --path . --script res://tests/player_registry_test.gd   # one script, full output
godot --headless --editor --path . --quit-after 30                        # editor import scan
```

Before running:

- Close any interactive host. The browser suite refuses to run over an existing host.
- The browser suite uses ports `18080`/`18081` for its startup lifecycle checks.
- `GODOT_BIN` overrides the Godot executable for the check command and the browser tests.

## The end-to-end test

`web/e2e/bubbles_two_phones.spec.ts` runs the real phone client in two emulated Pixel 7
Chromium contexts against the real host on ports 18200/18201. The phones join, walk in the
lobby, ready up, swipe through a Bubbles round and return to the lobby.

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
- By default it shortens only the Bubbles round, to 10 s and in memory. `E2E_ROUND=full` keeps
  every default.
- It prints `E2E round ending` two seconds before the round ends, and the phones stop swiping
  then. A swipe that reaches the host after the round has ended is rejected as
  `stale_or_unavailable`, and the phone shows that rejection in its error panel.

The test fails on a missing step, a phone without an accepted swipe, a page error, a visible
phone error panel, or a host `ERROR` line.

- Each phone saves a screenshot per step in `test-results/e2e/`, with a Playwright trace when
  the test fails.
- It is `[AUTO]` evidence from desktop Chromium. It never stands in for `[PHYSICAL-PHONE]`.

```powershell
cd web
npm run e2e                                    # the test alone
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

Five scripts do not use the base:

- `pre_minigame_server.gd`, `motion_lab_server.gd` and `e2e/host.gd` in `tests/`, and
  `bubbles_phone_preview.gd` in the Bubbles `tests/` folder, are hosts that a browser test
  starts and stops. They never reach an end.
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

- Tilt Shift art: `python tools/assets/prepare_tilt_shift_art.py check` compares
  runtime pixels, alpha, padding and import policies against the source masters.
  `tests/tilt_shift_art_test.gd` loads all textures and checks their shared pivots
  and contact references. [The source guide](../art/tilt_shift/README.md)
  describes isolated export-pack inspection.

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
under `test-results/`. All but the first need `--rendering-method gl_compatibility`; the first
uses the Compatibility renderer by default.

```powershell
godot --path . --rendering-method gl_compatibility --script res://tests/<helper>.gd
```

The helpers whose names start with `bubbles_` are in
`minigames/002_bubbles_and_jellyfishes/tests/`; use that folder in place of `tests/`.

| Helper | What it saves | Folder |
| --- | --- | --- |
| `bubbles_player_visual_check` | One player bubble: small, grown, spinning, pop and re-form, and ten players. Components only, not a composed arena. | `bubbles-player/` |
| `bubbles_animation_visual_check` | Player animation in order: small and maximum idle, held left drag, accepted swipe, slow held and released drag, charge glow and wobble, active spin, burst, reformed. | `bubbles-animation/` |
| `bubbles_creature_visual_check` | Creatures: entrance and warning, active creatures, white-blinking scatter. | `bubbles-creatures/` |
| `bubbles_creature_motion_visual_check` | Creature telegraphs in order: the offscreen bubble burst before reveal, the fish entering from that origin, pufferfish jiggle, warning off, jellyfish breathing. | `bubbles-telegraphs/` |
| `bubbles_presentation_visual_check` | The shared screen: empty, entrance, ten players at FHD and HD, warning on and off, final timer, tied results, two-player maximum bubble. | `bubbles-presentation/` |
| `pre_minigame_visual_check` | The ready screen with two and ten players at 1920×1080 and 1280×720. | `pre-minigame/` |
| `bubbles_viewport_visual_check` | Player-bubble edge contact at 1920×1080 and 1280×720. | `bubbles-viewport/` |
| `motion_lab_visual_check` | A synthetic desktop capture of the motion lab. Not physical sensor evidence. | `motion-lab/` |

- The committed tablet preview on the ready screen comes from an active Bubbles capture made
  by the presentation helper.
- A normal-profile editor load may print forced-shutdown RID and ObjectDB cleanup warnings
  after a successful scan. Treat exit zero with no script or import error as the result. Do
  not confuse cache or profile permission failures with product failures.

## Phone preview in a desktop browser

Run the preview host, then join at `http://127.0.0.1:8080`:

```powershell
$preview = "res://minigames/002_bubbles_and_jellyfishes/tests/bubbles_phone_preview.gd"
godot --headless --path . --script $preview
```

- It starts a one-player Bubbles protocol fixture with eight collected jellyfish and the
  explicit debug label.
- Stop it before starting normal play.
- The browser and host suite runs the same fixture on separate ports.
- Neither preview is a playable arena or a physical-phone check.

## After rebuilding the phone client

Restart the host after rebuilding the browser output, so its startup-cached assets refresh.
Then reload or relaunch the controller. The phone's development error panel is described in
[phone-client.md](phone-client.md#development-error-panel).
