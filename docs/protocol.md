# Protocol

What phones and the host say to each other: the HTTP routes, the WebSocket messages, and the
limits the host enforces. Which script owns each part is in
[architecture.md](architecture.md).

## Host authority

The host owns session state, player identity, round timing, score, results and receipt time.
Phones send UI actions and controller input only.

- A client-supplied player ID has no authority. The host derives the player from the
  connection.
- The browser never sends host time, client timestamps or pointer positions.
- Registered socket identity and the lobby or active-protocol gates decide what a message may
  do.

## Defaults

From `Tuning/Shared/Networking/Default.tres`:

- HTTP `8080`; WebSocket `8081`.
- 32 transport connections per service.
- At most 10 registered players per session. The designer setting may be lower.
- Five-second request and handshake timeout.
- 60-second reconnect grace.

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

Local overrides and HTTPS are in [networking.md](networking.md#local-network-configuration).

## HTTP routes

The host serves a fixed list and nothing else:

- Pages and styles: `/`, `/style.css`, `/session.json`.
- Modules: `/app.js`, `/pwa.js`, `/lobby_controls.js`, `/lobby_input.js`,
  `/platform_controls.js`, `/platform_input.js`, `/immersive.js`,
  `/character_selection.js`, `/squircle_v1.js`, `/vendor/nipplejs.mjs`. A minigame's modules
  are under its folder: `/002_bubbles_and_jellyfishes/bubbles_gesture.js`.
- Generated settings: `/platform_input_settings.json`.
- App manifest and icons: `/manifest.webmanifest`, `/app-icon-180.png`, `/app-icon-192.png`,
  `/app-icon-512.png`.
- Character sheets: `/squircle-v1/manifest.json`, `/squircle-v1/idle-front-colorable.png`,
  `/squircle-v1/idle-front-neutral.png`, `/squircle-v1/idle-front-blink.png`.
- Bubbles art: `/bubbles-jellyfish.png`, `/bubbles-phone-background.png`.

Responses:

- Unknown routes return 404. Non-GET methods return 405.
- Headers beyond 8192 bytes are rejected with 431, or with a TCP reset when unread bytes remain
  on Windows.
- A response closes after its final bytes have had time to flush, so larger PNGs load
  completely.

## Joining and identity

Protocol 1 begins with `hello` and `welcome`. It then supports join, resume, leave, and
personalized lobby and gameplay state.

- Before join, the phone shows Squircle color selection, then name entry.
- `join` submits `name`, `character_shape: "squircle"` and `character_color` together.
- The host accepts missing and legacy body-shape values as Squircle, rejects unknown
  body-shape values, and validates the ten approved player colors.
- A join with no style uses Squircle and the `#598DF2` blue fallback. A valid color without a
  shape keeps that color.
- The registry stores Squircle. Lobby rosters, Bubbles snapshots and resume state carry it
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

- The lobby uses the Squircle v1 movement clips. Setup and Bubbles use its front idle clip.
- The Squircle v1 tint colors its body, hands and feet. The neutral and blink faces stay
  untinted.
- The colorable layer uses the same tint treatment on host and phone.

## Ready-up

During ready-up, a registered phone sends `{"type":"pre_minigame_ready","ready":true|false}`.

- The host derives the player ID from the connection.
- It replies with a personalized `pre_minigame_snapshot` holding that player's ready value and
  the ordered roster.
- New phone handshakes cannot begin onboarding in this phase. Onboarding sockets that were
  already open may finish joining, and registered phones may resume.
- Disconnect and resume clear the ready state.
- Host cancel restores the lobby state on connected phones.

## Bubbles input

While a touch is held, the browser may send `bubbles_charge` with `input_seq` and `stage`:

- `start`, `progress` and `cancel` carry an integer `step` from 0 to 4.
- `motion` carries a two-axis quantized `drag` vector of integers from -4 to 4.
- The browser throttles motion to 70 ms, sends a 600 ms heartbeat while held, and caps a
  gesture at 48 motion packets.

On touch release, the browser sends one `bubbles_trace` with the same gesture sequence. It
holds at most 128 normalized points, under an 8192-byte packet ceiling.

The host side:

- For the current authenticated touch sequence, the host accepts four coarse charge steps plus
  up to 48 quantized drag updates, spaced at least 60 ms apart.
- Charge and drag drive only transient shared-screen deformation and glow. They reset after
  1.2 seconds without updates.
- The host records touch start. Live drag stretch settles once `swipe_max_hold_seconds`
  passes, and a late swipe applies no impulse.
- Completed spins use the gesture classifier and its cooldown.
- The host replies to a trace with `bubbles_trace_result` and a `bubbles_snapshot`.
  `bubbles_feedback` carries collection, spin and pop cues.
- Disconnect clears an unfinished trace. Resume requires a new gesture.
- Reconnect embeds the latest personalized snapshot in `welcome.gameplay`.

## Lobby platform input

After join, the portrait Playground mounts the reusable `PlatformControls` and
`PlatformInputState` through `createLobbyContext`. The shared intent, tuning, lifecycle,
adapter harness and host handoff are in
[platform-phone-controller.md](platform-phone-controller.md).

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
