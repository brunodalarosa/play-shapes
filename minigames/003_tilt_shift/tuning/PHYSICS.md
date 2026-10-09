# Tilt Shift physics and delivery

The selected rules profile references `Physics.tres`. These values drive the same arena
scene for runtime and later workshop preview. Duplicate the profile for experiments,
select it through the rules Resource, and restart the shift to apply edits.

## Provisional values

All lengths use the paddle layout's coordinate unit: one default arena width.
One coordinate unit is 1,000 physics-world units; viewport size never changes gravity.

| Field | Default | Valid range | Effect |
| --- | --- | --- | --- |
| Ball count | 60 | 0–1,000 per round | Positive balls, independent of curve shape. |
| Negative ball count | 20 | 0–1,000 per round | Additional negative balls; zero disables them. |
| Delivery curve | `(0, 1), (1, 1)` | 2–64 linear points | Progress from zero to one; finite nonnegative relative intensity. |
| Negative delivery curve | Zero through 20%, peak at 70%, zero from 90% | 2–64 smooth points | Full-round progress; finite nonnegative relative intensity. |
| Use position seed / seed | Off / 1 | Boolean / integer | Repeat the position sequence when enabled. |
| Spawn half width | 0.40 | 0–0.49 widths | Centered entry interval; ball edges must clear both walls. |
| Spawn height | 0.03 | 0–0.5 widths | Empty gap above the whole ball, beyond the fitted visible viewport top. |
| Delivery cutoff | 6 | 0–300 seconds | Lead time before scoring closes; must leave room for the configured schedule. |
| Ball radius | 0.0138 | 0.003–0.02 widths | Shared circular collider and sprite radius for both ball types. |
| Paddle length | 0.10 | 0.02–0.20 widths | Longer gives more contact surface and a larger swept disk. |
| Paddle thickness | 0.01 | 0.006–0.03 widths | Physical rectangle and placeholder drawing. |
| Gravity | 0.18 | 0–2 widths/s² | Downward acceleration; does not override project gravity. |
| Entry speed | 0.05 | 0–1 widths/s | Initial velocity, independent of subsequent acceleration. |
| Rotation speed | 180 | 1–180 degrees/s | Maximum rate toward an unwrapped target, subject to the tip-step bound. |
| Ball / paddle friction | 0.2 / 0.4 | 0–1 each | Lower slides more; the larger contacting value wins. |
| Ball / paddle restitution | 0 / 0 | 0–1 each | Contact rebound includes both materials. |

Invalid saved/script values fail launch validation rather than becoming live physics.
Inspector ranges are input guidance; final density, contact and gravity choices need play.
Player dimensions above are legacy fallback fields. Mapped layouts override them:
A uses `0.20 × 0.016` widths and B `0.18 × 0.016`; neutral size is independent.
The shipped preset selects a six-second cutoff; older resources without that field retain zero.

## Delivery and position randomness

The curve is an editable array of `(normalized progress, intensity)` points with straight
segments. Integrate trapezoids and place each ball at a midpoint quantile of total weight.
Changing the shape preserves the configured count; zero-intensity spans receive no balls.
The schedule is available through `TiltShiftDelivery.schedule(count, points, duration_msec)`.

Negative balls have their own count and curve. Their progress spans the full round,
independently of the positive delivery cutoff. The initial points are `(0, 0)`, `(0.2, 0)`,
`(0.35, 0.15)`, `(0.7, 1)`, `(0.9, 0)`, `(1, 0)`. Smoothstep interpolation makes each join
smooth without overshoot; zero spans remain empty. Scheduling integrates this curve exactly
and uses midpoint quantiles, with `smooth = true` on the same delivery helper.

Both types share spawn bounds, gravity, contacts and position randomness. The combined
population and handle budget is the sum of both counts: 80 by default, at most 2,000.
The negative curve's final zero span suppresses overdue deliveries after a host hitch.
Already spawned negative balls can still be caught before the scoring deadline.

Positive curve progress spans `round_duration_seconds - delivery_cutoff_seconds`. Its budget
is integrated across that window; zero-intensity spans remain empty. Offsets use whole
host milliseconds and are strictly less than its end and the scoring deadline.
Reject positive counts with no positive curve weight, malformed points, or a positive
span too narrow to contain a representable pre-deadline delivery. Zero-count rounds
may use all-zero curves. The same profile applies to every round in a shift.

