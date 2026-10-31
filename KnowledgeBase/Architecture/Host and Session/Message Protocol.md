---
tags: [architecture]
level: system
parent: "[[Play Shapes Overview]]"
status: draft
code: [Tuning/Shared/Networking/Default.tres, ControllerNetworkConfig, web/src/network_config.ts, NetworkingTuning, web/public/platform_input_settings.json, PlatformInput, PlatformSurface, PlatformMotor]
verified:
branch:
---

# Protocol

What phones and the host say to each other: the HTTP routes, the WebSocket messages, and the
limits the host enforces. Which script owns each part is in
[[Codebase|architecture.md]].

## Host authority

The host owns session state, player identity, round timing, score, results and receipt time.
Phones send UI actions and controller input only.

- A client-supplied player ID has no authority. The host derives the player from the
  connection.
- The browser never sends host time, client timestamps or pointer positions. Input to a
  character the phone predicts carries a simulation tick instead
  ([[0048-predicted-input-carries-a-tick|0048]]), never wall-clock time.
- Registered socket identity and the lobby or active-protocol gates decide what a message may
  do.

## Motion subscriptions

The host selects one lab player or a roster of at most ten gameplay players. Each receives
`motion_lab` or `motion_subscribe`, with `subscription_id`, `send_hz` and `stale_msec`.
Subscription identity is opaque, per player and replaced on reconnect; a phone-authored
player ID is rejected. The raw sample/status schema is shared with the lab.

- `motion_sample`: current subscription, increasing integer `sequence`, and nullable raw
  orientation, angular velocity, acceleration, screen angle, event ages/rates and interval.
  Unknown/missing sample fields and non-finite/out-of-bound values are rejected.
- `motion_status`: current subscription, capture/network diagnostics and transmission rate.
  At most five accepted status messages/s; the browser normally sends about four/s.
- `motion_calibrate`: `type` and current `subscription_id`. At most five requests/s.
  Mapped Tilt Shift 3D rounds additionally require current `generation` and `round_token`.
  The host chooses its latest usable orientation; active calibration is rejected.
- `motion_control_state`: host feedback with current subscription and `control_state`,
  containing `calibrated`, `usable` and `capture_state`. Calibration replies also contain
  `accepted` and `reason`. Feedback contains no client-selected physical angle or identity.
- `motion_stop`: retiring `subscription_id`. The phone stops only its matching capture.

Samples are accepted no faster than every 34 ms; the raw transport stale threshold is
1000 ms. Latest-only burst handling and browser backpressure avoid catch-up replay.
Capture failure states and Tilt Shift 3D's shorter continuity gap are documented in
[[005 Motion Control|motion-input.md]].

## Defaults

From `Tuning/Shared/Networking/Default.tres`:

- HTTP `8080`; WebSocket `8081`.
- 32 transport connections per service.
- At most 10 registered players per session. The designer setting may be lower.
- Five-second request and handshake timeout.
- 60-second reconnect grace.

Each WebSocket connection takes host messages of up to 64 KiB, such as a Flappy Race snapshot
with its whole course, and phone messages of up to 16 KiB.

## Endpoints and session discovery

`ControllerNetworkConfig` is the endpoint source for both services, the lobby QR and
`/session.json`.

- It pairs HTTP with WS, or HTTPS with WSS.
- It separates the bind interface from the advertised hostname or IP.
- It keeps certificate paths private.
- `GET /session.json` returns the protocol, the session ID, the HTTP and WS schemes, and the
  WebSocket port.
- `web/src/network_config.ts` validates that pair against the page protocol and uses the page
  hostname. Mixed-content combinations fail.
- Ports default from the active `NetworkingTuning` Resource.
- Joining is always at `/`. There is no room system and no mDNS.

