# 0002. One command defines verified

Decided by the project owners on 2026-10-03.

## Situation

Verification was a hand-kept list of commands that had fallen behind the tests. A Godot test could also print an error and still exit with success.

## Decision

`node tools/check.mjs` is the definition of an automated pass. It finds the Godot test scripts by name, and runs the format, lint and document checks, the tool tests, the browser type check and tests, the bundle check and the end-to-end test.

A Godot script fails on a non-zero exit code or on any `ERROR` line.

## What follows

- A change is reported as verified only with this command's output.
- Lines Godot prints about objects still held at exit are ignored by a marked, temporary list. Fixing the tests that cause them and deleting the list happen in the same change.
- The Windows export test needs export templates and runs only with `--release`.
