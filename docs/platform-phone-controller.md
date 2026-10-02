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

**Current host:** `lobby_move` uses horizontal X; `lobby_jump_release` uses the existing grounded jump rule. Added vertical/stance/release-axis fields are ignored. `lobby_fall_release` is rejected as `unsupported_message`, displayed by the existing development error panel. It causes no drop and no jump fallback. Host stance validation, animations, release-axis application and drop physics remain a separate implementation. Use the isolated harness to review FALL before host integration.

The host integration must:

- Resolve identity from the registered socket and gate the active platform context. Validate finite bounded unit-disk axes, positive safe-integer increasing sequence, known stance/action and matching release type/action. Preserve stale/duplicate rejection and connection replacement.
- Load the shared settings and implement the ordered classifier above. Reported stance is a **controller hysteresis hint**, not host game state. Validate it against the vector: neutral requires zero axes; active hints require magnitude above the dead zone; look-up/crouch require the correct Y sign and angle inside the exit sector. Seed classification with the valid hint and require its reconstructed result to match. This preserves phone selection when intermediate samples were coalesced, including releases in the angular/radial hysteresis band. Decide actual grounded stance independently on the host.
- Apply release axes, stance hint and action atomically at that sequence **before** evaluating eligibility. Do not choose an action from cached older axes, turn FALL into JUMP or queue a rejected attempt for a later landing. Fall requires a consistent crouch hint; jump requires a non-crouch hint.
- Expire both axes and stance using host receipt time; the existing horizontal lease is 350 ms. Clear input and temporary collision exclusions on disconnect/resume, removal, respawn and context exit. Keep gravity and grounding authoritative.
- Add grounded look-up/crouch presentation and per-player Open/Closed drop rules through shared host components. These are pending and not claimed by the browser checks.

A custom platform context uses the same intent shape with its own explicit transport adapter. Its host configuration and browser constructor must share settings rather than tune independently.

## Harness and verification

From `web/`, run `node scripts/serve_platform_harness.mjs` and open `http://127.0.0.1:18181`. The loopback fixture mounts the real component with `createPreviewContext`, recording intent without a lobby socket or future minigame. **Switch adapter** uses the Playground mapping on the same component. **Reactivate controls** checks reset; **Input tuning** applies validated overrides and resets touches. Fixtures stay under `web/tests/fixtures/`, excluded from exported builds, with no diagnostic copy added to production gameplay.

Run `npm install`, `npm run check`, `npm run build`, and `npm test`. `platform_input.test.mjs` covers analog axes, radial/angular hysteresis, held-action mode changes, cancellation, keys and generated settings. `platform_controls.test.mjs` exercises compiled handlers with only NippleJS rendering replaced: capture failures, independent touches, unsent input at release, lifecycle resets, throttling, reactivation, adapter changes and cleanup. `host.test.mjs` serves the assets and checks legacy compatibility plus the unsupported fall route. Onboarding, Bubbles, motion, readiness and HTTPS tests remain in the suite.

Record desktop-browser evidence separately from simulated handlers and physical phones. Phone review still needs simultaneous stick/action touches, vertical-sector jitter, diagonals, direction changes during action release, cancellation, background/rotation and disconnect/resume. Host stance/drop end-to-end review follows the separate integration. A desktop viewport cannot establish touch latency or ergonomics.
