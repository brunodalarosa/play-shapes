# Tilt Shift host rules

Tilt Shift has a host-only rules foundation. Its physics, motion capture, editor workshop,
phone/shared presentation and lobby entry are not integrated yet.

## Ownership

`TiltShiftShiftController` owns the frozen shift roster, equal teams, rounds, scoring
windows, cumulative totals, paddle assignments and last accepted angles. Physics reports
registered ball catches; it never supplies a score or a team choice.

The controller uses typed contracts in `tilt_shift_state.gd`. Its `Player` input contains
the registry's stable player ID, name, seat, selected Squircle color and connected state.
The future transport boundary converts registry/wire records to these types.

`TiltShiftTuning`, `TiltShiftPaddleLayout` and `TiltShiftBasketPreset` are editable
Resources. [The field guide](tuning/README.md) describes their units and validation.
The controller freezes selected content with `duplicate_deep(DEEP_DUPLICATE_ALL)`
at launch. Ordinary duplication can retain externally saved Resources.

## Host calls

Assign `controller.tuning` from `SessionHost.active_presets.tilt_shift` before launch,
or inject a profile for a preview/test. The exported default makes the controller
independently usable. Calls take monotonic host milliseconds; phones never supply
identity, tokens, catch reports or host time directly.

| Call | Contract |
| --- | --- |
| `start_shift(players, time)` | Validate 2/4/6/8/10 unique identities and content, form random equal teams, reset totals and start round one. |
| `advance(time)` | Call once per host frame/arena step; close an active round at its deadline. |
| `start_next_round(time)` | Only between rounds, after clearing old ball nodes. No implicit settling period or intermission duration. |
| `register_ball(token, time)` | Register a host ball during scoring; return its typed `BallHandle`. |
| `resolve_ball(handle, basket_id, time)` | Resolve once for the basket's team or trash. Unknown baskets leave the ball unresolved. |
| `discard_ball(handle, time)` | Resolve cleanup without points. |
| `accept_angle(id, radians, token, time)` | Accept a finite host-validated angle for all the player's paddles. Complete turns stay unwrapped. |
| `set_connected(id, connected)` | Annotate presence; retain roster, identity, team, assignment and angle. |
| `snapshot(optional_id)` | Return independent typed copies; optional ID restricts the player list. |

Calls return a typed `Result`: `accepted`, rejection `reason`, actionable preset `errors`,
and a ball handle for registration. Rejected preparation does not create live state.
A running shift cannot replace its roster. A finished controller can start a new shift;
host time remains monotonic.

## Deadline and notifications

A catch at `time >= deadline_msec` is rejected even when its callback precedes `advance`.
Both use the same finish operation. Round end occurs once; the last round also emits
one shift end. Scores carry across rounds. Highest total wins; a tie has `is_draw = true`
and `winner = -1`.

Every shift generation/round has a new opaque token. Ball indices are local to it;
resolution status is a packed byte array cleared at round end. Old handles cannot score
later, even before physics deletes the old nodes. Memory grows with this round's
registrations; the later delivery system must enforce its ball budget.

`round_started`, `assignments_changed`, `score_changed`, `round_ended` and `shift_finished`
publish typed snapshots. `angle_changed` and `presence_changed` publish copied players.
State is committed before notification. Mutation calls during notification are rejected;
start the next round after the finishing call returns.

The future arena maps each paddle owner to that player's angle. Presentation plays the
whistle from `round_ended`. The controller has no frame loop of its own: its host consumer
supplies time through `advance` and event calls.

## Assignment diagnostics

The allocator balances five paddles per team and rotates extra-share quotas. It searches
all feasible mappings to minimize same-owner neighbor edges. Equal optima prefer changes
from the previous round; seeded tie breaking makes host tests repeatable. One teammate
retains five paddles; five teammates retain one each.

Snapshots contain the complete neighbor graph and both teams' `Allocation` reports:
paddle/owner IDs, counts, conflict pairs/distances and `minimum_conflicts`. Zero means
complete separation is feasible. A positive minimum proves an unavoidable conflict count
under those quotas, not a forced specific pair.

Graphs/assignments are computed at shift start or round boundaries. Intermediate sizes
have at most 1,024 raw mappings per team before pruning; one/five teammates bypass search.
Per-frame rule work is one deadline check. Ball status lookup is constant time; player
lookup visits at most ten entries.

This foundation introduces no HTTP/WebSocket messages or phone traffic. Snapshots are
host objects; later consumers select and serialize the wire fields they need.
