# Motion input

How the phone's gyroscope and accelerometer readings reach the host, the units they use, and
the F12 lab that displays them, and Tilt Shift's calibrated control consumer.
Capture runs only for a host-selected consumer. Phone browsers expose these sensors only
over HTTPS; see [local-https.md](local-https.md).

## On the phone

`web/src/motion_input.ts` wraps:

- capability detection;
- both gesture-triggered permission requests;
- nullable raw motion and orientation fields;
- per-event freshness, counts and frequency;
- explicit start, stop, suspend and resume.

It reports what it actually knows:

- An unknown permission, on a browser without `requestPermission`, stays unknown.
- No events and partial data remain observable.
- Reconnect does not presume that permission persisted.

## On the host

`host/motion_input_channel.gd` owns one host-selected player subscription.
`WebsocketService` holds at most ten independent channels, keyed by authenticated identity.

- Each connection and lifecycle gets a fresh opaque subscription ID.
- Samples must be strict, finite and bounded, with increasing sequences.
- The receive interval is at least 34 ms, below the 30 Hz ceiling. Data is stale after 1000 ms.
- `WebsocketService.begin_motion` and `end_motion` route status and the latest samples
  through authenticated registry connections and existing sockets. A client-authored player
  ID is never accepted.
- `begin_multiplayer_motion(ids)` replaces the capture session with a bounded roster.
  Reconnect rotates only that player's subscription. Ending a session clears every channel.
- Incoming sample bursts retain the newest sample before applying the receive limit.
  Status and calibration actions preserve their order relative to samples.

`web/src/motion_stream.ts` owns bounded transmission and session-scoped listeners. Its
`requestPermission()` must be invoked directly by a user gesture. `requestCalibration()`
asks the host to use its latest usable sample; no phone-authored neutral or angle is sent.
The lab wraps this same stream with its existing developer panel.

Gameplay capture skips sends whenever WebSocket bytes are queued. The lab retains its
8192-byte backpressure threshold. A resumed timer samples current data without catch-up.
Feedback and stop messages match their subscription generation.

## Tilt Shift control

`TiltShiftMotionController.prepare(service, ids, profile)` starts capture and fresh
per-player calibration state. `player_state(id)` exposes `capture_state`, `usable` and
`calibrated`; `ready_for(id)` requires both usable capture and completed calibration.
The readiness screen and its permission/calibration buttons are separate integration work.

After the actual arena starts, `activate(arena)` verifies its roster. Older single-layout
profiles require every player to be ready before attachment. Mapped profiles allow capture
and calibration inside round preparation. The consumer preserves neutral through the shift,
including intermissions, unless the player deliberately recalibrates before active scoring.
It sends host-owned unwrapped angles through the rules controller; all assigned paddles
receive the same target. The existing physical limiter determines their confirmed poses.

Control uses the direction of world up projected into the physical screen plane. Clockwise
rotation as seen by the holder maps to clockwise 2D rotation. Yaw and display autorotation
alone do not change the phase. Repeated sampled turns accumulate without a rotation stop.
See [the tuning guide](../minigames/003_tilt_shift/tuning/MOTION.md).

Complete, fresh orientation is required. Unknown permission may be proven usable by samples;
denied, unavailable, unsupported, insecure, missing and partial orientation remain distinct.
Live acceleration cannot make stale orientation usable. A nearly face-horizontal phone has
an unusable gravity projection: hold the last angle rather than inventing an axis.

Reconnect preserves the original neutral and accumulated branch. The next usable phase
chooses the nearest equivalent angle; it cannot recover unseen full turns. More than 250 ms
between usable samples marks a resumed path. Exactly ambiguous half-turn changes are held.
Reliable unwrapping requires less than 180 degrees between usable samples; real-device
accuracy and comfortable off-axis motion remain pending human trials.

`stop()`, arena stop/exit, shift completion or a replacement capture consumer releases
channels, listeners and calibration. A later preparation starts fresh. The consumer emits
state-change feedback at most five times/s, plus calibration replies limited to five/s;
a new subscription receives fresh feedback. No per-frame angle snapshots are added.

## Tilt Shift preparation lifecycle

The normal catalog flow uses TiltShiftSession to keep the same motion consumer across
the preparation-to-factory scene transition. Final joins from existing onboarding sockets
receive new isolated channels without resetting earlier players. Expired preparation
participants lose their channels. READY is revoked when capture becomes stale or unusable.

