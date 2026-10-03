# Platform phone controller

The phone's joystick and action button for 2D platform movement, and the host parts that
turn their input into movement. It covers the input tuning, the intent the phone sends, the
host components, and how another minigame reuses them. The Playground lobby is the first
user.

## The parts

On the phone:

- `PlatformControls` mounts the NippleJS stick, the action-button handlers and the lifecycle
  behavior.
- `PlatformInputState` owns the axes, the sector hysteresis, action ownership and the intent
  snapshots.
- `LobbyControls` is a mounting wrapper over `createLobbyContext`, which maps intent to the
  Playground messages.
- Another 2D platform context supplies `{ activeClass, send(intent) }` to the same component,
  plus its own screen, stick and button elements.

The transport adds the sequence and the ownership of the current connection. The controls
never supply identity, grounding or platform eligibility. Only the host can change game
state.

## What the player sees

- A portrait layout with a lower-left stick and a lower-right toy button. NippleJS is bundled
  locally.
- The stick has no axis locks.
- Near-down changes the button text to **FALL** and its accessible name to **Fall**. Other
  input shows **JUMP** and **Jump**.
- Changing the stick while holding the button changes the action that will be attempted on
  release.

## Axes

- The convention is **X positive right, Y positive up**, matching NippleJS's `vector`.
- Godot's screen-coordinate Y points down. Host physics must not use this intent as free
  vertical velocity.
- Vertical input selects a stance and an action. X keeps horizontal analog movement.
- Each axis is finite and in `[-1, 1]`, with a vector magnitude of at most one. Clamp the
  components, then normalize vectors longer than one.
- Active analog magnitude is preserved, not rescaled outside the dead zone.

## Tuning the input

Edit `DEFAULT_PLATFORM_SETTINGS` in `web/src/platform_input.ts`, rebuild, and restart the
host.

- Constructors accept settings overrides for another context. Invalid ranges throw before
  mounting.
- The build generates `web/public/platform_input_settings.json` from the same defaults, with
  `version: 1` and `axisConvention: "x-right-y-up"`.
- The host reads that bundled JSON instead of holding its own copy of the tuning. It is a
  generated file, not a second place to tune. Do not edit it, and do not tune host thresholds
  separately.
- The HTTP allowlist and the export policy include it and the two shared modules.

| Setting | Default | Meaning |
| --- | --- | --- |
| `deadZone` | 0.16 | Return to neutral at or below this magnitude. |
| `deadZoneHysteresis` | 0.04 | From neutral, require magnitude at least 0.20 to activate. |
| `verticalEnterDegrees` | 20 | Enter up/down within this angle of vertical. |
| `verticalExitDegrees` | 28 | Retain the same up/down sector until outside this angle. |
| `moveIntervalMsec` | 45 | Minimum spacing between movement-event sends while held. |
| `refreshIntervalMsec` | 100 | Refresh both held axes without new touch motion. |

## How input is classified

The comparisons apply in this order:

1. Clamp and normalize the finite vector. Nonfinite device samples cannot replace held state.
2. If the magnitude is at most `deadZone`, output `(0, 0, neutral)`. Also output neutral when
   the previous classification was neutral and the magnitude is below
   `deadZone + deadZoneHysteresis`.
3. The candidate stance is `look_up` for positive Y and `crouch` for negative Y. Compute
   `atan2(abs(X), abs(Y))` in degrees.
4. Use the exit angle when the previous classification was that same candidate; otherwise use
   the entry angle. At or inside the angle, select the candidate; outside it, select `move`.

What follows from it:

- The exit angle must stay below 45 degrees, so ordinary diagonals stay `move`.
- Neutral, look-up and move select JUMP. Crouch selects FALL.
- Fresh 24-degree downward input is `move` and JUMP. Moving from 19 to 24 degrees keeps
  `crouch` and FALL until passing 28 degrees.
- A magnitude of 0.18 stays active after entry, but stays neutral when approached from rest.

## The intent

```ts
type PlatformSnapshot = {
  axes: { x: number; y: number };
  stance: "neutral" | "move" | "look_up" | "crouch";
};
type PlatformIntent =
  | { kind: "move"; input: PlatformSnapshot }
  | { kind: "release"; action: "jump" | "fall"; input: PlatformSnapshot };
```