Local overrides and HTTPS are in [[Networking#Local network configuration|networking.md]].

## HTTP routes

The host serves a fixed list and nothing else:

- Pages and styles: `/`, `/style.css`, `/session.json`.
- The phone client: `/app.js`, one script that holds every module except the 3D view, and
  `/three_view.js`, which `/app.js` loads only when a 3D screen starts
  ([[Browser Build|browser-build.md]]).
- Generated settings: `/platform_input_settings.json`.
- App manifest and icons: `/manifest.webmanifest`, `/app-icon-180.png`, `/app-icon-192.png`,
  `/app-icon-512.png`.
- 3D models for the phone: `/models/cubio.glb` and `/models/jellyfish.glb`, and where
  Cubio's shape face sits on its model, `/models/cubio-face-anchor.json`.
- Shape character faces: `/shape_faces/face_presets.json` and one
  `/shape_faces/facial_part_<name>.png` per part the manifest lists, from the shared runtime
  folder.

Responses:

- Unknown routes return 404. Non-GET methods return 405.
- Headers beyond 8192 bytes are rejected with 431, or with a TCP reset when unread bytes remain
  on Windows.
- A response closes after its final bytes have had time to flush, so larger PNGs load
  completely.

## Joining and identity

Protocol 1 begins with `hello` and `welcome`. It then supports join, resume, leave, and
personalized lobby and gameplay state.

- Before join, the phone shows Cubio color selection, then name entry.
- `join` submits `name`, `character_shape: "cubio"` and `character_color` together.
- The host accepts missing and legacy body-shape values as Cubio, rejects unknown
  body-shape values, and validates the ten approved player colors.
- A join with no style uses Cubio and the `#598DF2` blue fallback. A valid color without a
  shape keeps that color.
- The registry stores Cubio. Lobby rosters, gameplay snapshots and resume state carry it
  forward.

The registry keeps four identities apart:

- the transport `connection_id`;
- the host-owned, session-scoped `player_id`;
- the host-owned `session_id`;
- an opaque reconnect token held by the browser.

The browser stores only the session ID, the token, the last-used name and the monotonically
increasing gameplay sequence it needs to resume safely.

## When joining and resuming are allowed

- New joins are lobby-only, with one exception: a final submission from an onboarding socket
  that was already open before Start.
- Valid resumes remain available during ready-up and gameplay.
- A phone reload creates a new transport connection but may resume the same player during
  grace.
- A duplicate resume with an active token gives the newest tab ownership and closes the old
  connection.

## Character appearance

- The lobby, Bubbles and jellyfishes 3D, setup and the Ready screen use the same exported
  3D Cubio. Joins send `character_shape: "cubio"`, the only accepted body.
- The player tint colors the body, hands and feet. The neutral and blink faces stay
  untinted.
- The host and phone render the same rig and preserve the original face artwork.

## Ready-up

During ready-up, a registered phone sends `{"type":"pre_minigame_ready","ready":true|false}`.

- The host derives the player ID from the connection.
- It replies with a personalized `pre_minigame_snapshot` holding that player's ready value and
  the ordered roster.
- New phone handshakes cannot begin onboarding in this phase. Onboarding sockets that were
  already open may finish joining, and registered phones may resume.
- Disconnect and resume clear the ready state.
- Host cancel restores the lobby state on connected phones.

## Lobby platform input

After join, the portrait Playground mounts the reusable `PlatformControls` and
`PlatformInputState` through `createLobbyContext`. The shared intent, tuning, lifecycle,
adapter harness and host handoff are in
[[Platform Controller|platform-phone-controller.md]].

- The NippleJS stick is unlocked: X is right-positive and Y is up-positive, with unit-disk
  analog axes, a radial dead zone with hysteresis, and narrow up and down sectors.
- Near-down selects FALL. Other directions select JUMP.
- Release sends one explicit attempt with the latest two-axis snapshot, including locally
  observed changes that the movement throttle suppressed.
- `lobby_move`, `lobby_jump_release` and `lobby_fall_release` carry `horizontal`, `vertical`,
  `stance` and an increasing `input_seq`. Releases also carry `action`.
- The build generates `web/public/platform_input_settings.json` from the browser defaults.

What the host checks:

- Complete finite unit-disk axes, consistent stance hints, a matching release action, and a
  safe increasing sequence.
- `PlatformInput` reads the generated browser settings and reconstructs the radial and angular
  hysteresis, so coalesced snapshots remain valid.
- Release axes apply atomically before host eligibility.
- Both axes, stances, queued jumps and temporary exclusions expire after 350 ms without
  refresh.
- No client player ID, grounding or platform choice is used.

## Falling through a surface

- FALL requires grounded contact with exactly one Open `PlatformSurface`, never another
  character or Closed ground.
- `PlatformMotor` excludes only that support, for that body. It suspends the body's floor snap
  and keeps every other collider active.
- Contact is restored after clearance, a lower landing, an edge exit, or a 0.65-second
  timeout.
- Repeated FALL while held down is rejected, even after landing. Leave the down sector before
  another deliberate descent.
- Rejected attempts never become queued drops or jumps.
- Disconnect or resume, despawn, component or scene exit, input expiry and fall reset clear
  transient contact and intent.
