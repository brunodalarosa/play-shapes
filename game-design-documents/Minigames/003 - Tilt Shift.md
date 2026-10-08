# Tilt Shift

Tilt Shift is minigame 003: two equal teams guide falling balls through a toy factory
by holding phones sideways like balancing beams. One playthrough is a multi-round shift.

## Preparation and control

The starting roster is exactly 2, 4, 6, 8 or 10 players. The host selects participants
for each round. A participant panel appears in round one when some players sit out,
and in later rounds when the participant set changes. It shows names, player-colored
Shape Characters and readiness grouped by team. Only selected players use READY.
If the panel is skipped, READY is skipped too.

Phones enable motion and choose a comfortable neutral before or between rounds.
Fresh usable calibration is required for READY; recalibration clears READY.
The local host can force the round, and a 60-second panel timeout starts it regardless
of connectivity. Disconnects never restart this timer. A centered 3, 2, 1 countdown
and short START fade precede the full active scoring window and ball delivery.

Calibration is locked during active play. Reconnect keeps the same neutral,
team and assignments. Missing input holds the last accepted angle without pausing,
transferring ownership or inventing turns made during a connection gap.

## Factory shift

The host randomly forms equal Orange and Blue teams, fixed for the shift. There are
two Orange, two Blue and one grey automatic paddle in layout A, and three per team
in layout B. The default four rounds alternate A, B, A, B. Anchors and team colors
stay fixed within each layout; dimensions are independently tunable. The neutral
paddle starts at zero and rotates continuously only during active play, reversing
direction at its next appearance in the same shift.

Selection favors players who have not played that layout, then those with fewer total
rounds, with random ties. In a ten-player shift, round two selects the six spectators
from round one. Everyone plays twice, and one player per team plays only B.
Smaller rosters control several paddles together; larger shares rotate fairly and
same-owner neighbors are minimized. Spectators keep their team and idle character.

Balls collide with one another and with the host's rotating paddles. A team basket
adds one point to its team, regardless of who touched the ball. Trash discards it.
Every ball resolves at most once. Basket presets pair team openings by reflection.

The round deadline stops scoring immediately and clears unresolved balls before the
next round. Team totals accumulate; the highest shift total wins, and equal totals draw.
Balls enter wholly above the fitted visible viewport. Delivery ends before the scoring
deadline while preserving the configured budget and empty curve intervals.
Results stay on the host until Return to lobby. Audio is currently deferred.

## Tuning and review

Selected Resources control duration, mapped basket presets, ball count and delivery
curve, motion gain, continuous or bounded input, physical materials and preparation.
The workshop's Tunables tab edits the same Resources used by preview and runtime.
See the [field guide](../../minigames/003_tilt_shift/tuning/README.md).

Real phones and owner playtests determine comfort, responsiveness, full-turn tracking,
readability, strategic fairness and final tuning. Synthetic inputs and runtime captures
do not provide those approvals.
