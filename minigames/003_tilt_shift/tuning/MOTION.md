# Tilt Shift motion tuning

The selected `TiltShiftTuning.motion` profile controls calibrated phone tilt. Its values
are copied at preparation; changes apply to a later control session.

## Starting values

| Field | Default | Units / valid range | Effect |
| --- | --- | --- | --- |
| Gain | 1 | Paddle degrees per phone degree, 0.05–8 | Higher amplifies tilt; physical rate limits may add lag. |
| Continuous | True | Boolean | Keeps sampled full turns and reversals without a rotation stop. |
| Maximum degrees | 60 | Degrees either side of neutral, 1–180 | Clamps bounded comparison output only. |
| Minimum projection | 0.2 | Unit gravity projection, 0.01–0.95 | Higher rejects more face-horizontal/off-axis poses. |
| Continuity gap | 250 | Milliseconds, 34–1000 | Longer intervals are marked resumed, not observed continuous paths. |

No extra smoothing is applied. These are provisional trial values, not owner feel approval.
The arena's [physical limits](PHYSICS.md) still constrain how fast colliders can follow
targets. High gain does not bypass those limits or certify faster contacts.

## Gesture and calibration

Hold the phone sideways, with its screen facing comfortably toward the holder, like a
balancing beam. Explicit calibration chooses the current fresh orientation as neutral.
Raising one end and lowering the other rotates all assigned paddles together. The phase
measures gravity in physical screen axes; screen autorotation never changes neutral.

The gravity projection must exceed the selected threshold. At 0.2, its geometric boundary
is approximately 11.54 degrees away from a face-horizontal screen. This is a mathematical
guard, not a measured device comfort envelope. A flat phone cannot establish neutral.

Continuous mode accumulates nearest signed changes through wraps and repeated turns.
In bounded mode the accumulator remains unwrapped, while output clamps at the selected
maximum. Rotating far beyond a limit requires returning inside that neutral-relative range
before the output leaves its stop; there is no moving neutral or saturation recentering.

## Interruptions

Missing, stale or unusable orientation holds the accepted angle. On reconnect, keep neutral
and choose the nearest equivalent phase on the old accumulated branch. A shortest-path
correction can occur, but unseen complete turns are never recovered. No active recalibration
is permitted, including between rounds. Leaving the shift discards calibration.

At exactly 180 degrees the direction is ambiguous, so hold and report it. Full-turn accuracy
requires less than 180 degrees between usable samples. A continuity flag reports gaps;
it does not add artificial turns or change the neutral.

## Measurement boundaries

`tilt_shift_motion_cost_check.gd` measures ten distinct synthetic streams with 17 ms virtual
frames and 34 ms sample intervals. It uses actual controller and paddle target application,
with 120 warmup and 1200 measured frames. Socket parsing, native physics, rendering and
physical sensors are excluded. Output is ignored `test-results/tilt-shift/motion/cost.json`.

The browser stream test measures encoded JSON traffic for ten synthetic phones over 20.4
virtual seconds after warmup. It includes periodic status and excludes framing, network
delay, physical sensors and host feedback. Output is ignored
`test-results/tilt-shift/motion/traffic.json`; it is not a physical network benchmark.
