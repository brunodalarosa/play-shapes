---
area: Minigames
tags: [system, stub]
code: []
verified:
branch:
---

# 005 Messages

Hub: [[005 Tilt Shift]].

The messages of minigame 005. The shared rules are in the message protocol.

Every normal Tilt Shift 3D launch uses the shared all-player Pre-minigame gate before freezing
an even roster and opening the factory. Its round controller owns subsequent selected-player
readiness. Sensor status and samples use the authenticated motion subscriptions. On the
Pre-minigame screen, the readiness snapshot's `preparation` adds the player's `color`, the
`face` to show and the paddle's `look`, with `paddle_size` taken from the first round's layout.

`tilt_shift_3d_snapshot` carries generation, increasing sequence, phase, round, team,
owned paddle IDs and physical paddle length and thickness (`paddle_size` in arena widths, also
for spectators, whose phones show their paddle resting under the waiting background), plus:

- `color`: the player's Cubio colour as six hex digits.
- `face`: the face preset the phone shows, the strongest across the player's paddles.
  IDs start with `face_` followed by lowercase words separated by underscores, at most 64
  characters in total. Original single-letter IDs remain valid.
- `look`: the corner, depth, gap, outline and face ratios, the gap colour, the orange, blue
  and neutral outline colours and the wall's two colours.
- `angle_radians`: the physical angle of the player's first paddle, which trails the accepted
  angle under the turning limit; zero for spectators.

Mapped snapshots also carry `round_token`, `selected`, `ready`, `ready_available`,
`calibration_available`, `calibrated`, `usable` and `landscape`. Phases include `preparing`,
`countdown`, `start`, `active`, `between_rounds` and `finished`. No client-authored angle,
team, assignment or score message is accepted. Obsolete snapshot generations or sequences
cannot replace the current phone view.

`tilt_shift_3d_ready` carries `type`, current `generation`, `round_token` and Boolean `ready`.
The connection supplies identity. Only selected players in a visible ready panel can change
readiness. Fresh usable calibration and landscape are required; recalibration, disconnection,
portrait or stale capture clears READY. A stale or invalid READY is dropped without an error,
and the sender gets its current snapshot back. Countdown start is final even if a player then
disconnects. The panel timeout runs once from opening; force start is a local host action, not
a message.

Angle updates and face changes coalesce to the latest state at the selected flow ceiling, 15 Hz
by default. Queued socket output skips that update rather than accumulating a backlog. Round
and resume transitions send current state immediately. Calibration is available before and
between active rounds, including countdown and START; it is locked during scoring. Reconnect
preserves neutral and does not recover unseen complete turns.

`landscape` is derived from the authenticated motion sample's `screen_angle`: either
quarter-turn display orientation qualifies. It is included in Tilt Shift 3D preparation,
control feedback and gameplay snapshots. It does not change capture `usable` or paddle angles.
