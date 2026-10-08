# Tilt Shift flow tuning

The selected `TiltShiftTuning.flow` profile is copied when preparation starts. Changes
apply to a later shift. Existing motion, physics and rules profiles retain their owners.

| Field | Default | Range | Effect |
| --- | --- | --- | --- |
| Readiness seconds | 60 | 1–120 seconds | Deadline measured once from opening the selected-player panel, regardless of connectivity. |
| Countdown seconds | 3 | 0.1–10 seconds | Centered countdown before START; ball delivery and scoring remain stopped. |
| Start seconds | 0.6 | 0.1–2 seconds | Total centered START fade before the active round clock begins. |
| Intermission seconds | 3 | 0–10 seconds | Compatibility pause for older single-layout profiles; mapped rounds enter preparation immediately. |
| Phone updates Hz | 15 | 1–30 updates/s | Ceiling for coalesced personalized angle snapshots. Launch, round changes and resume also send immediate state. |

Selected phones show one canonical team paddle as a movement guide for every allocation.
Its rotation comes from the last accepted host angle; it never runs local physics.
The host's complete assignment list remains available for protocol checks and reconnect.

The default five-opening basket preset is unchanged. `ThreeOpenings.tres` provides
a second mirrored preset for mapping selected rounds or workshop comparisons.
Neither preset establishes strategic fairness without owner playtesting.

The normal catalog path first uses the shared Pre-minigame screen: every player enables tilt,
calibrates in landscape and confirms READY. It then freezes an even roster and prepares
the selected participants inside gameplay.

Round one opens the panel only with spectators; later rounds open it when the participant
set changes. Otherwise both panel and READY are skipped. The host accepts READY only
from selected players with fresh usable calibration and landscape orientation.
Recalibration or losing landscape eligibility clears READY while waiting.

All selected READY, local force start or the panel deadline starts countdown. Disconnects
never restart its clock or a countdown already running. Calibration is allowed before
active scoring and between rounds; reconnect preserves neutral.

In normal phone play, a first round without the panel waits for all selected phones to have
fresh calibrated input before starting its countdown. This initial wait has no deadline and
does not expose READY. Later rounds retain calibration. Synthetic factory/workshop callers
do not enable this phone-capture gate. Panel timeout and force behavior remain unchanged.

The separately labeled F12 factory review uses ten synthetic players and
host-authored demo input. It grants no real one-player launch exception.

The browser flow tests write encoded downstream traffic and coordination callback costs
under ignored `test-results/tilt-shift/flow-*.json`. Cost excludes native physics, rendering
and sensor capture. Traffic excludes framing and physical network latency.
