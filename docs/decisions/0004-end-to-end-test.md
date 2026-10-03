# 0004. The end-to-end test drives the real game

Decided by the project owners on 2026-10-03.

## Situation

The game is a host and several phones. No single-process test shows that a phone can join, play a round and return to the lobby.

## Decision

The end-to-end test runs the real host and the real phone client in emulated Chromium phones, with Playwright Test. A test-only host script starts the game through its own boot scene and clicks the host's buttons with injected mouse events, so the engine's hit testing applies.

The default run shortens only the round length, in memory. `--full` plays with every default.

A control route may be added to the game to let quick tests start a minigame or set a state directly. Those are tests that do not go through the whole flow; the end-to-end test keeps using what a person would use.

## What follows

- The host script depends on a few node names in the scenes. A rename breaks the test loudly.
- Only Chromium is covered. The test is automated evidence from a desktop browser and never stands in for a real phone.
