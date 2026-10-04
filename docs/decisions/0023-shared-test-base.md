# 0023. Test scripts share one base of our own, and any logged error fails them

Decided by the project owners on 2026-10-03.

## Situation

Each test script carried its own copy of a check helper, its own failure count and its own way of quitting. There were ten versions of the helper in 24 scripts, and four more scripts used `assert`. A script error or a failed `assert` ended the test's function without quitting, so the script sat until the check command's three-minute timeout. Three passing tests still held objects when they quit, and the check command ignored what Godot printed about it.

The alternative was a test framework, GUT or gdUnit4. Either is a vendored addon and a rewrite of every test into its shape. The check command already runs each script in a Godot process of its own, which gives the isolation a framework would.

## Decision

Tests and render helpers extend `TestScript`, a small base in `tests/`. It runs the test's body, counts every error Godot logs while it runs, frees what the test put in the tree, reports and quits.

Failures are counted by a `Logger`, not by the check helper. A failed check, a script error and an error raised by the code under test are then the same thing: an error line and one failure. The exit code agrees with the output whether the check command or a person runs the script.

The check command fails a script on any line Godot prints at exit about something still held.

## What follows

- A script error returns to the base, which quits. Godot returns to the caller of a function that errors, also across `await`, and the base relies on that.
- Before quitting, the base waits for two audio mixes. A sound still playing is let go by the audio thread, and frames pass faster than mixes when nothing is drawn; without the wait a test that played a sound held it at exit in some runs and not in others.
- A test waiting on a signal that never comes still runs into the check command's timeout.
- The hosts a browser test starts, and the export test that runs inside the editor, do not use the base. [verification.md](../verification.md#test-scripts) lists them.
- The export test is excused the lines about things held at exit, because the editor holds a great deal when a script quits it.
- The ports, the browser tests' phone helper and the tests' reach into private members were planned with this change. They moved into the refactor steps that rewrite the same tests; the [roadmap](../roadmap.md) says where.
