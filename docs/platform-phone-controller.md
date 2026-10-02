# Reusable platform phone controls

`PlatformControls` mounts the actual NippleJS stick, action-button handlers and lifecycle behavior. `PlatformInputState` owns axes, sector hysteresis, action ownership and intent snapshots. `LobbyControls` is a mounting wrapper over `createLobbyContext`, which maps intent to Playground messages. Another 2D platform context supplies `{ activeClass, send(intent) }` to the same component, plus its own screen/stick/button elements. Transport adds sequence and current-connection ownership; the controls never supply identity, grounding or platform eligibility.

The portrait layout, lower-left stick, lower-right toy button and locally bundled NippleJS remain unchanged. The stick has no axis locks. Near-down changes the text to **FALL** and accessible name to **Fall**; other input shows **JUMP**/**Jump**. Changing the stick while holding the button changes the eventual release attempt. Only the host can change game state.

## Axes and tuning

The convention is **X positive right, Y positive up**, matching NippleJS's `vector`. Godot's screen-coordinate Y points down; host physics must not use this intent as free vertical velocity. Vertical input selects a stance/action; X retains horizontal analog movement. Each axis is finite and in `[-1, 1]`, with vector magnitude at most one. Clamp components, then normalize vectors longer than one. Active analog magnitude is preserved rather than rescaled outside the dead zone.

Edit `DEFAULT_PLATFORM_SETTINGS` in `web/src/platform_input.ts`, then rebuild. Constructors accept settings overrides for another context. Invalid ranges throw before mounting. Build generates `web/public/platform_input_settings.json` from the same defaults, with `version: 1` and `axisConvention: "x-right-y-up"`. The host handoff can read that bundled JSON instead of duplicating tuning. It is a generated artifact, not an independent tuning source. The HTTP allowlist and export policy include it and the two shared modules.

| Setting | Default | Meaning |
| --- | --- | --- |
| `deadZone` | 0.16 | Return to neutral at or below this magnitude. |
| `deadZoneHysteresis` | 0.04 | From neutral, require magnitude at least 0.20 to activate. |
| `verticalEnterDegrees` | 20 | Enter up/down within this angle of vertical. |
| `verticalExitDegrees` | 28 | Retain the same up/down sector until outside this angle. |
| `moveIntervalMsec` | 45 | Minimum spacing between movement-event sends while held. |
| `refreshIntervalMsec` | 100 | Refresh both held axes without new touch motion. |

Classification applies these comparisons in order:

1. Clamp and normalize the finite vector. Nonfinite device samples cannot replace held state.
2. If magnitude is at most `deadZone`, output `(0, 0, neutral)`. Also output neutral when the previous classification was neutral and magnitude is below `deadZone + deadZoneHysteresis`.
3. Candidate stance is `look_up` for positive Y, `crouch` for negative Y. Compute `atan2(abs(X), abs(Y))` in degrees.
4. Use the exit angle when the previous classification was that same candidate; otherwise use the entry angle. At or inside the angle select the candidate; outside it select `move`.

The exit angle must stay below 45 degrees, so ordinary diagonals stay `move`. Neutral, look-up and move select JUMP; crouch selects FALL. Fresh 24-degree downward input is `move`/JUMP; moving from 19 to 24 degrees retains `crouch`/FALL until passing 28 degrees. Magnitude 0.18 stays active after entry but stays neutral when approached from rest.

## Intent, ordering and lifecycle

```ts
type PlatformSnapshot = {
  axes: { x: number; y: number };
  stance: "neutral" | "move" | "look_up" | "crouch";
};
type PlatformIntent =
  | { kind: "move"; input: PlatformSnapshot }
  | { kind: "release"; action: "jump" | "fall"; input: PlatformSnapshot };
```

Every device movement updates local axes and the button mode immediately, including movements suppressed by the network throttle. A matching action release sends exactly one synchronous `release` with a copy of the **current** snapshot and displayed action. It does not first send a separate movement or depend on the last movement packet. Repeated/foreign releases do nothing. Snapshots remain independent of later input.

Movement-event sends are spaced by 45 ms with a separate 100 ms refresh: about 23 event sends plus ten refreshes per held second. First movement, neutralization and deliberate action releases send immediately. There is no backlog of intermediate moves. Adapters must gate transport on the active connection/context and keep queues bounded.

Action cancellation releases ownership/capture without an action; the independent stick can stay held. Stick release/cancellation resets both axes, stance and mode and sends neutral. A still-held action then releases JUMP with that neutral snapshot. Blur, backgrounding, pagehide, viewport/orientation/fullscreen changes and deactivation cancel all touches/keys, restore neutral/JUMP and destroy the old joystick. Focus/visibility recovery recreates it. Socket loss/resume, leaving, READY, Bubbles and Motion Lab use the app's existing deactivation/reactivation paths. `setContext()` neutralizes through the old adapter first; `destroy()` also removes listeners and refresh timers.

Space and Enter are owned from keydown to keyup, suppress duplicate browser clicks and ignore repeats. Losing focus cancels the key. Native assistive click uses the same current snapshot; pointer-generated clicks cannot cause a second action.

## Playground migration and host handoff

The app adds monotonically increasing `input_seq`. Its adapter sends:

```json
{"type":"lobby_move","horizontal":0.6,"vertical":0.3,"stance":"move","input_seq":10}
{"type":"lobby_jump_release","action":"jump","horizontal":0.6,"vertical":0.3,"stance":"move","input_seq":11}
{"type":"lobby_fall_release","action":"fall","horizontal":0.1,"vertical":-0.8,"stance":"crouch","input_seq":12}
```

**Current host:** all three routes use the complete contract. `PlatformInput` reconstructs the phone hint using shared generated tuning. `LobbyPlaygroundWorld` applies the release snapshot before asking `PlatformMotor` to jump/fall. `WebsocketService` resolves only the registered connection's player and gates lobby input during readiness, Bubbles and other active protocols. Invalid data does not consume sequence; a valid but physically ineligible release consumes sequence without queuing an action or returning a jump fallback. Success remains silent on the socket.

Both axes are required, finite, within `[-1,1]` and inside the unit disk (roundoff tolerance `0.000001` on squared magnitude). Sequence is an increasing positive safe integer. Neutral requires zero axes; known active hints must reconstruct through the shared classifier. FALL requires crouch and matching `action: "fall"`; JUMP requires a non-crouch hint and matching `action: "jump"`. Stance is only a hysteresis hint: the host independently decides grounding/presentation. Client-supplied identity/support/grounding fields have no authority. Incomplete horizontal-only packets are rejected; the bundled PS-081 controller supplies the complete snapshot.

## Host components and platform setup

- `components/platform_input.gd`: shared classifier and bounded snapshot/action validation. Loads `web/public/platform_input_settings.json` once. Tune sectors/dead zones in `DEFAULT_PLATFORM_SETTINGS`, rebuild, and restart the host. Do not tune host thresholds separately or edit generated JSON. The isolated harness exposes the same thresholds for temporary browser review.
- `components/platform_surface.gd`: attach to each `StaticBody2D` support. Keep authored `CollisionShape2D` geometry and one-way settings. Choose **Drop Rule: Open/Closed** in the Inspector. Closed affects deliberate FALL only; it does not become solid from below. Playground `BottomShelf` is Closed and all ten raised shelves/block tops are Open. Select `PlatformSurfaces/<name>` to change just that rule.
- `components/platform_motor.gd`: child of any `CharacterBody2D` with ordinary collision shapes. The parent owns geometry/layers; the motor owns physics, axes, input expiry, jump eligibility, bounce, grounded stances, per-body drop exclusions and cleanup. Set its physics priority before a separate physics presentation adapter. Read `presentation_action()` for idle/walk/run/look_up/crouch. Horizontal movement, gravity, travel-facing and the full upright collider remain unchanged.

A context adapter validates with `PlatformInput.validate(message, action)`, supplies connection/sequence/context gates, calls `motor.set_input(snapshot.axes, snapshot.stance, host_receipt_msec)`, then calls `request_jump()` or `request_fall()` once. Call `set_enabled(false)` on disconnect and `clear_input()` on context exit/resume. Connect `fall_reset_requested` to that context's spawn positioning. Tree exit also cleans the component. There is no registry, nameplate, art, networking or singleton dependency. `tests/fixtures/platform_reuse.tscn` demonstrates two generic capsule bodies and Open/Open/Closed supports with these exact components, independently of lobby reconciliation. Open it for inspection; tests drive physics without copying a controller.

FALL resolves current slide contacts, rejects ambiguous/unknown/character support, and excludes only that supporting Open body via the requesting character's collision exception. It never changes a shared collider or collision mask. Floor snap is suspended while this exception exists. Full-body vertical clearance, horizontal edge clearance, another lower contact or timeout restores the previous snap and removes the exception. Close stacked surfaces catch the body even before full-body clearance. A FALL latch requires leaving crouch before another accepted drop, so repeated releases cannot silently descend multiple floors. Airborne/Closed/repeated attempts are discarded.

| Motor setting (Inspector) | Default | Purpose |
| --- | --- | --- |
| `input_timeout_msec` | 350 | Expire axes, stance, queued jump and transient drop after lost refresh. |
| `drop_timeout_seconds` | 0.65 | Maximum support exclusion, even without clearance. |
| `drop_clearance` | 4 px | Extra full-body clearance below support bounds. |
| `drop_speed` | 80 px/s | Initial downward speed; lower platforms remain collidable. |

Normal movement/jump/gravity/bounce values now live on `LobbySquircle/PlatformMotor`; visual scale stays on `LobbySquircle`. A short timeout can stop a slow drop early. A longer timeout still excludes only one support. Disconnect/resume, expiry, component/scene exit and respawn clear transient contact and intent. Support `tree_exiting` restores contact before its physics RID is freed. Cached floor contacts cannot authorize an action immediately after lifecycle reset; the next physics step refreshes them.

A custom platform context uses the same intent shape with its own explicit transport adapter. Its host configuration and browser constructor must share settings rather than tune independently.

## Harness and verification

From `web/`, run `node scripts/serve_platform_harness.mjs` and open `http://127.0.0.1:18181`. The loopback fixture mounts the real component with `createPreviewContext`, recording intent without a lobby socket or future minigame. **Switch adapter** uses the Playground mapping on the same component. **Reactivate controls** checks reset; **Input tuning** applies validated overrides and resets touches. Fixtures stay under `web/tests/fixtures/`, excluded from exported builds, with no diagnostic copy added to production gameplay.

Run `npm install`, `npm run check`, `npm run build`, and `npm test`. `platform_input.test.mjs` covers analog axes, radial/angular hysteresis, held-action mode changes, cancellation, keys and generated settings. `platform_controls.test.mjs` exercises compiled handlers with only NippleJS rendering replaced: capture failures, independent touches, unsent input at release, lifecycle resets, throttling, reactivation, adapter changes and cleanup. `host.test.mjs` checks registered, sequenced two-axis/release routes; `ready_flow.test.mjs` rejects all lobby routes during readiness and FALL during Bubbles. Godot `platform_input_test.gd`, `platform_drop_reuse_test.gd`, and `platform_lobby_boundary_test.gd` cover host validation, per-player physics and the real Playground adapter. Onboarding, Bubbles, motion, readiness and HTTPS tests remain in the suite.

Record desktop-browser evidence separately from simulated handlers and physical phones. Phone review still needs simultaneous stick/action touches, vertical-sector jitter, diagonals, direction changes during action release, cancellation, background/rotation and disconnect/resume. The host integration has automated physics/protocol and live Compatibility capture evidence in [PS-082](ps-082-platform-stances.md). A desktop viewport cannot establish touch latency or ergonomics.
