# Roadmap

What is done, what comes next, what is waiting, and which bugs are known. The project owners
decide what goes here. A change that finishes or adds work updates this document. The reasons
behind the choices are in [decisions/](decisions/README.md).

## The goal

Many minigames built from shared parts, especially input, and quick iteration on new and
existing ones. The game keeps playing the same while the code is reshaped; see
[decision 0001](decisions/0001-evolve-the-code.md).

## Done: making the project safe to change

- One command runs every automated check.
- One list of required tools, and a setup script that checks them.
- An end-to-end test that plays a round with two emulated phones.
- Formatters and linters, with the whole code base reformatted once.
- The development manual split into one document per area, held to one standard.
- A decision log and this roadmap.
- A branching model, Git Flow, with `develop` as the branch work merges into
  ([branching.md](branching.md)).
- No ticket numbers anywhere, with no exemptions: the names inside the Squircle Blender
  source were the last.
- One shared base for the test scripts
  ([0023](decisions/0023-shared-test-base.md)). A script error, or anything a test still
  holds at exit, fails the check at once.

## Done: the refactor so far

- One folder per minigame ([0015](decisions/0015-one-folder-per-minigame.md)), and a catalog
  of minigames that the lobby, the launch rules, the ready screen and the debug menu read
  ([0024](decisions/0024-minigame-catalog.md)).
- The phone client bundled into one script, so a new module needs no route and no export
  rule ([0016](decisions/0016-bundle-the-phone-client.md)).

## The refactor, in order

This is what comes next.

1. Split the phone client's largest module, `app.ts`. The client is already bundled into
   one file ([0016](decisions/0016-bundle-the-phone-client.md)).
2. The input pipeline: one message for gameplay input and reusable controls
   ([0017](decisions/0017-one-input-message.md)). The late-input bugs below belong here,
   and so does one shared phone helper for the browser tests, which this step rewrites.
3. A shared round lifecycle and a stage kit.
4. A shared character component, and screens rebuilt with containers and a theme
   ([0018](decisions/0018-ui-with-containers.md)).
5. Typed classes throughout the host. It starts with the lint list of files still allowed to
   declare a dictionary, and ends when only the two edges remain
   ([0019](decisions/0019-typed-classes.md)).
6. Tools for faster iteration: a control route for quick tests
   ([0004](decisions/0004-end-to-end-test.md)), a short-round tuning preset, screenshot
   comparison against references, bot phones that speak the protocol, and free ports in
   place of the hard-coded ones in the tests.

Each step gives the tests of the code it reshapes proper ways into that code. When the last
one has, the `private-access` lint rule is turned back on for `tests/`
([0007](decisions/0007-lint-rules-and-exceptions.md)).

After the input pipeline: bots that fill a game with players
([0008](decisions/0008-bots.md)).

## Tilt Shift foundation

Host rules and editable content exist for Tilt Shift: equal teams, balanced rotating
paddle assignments, immediate deadlines and cumulative team scoring. A shared physics
arena adds falling/colliding balls, full-turn paddles, basket catches and seeded delivery.

Calibrated multiplayer motion has its host consumer and reusable browser stream, with
per-player neutral, continuous turns, bounded comparison, reconnect policy and lifecycle.
The editor workshop provides snapped content editing, geometry guides, named saves and
actual gameplay preview. Readiness/phone presentation, production presentation and lobby
launch remain outside this foundation. Real-phone accuracy and feel await owner trials.
See [the rules contract](../minigames/003_tilt_shift/README.md).

## Backlog

- The first release, `0.1.0`: decide where the project and the Windows package record the
  version, then follow [branching.md](branching.md#a-release).
- Cloud CI, if hosted runners turn out to be free for this repository
  ([0021](decisions/0021-no-cloud-ci.md)).
- The end-to-end test on WebKit, in the `--full` run.
- Mark `web/public/` as generated for GitHub's diffs.
- Remove 21 `.uid` files whose scripts no longer exist.
- Shrink the code map in [architecture.md](architecture.md); it describes the code file by
  file and goes stale.
- Use Godot's own script warnings as a stricter GDScript lint.
- Format Markdown with a tool. Format and lint the Python art tools.
- A connection helper in the lobby: firewall, same Wi-Fi and guest-network tips. An idea,
  not yet asked for.

Reviews that need a person or a real phone are in [pending-reviews.md](pending-reviews.md).

## Known bugs

Input that is already on its way when the host changes phase is rejected, and the phone shows
its red error panel for the rest of the session. Two cases are known:

- Pressing Start while a phone holds the lobby stick. The host answers `lobby_unavailable`.
  To reproduce, set `AT_REST_SECONDS` to `0.0` in `tests/e2e/host.gd` and run `npm run e2e`
  in `web/`.
- Releasing a swipe as a Bubbles round ends. The host answers `stale_or_unavailable`. To
  try to reproduce, set `ROUND_ENDING_MSEC` to `0` in the same file and run
  `node tools/check.mjs --full e2e`. It fails only when a swipe happens to land as the round
  ends, which depends on timing.

Late input after a phase change should be dropped quietly. The end-to-end test avoids both
cases on purpose; fixing the bug means removing those two waits.

On Windows with Godot 4.7.2, `tilt_shift_rules_test` and `tilt_shift_motion_test` have exited with code
`3221225477` during native shutdown after printing zero assertion failures. It also
reproduces for the rules test in a fresh, fully imported copy of the rules-only commit. Treat that exit as
a failed check, retain its log and report it separately from assertion results; its
cause remains unresolved.

On Windows, the browser bundle rewrite after the browser suite can fail with
`The requested operation cannot be performed on a file with a user-mapped section open.`
Preserving the generated file in an ignored folder and regenerating it permits the focused
bundle check to pass, but the full run can reproduce the lock. Its cause remains unresolved;
retain the failed full-run logs rather than calling the complete check passed.
