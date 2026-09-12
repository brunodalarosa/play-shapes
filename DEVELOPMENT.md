# Play Shapes development

## Planning and task context

The canonical planning layer is Markdown under `Project/`, `Drafts/`, `Roadmap/`,
`Tasks/`, and `Decisions/`. Future agents should begin with
[Project Overview](Project/Project%20Overview.md), then read
[Task Index](Task%20Index.md), the selected task, and its linked decisions
before proposing or implementing work. The interactive Obsidian view is
[Task board](Task%20board.md); its manual-index fallback requires no plugin.

Implementation work must happen in a separate execution session from planning.
An implementation task is not ready until its scope, acceptance criteria,
dependencies, and draft execution prompt reflect approved design decisions.

## Phase 1 — LAN hello world (2026-09-09)

Implemented: boot starts HTTP and WebSocket services, then opens the lobby
playground with a join QR code. A browser on the same LAN loads the bundled
Hello world page and completes a versioned WebSocket handshake with Godot.
No player names, characters, controller inputs, persistence, or minigames yet.

Physical-phone scanning and cross-device network access are the remaining
acceptance check. Desktop Chrome successfully loaded the Wi-Fi address and
displayed the connected state. Do not equate this with a physical-phone test.

## Project location and running

The Git repository and Godot root are this `play-shapes/` directory, nested
inside the parent notes vault. Keep `project.godot` here. The parent contains
`AGENTS.md`, `Development phase 1.md`, `Main.md`, `Stack.md`, and
`Lobby playground.md`; read those before expanding scope. Their instruction
that the parent is the Godot root does not match the existing filesystem.

Open `project.godot` in Godot 4.7.2 and press F6 for an individual scene only
when appropriate; use **F5** for the complete boot flow. Or from this directory:

```powershell
godot --path .
```

Select the host's Wi-Fi/Ethernet IPv4 address in the lobby. Phones must use
the same reachable LAN. Scan the QR or type its displayed URL. The current
address is detected each launch; it is not stored in source. Refresh rescans
adapters and preserves the current choice when possible. Common `192.168.*`
addresses are preferred, but this is a heuristic, not default-route detection.
VPNs, multiple interfaces, and guest Wi-Fi can require manual selection.
Loopback, link-local, and IPv6 addresses are excluded. No address means no QR.

The browser connection count is diagnostic, **not** a player count. Reloading
creates a new host-assigned connection ID; there is no player identity yet.

## Code map

- `scenes/boot.*`: starts services, displays a startup error and Retry on failure.
- `host/session_host.gd`: autoload owning service lifecycle across scene changes,
  settings, address discovery, and URL construction. WebSocket bind failure
  rolls back HTTP startup. `stop()` releases listeners and connected peers.
- `host/default_settings.tres`: inspector-editable ports, connection limit and
  request/handshake timeout. Defaults: HTTP 8080, WebSocket 8081, 32 connections
  per service, five-second timeout. Restart to apply changed settings.
- `host/http_service.gd`: fixed route allowlist, bundled assets, bounded request
  buffers, nonblocking partial reads/writes, one GET per connection. No arbitrary
  filesystem access or client-selected resource loading.
- `host/websocket_service.gd`: bounded peers/messages and a JSON hello/welcome
  protocol. It rejects unsupported, malformed, binary, and repeated greetings.
  Clients cannot submit authoritative state. Future game messages should be
  validated and dispatched to separate game components through signals.
- `scenes/lobby.*`: editor-visible Control/Container billboard, address picker,
  refresh/copy actions and nearest-filtered QR texture with a four-module margin.
- `web/src/app.ts`: thin browser client, five-second config fetch timeout,
  handshake timeout and two-second retry. It reconnects after host restart and
  handles pagehide/pageshow for browser back-forward cache restoration.
- `web/public/`: offline HTML/CSS and committed compiled JavaScript. Godot serves
  these directly, so running the game requires neither Node nor internet access.
- `addons/kenyoni/qr_code/`: unmodified MIT QR runtime files pinned to commit
  `3d92d1bab93c0a8cb58951c039ddb17acd70a449`. See UPSTREAM.md and LICENSE.md.
  The existing Godot MCP addon and configuration were left unchanged. Upstream
  trailing whitespace is preserved; exclude this vendor directory from whitespace
  checks. GitHub marks the directory as vendored to keep reviews focused.

## Protocol version 1

GET `/session.json` returns `protocol` and `websocket_port`. The browser uses
the page hostname for `ws://HOST:PORT`.

```json
{"type":"hello","protocol":1}
```

Godot assigns the connection ID and replies:

```json
{"type":"welcome","protocol":1,"connection_id":1,"message":"Hello world"}
```

The HTTP server also serves `/`, `/app.js`, `/style.css`; unknown routes return
404 and non-GET methods return 405. Headers exceeding 8192 bytes are rejected
with 431 or a TCP reset if unread request bytes remain (Windows socket behavior).
There is no TLS, authentication, public hosting, or CORS API in this phase.
The listeners bind all interfaces for LAN access. Do not forward these ports
to the internet. Console packaging/network permissions remain future work.

## Build and verification

Node 22+ is needed only for development/tests (validated with Node 24.20.0).
After TypeScript changes, rebuild and commit `web/public/app.js` with its source.

```powershell
cd web
npm.cmd ci --ignore-scripts
npm.cmd run build
npm.cmd run check
npm.cmd test
```

Close the interactive game before tests. The suite refuses to test over an
existing host and launches its own Godot process. `GODOT_BIN` can override the
Windows executable default in `web/tests/host.test.mjs`. Tests also use ports
18080/18081 for startup rollback/retry/restart checks. QR decoder dependencies
are development-only; they are never shipped to phones.

From the Godot root:

```powershell
godot --headless --editor --path . --quit-after 30
```

Validated: TypeScript build/check; six integration tests covering actual HTTP
assets/config, independent QR decoding, route/method rejection, fragmented and
oversized requests, four simultaneous WebSockets with distinct IDs, malformed
and unauthorized state messages; startup rollback, retry and restart checks.
Godot runtime logs had no script/runtime errors. Headless editor import had no
parse errors; early editor shutdown reports MCP resource-cleanup warnings.
Visually checked the lobby QR and Chrome's Hello world/connected page via the
LAN address, including reconnection after restarting the host. A real phone scan
and mobile-browser layout check remain pending.

## Networking and export caveats

If a phone cannot load the page, check the displayed adapter, same Wi-Fi,
VPN LAN restrictions, guest-network client isolation, and Windows Firewall.
HTTP **and** WebSocket TCP ports must be reachable. If Windows asks to allow
Godot on a private network, the user should handle that permission. This work
does not change firewall or VPN settings. A busy port produces Retry in boot.

No export preset is created in this phase. When adding one, explicitly include
`web/public/*.html,web/public/*.css,web/public/*.js` as non-resource files and
exclude `web/node_modules/*`, `web/src/*`, `web/tests/*`, `tests/*` and
`test-results/*`. Otherwise Godot's export filtering can omit the web assets.
Validate an exported build separately; editor/runtime checks do not prove export.

## Next iteration

Confirm the physical-phone acceptance check, then add validated join/name
messages and a host-owned player registry as separate components. Keep browser
connection IDs separate from stable player identity. Add gameplay only after
that layer has explicit reconnect/disconnect rules.
