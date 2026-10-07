# Tilt Shift flow tuning

The selected `TiltShiftTuning.flow` profile is copied when preparation starts. Changes
apply to a later shift. Existing motion, physics and rules profiles retain their owners.

| Field | Default | Range | Effect |
| --- | --- | --- | --- |
| Intermission seconds | 3 | 0–10 seconds | Time after an exclusive round cutoff before the next mapped round. No scoring occurs during this pause. |
| Phone updates Hz | 15 | 1–30 updates/s | Ceiling for coalesced personalized angle snapshots. Launch, round changes and resume also send immediate state. |

The phone shows one canonical team paddle as a movement guide for every allocation.
Its rotation comes from the last accepted host angle; it never runs local physics.
The host's complete assignment list remains available for protocol checks and reconnect.

The default five-opening basket preset is unchanged. `ThreeOpenings.tres` provides
a second mirrored preset for mapping selected rounds or workshop comparisons.
Neither preset establishes strategic fairness without owner playtesting.

The normal catalog path requires an even roster and fresh calibrated motion from every
participant. The separately labeled F12 factory review uses ten synthetic players and
host-authored demo input. It grants no real one-player launch exception.

The browser flow tests write encoded downstream traffic and coordination callback costs
under ignored `test-results/tilt-shift/flow-*.json`. Cost excludes native physics, rendering
and sensor capture. Traffic excludes framing and physical network latency.