- Every device movement updates the local axes and the button mode at once, including
  movements the network throttle suppresses.
- A matching action release sends exactly one synchronous `release`, with a copy of the
  **current** snapshot and the displayed action. It does not first send a separate movement,
  and does not depend on the last movement packet.
- Repeated releases, and releases from another pointer, do nothing.
- A snapshot stays independent of later input.

## How often it sends

- Movement-event sends are spaced by 45 ms, with a separate 100 ms refresh: about 23 event
  sends plus ten refreshes per held second.
- First movement, neutralization and deliberate action releases send immediately.
- There is no backlog of intermediate moves.
- Adapters must gate transport on the active connection and context, and keep queues bounded.

## Cancellation and lifecycle

- Cancelling the action releases ownership and capture without an action. The independent
  stick can stay held.
- Releasing or cancelling the stick resets both axes, the stance and the mode, and sends
  neutral. An action that is still held then releases JUMP with that neutral snapshot.
- Blur, backgrounding, `pagehide`, viewport, orientation and fullscreen changes, and
  deactivation cancel all touches and keys, restore neutral and JUMP, and destroy the old
  joystick. Focus or visibility recovery recreates it.
- Socket loss and resume, leaving, READY, Bubbles and the motion lab use the app's existing
  deactivation and reactivation paths.
- `setContext()` neutralizes through the old adapter first. `destroy()` also removes
  listeners and refresh timers.

Keyboard and assistive input:

- Space and Enter are owned from keydown to keyup, suppress duplicate browser clicks, and
  ignore repeats. Losing focus cancels the key.
- A native assistive click uses the same current snapshot. Pointer-generated clicks cannot
  cause a second action.

## The lobby messages

The app adds a monotonically increasing `input_seq`. Its adapter sends:

```json
{"type":"lobby_move","horizontal":0.6,"vertical":0.3,"stance":"move","input_seq":10}
{"type":"lobby_jump_release","action":"jump","horizontal":0.6,"vertical":0.3,"stance":"move","input_seq":11}
{"type":"lobby_fall_release","action":"fall","horizontal":0.1,"vertical":-0.8,"stance":"crouch","input_seq":12}
```

How the host handles them:

- `PlatformInput` reconstructs the phone's stance hint using the shared generated tuning.
- `LobbyPlaygroundWorld` applies the release snapshot before asking `PlatformMotor` to jump or
  fall.
- `WebsocketService` resolves only the registered connection's player, and gates lobby input
  during readiness, Bubbles and other active protocols.
- Invalid data does not consume the sequence.
- A valid release that is physically ineligible consumes the sequence without queuing an
  action or falling back to a jump.
- Success is silent on the socket.

What makes a message valid:

- Both axes are required, finite, within `[-1,1]` and inside the unit disk, with a roundoff
  tolerance of `0.000001` on the squared magnitude.
- The sequence is an increasing positive safe integer.
- Neutral requires zero axes. Known active hints must reconstruct through the shared
  classifier.
- FALL requires crouch and a matching `action: "fall"`. JUMP requires a non-crouch hint and a
  matching `action: "jump"`.
- Incomplete horizontal-only packets are rejected.

The stance is only a hysteresis hint. The host decides grounding and presentation by itself,
and client-supplied identity, support or grounding fields have no authority.

## Host components and platform setup

- `components/platform_input.gd` is the shared classifier, with bounded snapshot and action
  validation. It loads `web/public/platform_input_settings.json` once.
- `components/platform_surface.gd` attaches to each `StaticBody2D` support.
  - Keep the authored `CollisionShape2D` geometry and the one-way settings.
  - Choose **Drop Rule: Open/Closed** in the Inspector. Closed affects deliberate FALL only;
    it does not make the surface solid from below.
  - In the Playground, `BottomShelf` is Closed and all ten raised shelves and block tops are
    Open. Select `PlatformSurfaces/<name>` to change just that rule.
- `components/platform_motor.gd` is a child of any `CharacterBody2D` with ordinary collision
  shapes.
  - The parent owns the geometry and layers. The motor owns physics, axes, input expiry, jump
    eligibility, bounce, grounded stances, per-body drop exclusions and cleanup.
  - Set its physics priority before a separate physics presentation adapter.
  - Read `presentation_action()` for idle, walk, run, look_up or crouch.

