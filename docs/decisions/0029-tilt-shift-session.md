# Persistent Tilt Shift session

Tilt Shift preparation acquires calibration before the shared screen changes into the
factory scene. The same consumer must survive that transition and keep its neutral
through gameplay reconnect, while cancel and later game selection retire it completely.

## Decision

An ordinary `TiltShiftSession` child of the existing SessionHost coordinates that
lifecycle. The shared readiness owner accepts an optional per-player predicate;
the session supplies fresh calibrated-motion eligibility for Tilt Shift only.
The factory, rules controller and motion consumer retain their current state ownership.

Load the session only when Tilt Shift preparation starts. Catalog listing and unrelated
games need none of its factory dependencies. Loading those dependencies during shared
startup also retains additional character/shader resources through headless shutdown.
The shared transport accepts the adapter through its existing `RefCounted` protocol
boundary, so its startup does not load Tilt Shift's typed state dependencies either.

## Consequences

The gameplay wrapper attaches the prepared consumer instead of starting new capture.
The workshop still instantiates the factory without host services. Another sensor game
can reuse readiness predicates without taking Tilt Shift's rules or lifecycle code.

Keeping preparation in the gameplay scene would lose it on scene replacement. Putting
all coordination into SessionHost would grow a shared service with game-specific rules.
No new autoload or general event bus is needed.