Mapped-round resume clears readiness and keeps neutral and ownership. Calibration is
allowed before/between active rounds and clears READY. Active play locks calibration.

When the first round skips the participant panel and READY, the normal phone session waits
in preparation until every selected player is connected with fresh calibrated input. This
initial calibration wait has no timeout; permission and CALIBRATE remain available until
the complete countdown starts. Later rounds reuse calibration and retain their panel rules.

Older shared-gate preparation retains its original neutral-reset policy.
Host cancel, scene startup failure, results, debug replacement and return to the lobby retire
the prepared consumer. The F12 factory review is explicitly simulated and creates no motion
subscriptions. See [flow tuning](../minigames/003_tilt_shift/tuning/FLOW.md).

## Units and axes

- Orientation angles are W3C intrinsic Z-X'-Y'' degrees.
- `rotationRate` is in degrees per second. Acceleration is in m/s².
- `MotionOrientation` maps the W3C Z-up reference to Godot's Y-up, and supplies
  screen-compensated or physical portrait-phone bases.
- Physical slab rendering undoes the UI's screen-axis compensation, so autorotation alone
  cannot rotate the hardware representation.

What the readings do not give:

- Missing orientation is never fabricated.
- Relative yaw is not a guaranteed compass.
- Accelerometer readings do not determine position.
- Recentering and smoothing belong to the consumer, such as the lab, not to the raw samples.

## The F12 motion lab

Choose **Gyroscope and Accelerometer Lab** from F12, before or after joining.

- It pins the connected registry seat 1, never the connection order. The host displays the
  pinned identity.
- If that identity expires, **Bind current Player 1** explicitly selects its replacement.
  Another phone never silently takes over.
- Only that phone receives a developer panel, with **Request Motion Permission**, raw values
  and capability diagnostics.
- **Return to lobby** restores the ordinary controls. Restart or exit stops capture and clears
  old subscriptions.
- Reconnect rotates the subscription and shows the permission action again.

`debug/motion_lab/motion_lab.tscn` owns:

- an isolated 3D `SubViewport` with a marked toy phone;
- **Recenter pose** and **Reset calibration**;
- optional quaternion smoothing, **Smoothing (seconds)**, 0 by default;
- three reusable signed-axis history plots of 120 samples;
- the host receipt rate, the phone transmission rate and the sensor event rate.

How it treats data:

- When angles are unavailable, it holds the last pose with a label. Stale data is never
  presented as live.
- Plot ranges are exported: acceleration 20 m/s², rotation 180 degrees per second. They clamp
  drawing only; raw data stays unchanged.
- Phone status heartbeats recover transitions that the bounded host channel coalesced.
- Under network backpressure, samples are skipped rather than queued late.

## Checking it on a real phone

Automated tests and desktop captures cannot show sensor accuracy, delay or phone lifecycle
behavior. With HTTPS enabled and trusted on the phone, launch the host, join the first phone,
open the lab, and tap **Request Motion Permission** on that phone. Then check:

- The QR code opens the exact controller. HTTPS shows no warning, the session metadata selects
  WSS, and no mixed-content failure occurs.
- Granting permission works from the button. Check the supported, denied, error and no-events
  states, both API permissions if exposed, and nullable readings. Ordinary non-motion controls
  must still work after denial.
- Orientation alpha, beta and gamma (degrees), angular velocity (degrees per second),
  acceleration and acceleration including gravity (m/s²) look right. Compare flat, upright,
  face-down, left and right tilt, and yaw with the host slab. Recenter, and rotate between
  portrait and landscape.
- Sample age, sensor event frequency, and the transmitted and received rates are plausible.
  Judge delay and noise before tuning smoothing.
- A second phone's movements cannot update Player 1's display.
- After Player 1 disconnects, reloads or reconnects, stale data is labeled, the identity stays
  pinned, and fresh events recover.
- Lock and unlock, switch Chrome away and back, return from a background tab, restart the lab,
  and return to the lobby. There must be no frozen-live values, stuck controls or lingering
  streams.
- With Internet off and Wi-Fi on, joining, permission, motion and reconnect still work.
- Normal lobby, READY, CANCEL and Bubbles work before and after the lab on both phones. Check
  the desktop no-sensor fallback separately.

Record each result with the browser and device versions. The tests for this area are listed
in [verification.md](verification.md#focused-checks-by-area).