## Using the motor from a context

A context adapter does this:

1. Validates with `PlatformInput.validate(message, action)`.
2. Supplies the connection, sequence and context gates.
3. Calls `motor.set_input(snapshot.axes, snapshot.stance, host_receipt_msec)`.
4. Calls `request_jump()` or `request_fall()` once.

It also:

- calls `set_enabled(false)` on disconnect, and `clear_input()` on context exit or resume;
- connects `fall_reset_requested` to that context's spawn positioning.

Tree exit cleans the component too. The motor has no registry, nameplate, art, networking or
singleton dependency.

`tests/fixtures/platform_reuse.tscn` shows two generic capsule bodies and Open, Open and
Closed supports using these exact components, with no lobby controller or registry. Open it to
inspect; the tests drive its physics without copying a controller.

A custom platform context uses the same intent shape with its own explicit transport adapter.
Its host configuration and its browser constructor must share settings, not tune separately.

## Falling through a surface

- FALL resolves the current slide contacts, and rejects ambiguous, unknown or character
  support.
- It excludes only the supporting Open body, through a collision exception on the requesting
  character. It never changes a shared collider or a collision mask.
- Floor snap is suspended while the exception exists.
- Full-body vertical clearance, horizontal edge clearance, another lower contact or the
  timeout restores the previous snap and removes the exception.
- Closely stacked surfaces catch the body even before full-body clearance.
- A FALL latch requires leaving crouch before another accepted drop, so repeated releases
  cannot silently descend several floors.
- Airborne, Closed and repeated attempts are discarded.

| Motor setting (Inspector) | Default | Purpose |
| --- | --- | --- |
| `input_timeout_msec` | 350 | Expire axes, stance, queued jump and transient drop after lost refresh. |
| `drop_timeout_seconds` | 0.65 | Maximum support exclusion, even without clearance. |
| `drop_clearance` | 4 px | Extra full-body clearance below support bounds. |
| `drop_speed` | 80 px/s | Initial downward speed; lower platforms remain collidable. |

- The movement, jump, gravity and bounce values live on `LobbySquircle/PlatformMotor`. The
  visual scale stays on `LobbySquircle`.
- A short timeout can stop a slow drop early. A longer timeout still excludes only one
  support.
- Disconnect or resume, expiry, component or scene exit and respawn clear transient contact
  and intent.
- A support's `tree_exiting` restores contact before its physics RID is freed.
- Cached floor contacts cannot authorize an action right after a lifecycle reset. The next
  physics step refreshes them.

## Harness and tests

From `web/`, run `node scripts/serve_platform_harness.mjs` and open
`http://127.0.0.1:18181`.

- The loopback fixture mounts the real component with `createPreviewContext`, recording
  intent without a lobby socket or another minigame.
- **Switch adapter** uses the Playground mapping on the same component.
- **Reactivate controls** checks the reset.
- **Input tuning** applies validated overrides and resets touches.
- Fixtures stay under `web/tests/fixtures/` and are excluded from exported builds. No
  diagnostic copy is added to production gameplay.

Browser tests, run by `npm test` in `web/`:

- `platform_input.test.mjs`: analog axes, radial and angular hysteresis, held-action mode
  changes, cancellation, keys and generated settings.
- `platform_controls.test.mjs`: the compiled handlers, with only NippleJS rendering replaced.
  It covers capture failures, independent touches, unsent input at release, lifecycle resets,
  throttling, reactivation, adapter changes and cleanup.
- `host.test.mjs`: registered, sequenced two-axis and release routes.
- `ready_flow.test.mjs`: every lobby route is rejected during readiness, and FALL during
  Bubbles.

Godot tests:

- `platform_input_test.gd`: host validation.
- `platform_drop_reuse_test.gd`: per-player physics on the reuse fixture.
- `platform_lobby_boundary_test.gd`: the real Playground adapter.

A desktop viewport cannot show touch latency or ergonomics. What still needs a real phone is
in [pending-reviews.md](pending-reviews.md).
