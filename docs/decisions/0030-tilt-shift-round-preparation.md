# 0030. Tilt Shift prepares selected players inside each round

Decided by the project owner on 2026-10-07.

## Situation

Alternating layouts need different participant counts and fair exposure history. A shared
all-player ready gate cannot express spectators, a per-round timeout, or skipped readiness.
Keeping preparation in a screen would give runtime and workshop preview different rules.
This replaces the shared-gate requirement for mapped profiles in decision 0029.

## Decision

The existing Tilt Shift round controller owns participant selection, READY, panel deadline,
countdown and START. The session routes authenticated actions and owns capture lifetime.
The factory and workshop render the same controller phases. The local host can force start;
phones cannot. Skipping the participant panel also skips READY. The panel clock starts on
opening, regardless of connectivity, and never restarts after a disconnect.

Decision [0031](0031-tilt-shift-initial-calibration.md) adds an initial calibration wait
when normal phone sessions skip the first participant panel.

Fair selection prefers an unplayed layout, then fewer rounds, with random ties. Layout
Resources carry stable exposure identities and their own dimensions. History belongs to
the playthrough, so editing Resources never stores runtime ownership or participation.

## What follows

- No new autoload, protocol route or second preview state machine is needed.
- Calibration can change between active rounds; active scoring locks it. Reconnect preserves
  neutral. Timeout and force start deliberately permit missing input and hold its last angle.
- The browser carries generation and round context for READY and calibration actions.
- Older profiles with no layout map retain their single-layout flow. The workshop imports
  them into explicit round maps when edited for the new journey.
