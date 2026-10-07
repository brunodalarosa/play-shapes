# Tilt Shift host rules, physics and presentation

Tilt Shift has host rules, calibrated motion, an editor workshop and a reusable factory
presentation around the playable physics arena. Phone presentation and lobby entry
are not integrated yet.

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

The arena maps each paddle owner to that player's angle. Presentation exposes one
`round_feedback` signal for later sound integration. The controller has no frame loop: its consumer
supplies time through `advance` and event calls.

## Shared gameplay and preview arena

Instantiate `tilt_shift_arena.tscn`, then call `start_shift(selected_tuning, players)`.
The arena owns its ordinary rules-controller child, ball bodies, paddle bodies, walls,
floor and delivery cursor. Its `controller` exposes the same authenticated host control
seam for future motion consumers. `start_next_round()` is available only between rounds.

The arena samples its injectable monotonic `clock` on each physics tick. Catch resolution
and ball registration use that same time. A stopped deadline clears all balls immediately;
the caller decides when to begin the next round. `stop()` clears bodies and scores by
retiring the controller. Removing the arena frees its complete scene subtree.

Rules snapshots include independent copies of the frozen physics profile. Live Inspector
edits cannot replace its dimensions, curve, materials or seed. The same paddle bodies and
anchors survive round changes; the selected floor openings and owner targets change.

`paddle_bodies()` exposes each stable ID, unwrapped target and confirmed `applied_angle`.
The actual collider and placeholder drawing share one transform. Sync-to-physics can keep
the previous confirmed pose for a tick; presentation must use the actual pose, not the
requested target. The angular-rate bound delays large target jumps without dropping turns.

The workshop can instantiate this arena with copied content and synthetic host controls.
It must call `stop()` before restart/exit; it needs no separate physics implementation.
`ball_spawned` and `ball_removed` expose host observations; neither awards points itself.
The [physics guide](tuning/PHYSICS.md) describes delivery, contacts and supported limits.

## Factory presentation

Instantiate `tilt_shift_presentation.tscn` as a full-size Control, then call
`start_shift(selected_tuning, players)`. It owns an ordinary `TiltShiftArena` in an
isolated SubViewport. The workshop gameplay preview uses this same scene. Future
readiness/catalog consumers can attach calibrated motion to its exposed `arena`.

Paddle artwork is a child of each physical body and fits its RectangleShape2D exactly.
End caps keep their aspect; the beam center stretches to match the selected length and
thickness. Camera zoom fits the view without scaling the physical subtree. Basket mouth
centers/widths match scoring openings; balls draw between the rear and front layers.

The five default mouths meet across the full stage, with no solid floor gaps. Their
front panels extend to the viewport's lower edge; top/bottom trim keeps its proportions.
Custom gapped presets retain visible neutral floor beams. Side rails add no colliders.

One station per participant faces into the arena and retains body/hand/foot colors.
Stations have no text labels. Team scores use colored numbers without team names.
Signed accepted-angle changes advance the authored `lever_pull` loop; missing or rejected
input holds the operating frame. Natural blinks continue during a hold. The station never
supplies physical angles. Paddle badges identify the current owner's seat, independent
of their selected character color.

Host notifications update cumulative scores, assignments, baskets and final win/draw.
The timer reads the host deadline. Each round end clears catch flashes and shows an
immediate cutoff cue once; `round_feedback(snapshot)` is available for future SFX.
No audio is bundled by this presentation. The caller chooses `start_next_round()`;
`stop()` disconnects retired controller notifications and clears all temporary visuals.

`tuning/Presentation.tres` controls side width, station/character size, basket art scale,
badge size, turns per animation loop, catch flash duration and HUD font size. Distances
use arena world units; the default arena width is 1,000. Presentation settings are copied
at launch and never change gameplay dimensions, scoring or phone message traffic.
The runtime art manifest contains geometry only and is included in export presets.

See [focused checks and capture helpers](../../docs/verification.md#focused-checks-by-area).
Capture checks establish local rendering; couch-distance readability, density, motion
feel and physical-phone responsiveness remain owner reviews.

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

Rules snapshots are host objects; presentation consumers select and serialize the wire
fields they need. Calibrated control reuses the shared motion transport described in
[motion-input.md](../../docs/motion-input.md#tilt-shift-control).

## Calibrated phone control

Create an ordinary `TiltShiftMotionController` node and call `prepare(service, ids, motion)`
before readiness. After explicit per-player calibration, `ready_for(id)` exposes the host
gate. Start the arena, then `activate(arena)` verifies that same calibrated roster.
The caller still owns readiness and launch; neither is added to the lobby by this consumer.

The node consumes latest samples, maps the physical sideways gesture to unwrapped angles
and calls the existing rules seam. Neutral stays fixed throughout the shift. Arena stop,
exit, shift completion and replacement subscriptions retire the consumer. `stop()` also
cancels preparation. A later game gets fresh capture/calibration state.
