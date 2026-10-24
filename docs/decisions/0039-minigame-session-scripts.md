# 0039. A minigame that prepares its players names a session script in the catalog

Chosen on 2026-10-18 for minigame 005.

## Situation

Tilt Shift prepares its players on the Pre-minigame screen: motion permission, landscape and a
neutral calibration gate READY and the launch. SessionHost does this for Tilt Shift through a
branch written for it. Tilt Shift 3D needs the same preparation, and later motion games may too.

## Decision

`MinigameDefinition.session_script` names a Node script. SessionHost creates that session on
first use and calls `prepare`, `ready_for`, `preparation_for`, `launch_eligible`,
`sync_players` and `stop` during the Pre-minigame screen and around play. The session registers
its `MinigameProtocol` when the game attaches.

Tilt Shift keeps its existing branch until it is retired.

## What follows

- A minigame with preparation adds a session script and a catalog field, not a host branch.
- Listing the catalog loads no minigame script; the session loads when its game is chosen.
- Retiring Tilt Shift removes its branch; nothing else in the host changes.