At ordinary physics ticks, due deliveries occur on the first tick in a positive span.
After a hitch, overdue deliveries wait through a zero span and can bunch together in the
next positive span. The positive delivery cutoff discards pending positive balls; there is no late catch-up
or guaranteed budget completion when the host stalls through the final positive span.

The position generator is independent of team allocation. A supplied seed restarts its
sequence at shift start and continues across rounds. An unseeded shift chooses a new seed,
exposed as `position_seed_used` for diagnostics. Physics, inputs and scores are not replay
deterministic; a seed promises only the ordered entry positions under unchanged content.

## Contacts, catches and cleanup

Balls use native rigid-body collision response, shape CCD, and body-local force integration.
Paddles are fixed-anchor animatable bodies synchronized to physics. Their visual and collider
share a transform. No Bubbles kinematics, pair solver or global gravity is reused.

Both contact materials use `rough = true`: their maximum friction applies. Restitution
adds the two non-absorbent material values, bounded by the engine. Zero paddle bounce
with nonzero ball bounce still rebounds. With both zero, paddle motion still transfers
momentum. Friction changes tangential sliding/rolling; it is not air damping.

The default five baskets cover the full floor, each one-fifth of its width. Every downward
center crossing resolves to a basket, including balls straddling a shared rim. The first
matching opening owns an exact shared boundary, and each ball resolves only once.

Custom gapped presets have solid floor segments and still require the full ball diameter
to fit an opening at the crossing. Floating-point seams within `0.00001` arena widths
do not create microscopic colliders or invalidate touching openings.

The host registers a ball's immutable scoring value before creating its physics body.
White balls award one point; dark blue balls remove one point from the catching team.
Totals saturate between zero and the signed 64-bit integer maximum, without overflow.
Negative sprites reuse the white-ball texture with a `#001a33` tint.
Trash, misses and out-of-bounds removal never score, and handles cannot resolve twice.

Deadline, next round, stop, restart and scene exit remove old balls. Their collisions are
disabled before deferred node deletion; rule tokens independently block obsolete catches.
Each mapped round rebuilds its frozen anchors, dimensions and floor during preparation.
The active clock, automatic rotation and delivery begin only after countdown/START.
Camera fitting supplies the visible top to the arena; walls extend beyond offscreen entry.

## Tested envelope and clearance diagnostics

The starting contact envelope uses the default dimensions, 60 Hz physics, rotation up to
180 degrees/s, and incoming ball speeds up to one width/s. Rotation limits tip travel to
half the selected ball radius per call; larger paddles/smaller balls may rotate more slowly
than the selected rate. There is no angle clamp or hidden full-turn stop.

`swept_clearances()` returns signed gaps from each full-turn disk to arena boundaries
and other full-turn disks. Negative gaps warn about overlapping swept extents; they do
not reposition presets or replace the allocator's neighbor graph. The default layout has
positive gaps. Changed dimensions/layouts need new runtime experiments before certification.

Native contacts permit transient solver penetration. Full-turn/reversal checks measure
its maximum and require less than half a default ball radius at the rotating contact.
Do not infer stability at arbitrary speeds, dimensions, overlapping drafts or tick rates
from shape CCD. One-width/s falling impacts and repeated turns are separate checks.

## Measurement limits

The cost helper runs 300 balls over 45 seconds with ten synthetic players rotating all
ten paddles. Delivery is concentrated between 40% and 60%, with linear ramps at 40–42%
and 58–60%; it uses position seed 827 and default geometry/materials. An empty three-second
arena supplies the baseline. The round budget is the upper bound, not expected population.

The report includes peak live balls, arena/control callback timings, and engine physics
monitor samples. Godot 4.7.2 refreshes the physics monitor with one-second maximum frame
times; its percentiles describe those interval peaks, not per-frame physics percentiles.
Script timings are per callback, after 20 warmups; monitor sampling starts after 1.2 seconds.

The helper identifies the CPU, engine and tick rate and checks finite state and cleanup.
Results are local headless measurements with synthetic input, not phone traffic, exported
performance, fairness or responsiveness evidence. Run it separately from other workloads;
[verification guidance](../../../docs/verification.md#focused-checks-by-area) names the command.
