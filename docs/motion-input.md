# Motion input

How the phone's gyroscope and accelerometer readings reach the host, the units they use, and
the F12 lab that displays them. No motion stream runs in normal gameplay; only the lab starts
one. Phone browsers expose these sensors only over HTTPS; see [local-https.md](local-https.md).

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

`host/motion_input_channel.gd` owns a host-selected subscription to one player ID.

- Each connection and lifecycle gets a fresh opaque subscription ID.
- Samples must be strict, finite and bounded, with increasing sequences.
- The receive limit is 30 Hz. Data is stale after 1000 ms.
- `WebsocketService.begin_motion` and `end_motion` route status and the latest samples
  through authenticated registry connections and existing sockets. A client-authored player
  ID is never accepted.

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
