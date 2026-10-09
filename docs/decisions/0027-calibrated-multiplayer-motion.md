# Calibrated multiplayer motion uses physical gravity phase

## Context

Tilt Shift requires ten independent calibrated sideways phone controls and repeated full
turns. The motion lab's single subscription and a limited raw Euler axis cannot deliver
those outcomes. The host must retain authority over identity, tuning and paddle angles.

## Decision

Keep one bounded latest-sample channel per registered identity inside WebsocketService.
The lab keeps its stable single-channel wrapper. One host-selected capture consumer owns
the session; replacing it retires every old channel. Browser capture/transmission is shared
between lab and gameplay, with subscription-scoped feedback and stop messages.

Compute the in-plane gravity phase from physical orientation, ignoring UI screen angle.
Calibrate per player, accumulate nearest phase changes and apply frozen host gain. Keep
the accumulator unlimited; bounded comparison clamps output without moving neutral.

After a gap, retain neutral and choose the nearest equivalent angle on the old branch.
Never integrate assumed gyro motion or infer unseen full turns. Degenerate projections,
missing orientation and ambiguous half turns hold the prior angle and expose unusability.

## Consequences

The next readiness consumer can gate READY using usable capture and host calibration;
it supplies the player-facing permission/calibration actions. No new autoload, HTTP route
or general gesture framework is needed. The lab remains an independent compatible consumer.

Gravity phase supports repeated turns in the screen plane without Euler wrap snaps. Its
physical comfort, off-axis tolerance and browser sensor accuracy still require real phones.
A face-horizontal pose is explicitly unusable, and fewer than 180 degrees between usable
samples is the necessary unwrapping assumption. The existing paddle physics limiter remains.
