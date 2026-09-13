# Play Shapes development

## PS-009 — character feet and reusable asset setup (2026-09-13)

**PS-009 is done.** The project owner explicitly approved the foot art on
2026-09-13 and requested completion. Pull-request merging remains an owner action.
This branch includes the preceding PS-009/PS-010 task-definition commit because
it is not yet on `main`. Unrelated local draft and task-board edits are excluded.

### Files and provenance

- `assets/Kenney_Shape_Characters/`: supplied Kenney Shape Characters 1.0,
  including both 104-image source sets, preview/sample, SVG/SWF overview,
  original CC0 license, and two updated PNG/XML atlases.
- `PNG/{Default,Double}/blue_foot_round.png`: one new right-facing rounded
  foot, 40 x 24 / 80 x 48, transparent and antialiased. Mirror for the left foot.
  One silhouette is the smallest useful set; additional poses await PS-010.
- `art/character-feet/blue_foot_round.xcf`: editable GIMP source with silhouette
  and highlight paths, blue gradient fill, and separate 20%-opacity white rim.
  Default was exported from a cubic downscale of the Double source.
- `art/character-feet/comparison-{default,double}.png`: native-resolution
  comparisons beside bodies, hands, face, assembled character, and environment.
- `art/character-feet/runtime-showcase.png`: captured from the actual Godot
  Compatibility renderer. `PROJECT_ADDITIONS.md` in the pack identifies the new
  feet as project additions, not Kenney originals.

Source inspection covered all 104 names at both resolutions, both atlases,
preview/sample, and the SVG overview. Bodies are 80 x 80 at Default, with smooth
vertical gradients and subtle top rims, not black outlines. Hands are roughly
28–38 pixels wide. The foot's rounded instep/toe and small bright rim follow
that treatment; neither realistic ankles nor a shoe sole outline were added.

Original standalone PNGs, license, preview/sample, and vector files remain
byte-identical. Atlas canvases grow only at the bottom: 577 x 605 and 1154 x 1210.
The new rectangles are (2,579,40,24) and (4,1158,80,48). Original rectangles
retain all coordinates and visible pixels. The atlases now use RGBA; invisible
RGB beneath alpha zero is not part of the appearance-preservation comparison.
Do not downscale the entire atlas to regenerate Default: original entries must
remain their supplied resolution-specific exports.

### Godot usage and designer controls

Instance `characters/shape_character.tscn`. Its six direct `Sprite2D` children
are `Body`, `Face`, `LeftHand`, `RightHand`, `LeftFoot`, and `RightFoot`.
Each has an independent position, rotation, scale, texture, and draw order.
Enable Editable Children on an instance to tune these in the inspector.
Body/face origins are their centers; hand origins are centers; feet have a
heel-biased pivot through ±12 Double-pixel sprite offsets. The root origin is
the body center. Default hand positions are (±55,20), feet (±20,60).
Body z=0, limbs z=1, face z=2. The left hand and foot use `flip_h`; transform
the whole root to place a character, not to recolor it. These defaults are
starting points for human pose experiments, not a committed rig or dance system.

Double is canonical at runtime, with each sprite scaled to 0.5 (80 world-unit
body). Set `player_color` on the root in the inspector or at runtime. Each
instance owns one shader material shared across its five colored parts.
Face has no tint material and retains the source white eyes and dark features.
The shader maps the canonical BLUE art's lightness into colored shadows and
highlights; keep blue body/hand textures when swapping the four body shapes or
six hand poses. Faces can use any `face_*.png`. No atlas parser, color-specific
assemblies, broad customization API, or per-color exports are required.

Keep root/ancestor `modulate` white, otherwise Godot will also modulate the face.
Use `player_color.a` for colored-part opacity only; use ancestor alpha deliberately
when fading the entire character. Very dark colors are lifted toward slate to
keep the dark face readable. This palette favors readability over exact requested
RGB reproduction. Color alone does not guarantee distinguishability for every
player or background; group readability and accessibility remain human checks.

`characters/background_sample.tscn` composes tree and three floor tiles as
ordinary sprites, with no collision, physics, or navigation. It can be instanced
and repositioned independently. It is a composition example, not a final level.

Open `characters/asset_showcase.tscn` and press **F6** for six color/pose examples
against light and dark backgrounds. F5 still starts the existing LAN lobby.
The review scene uses a responsive grid and static transforms only. It neither
starts services nor implements gameplay, networking, rigging, or animation clips.

### Import and authoring settings

All standalone PNGs use lossless compression, mipmaps, alpha-border fixing,
and disabled automatic 3D compression detection. Character and background roots
explicitly use **Linear with Mipmaps** and **Repeat Disabled**; children inherit.
This suits smooth art scaled down for a shared screen. Atlas imports retain no
mipmaps because the original pack has tightly adjacent entries without extrusion;
runtime uses standalone textures to avoid atlas bleed. Source previews/vectors
retain their original import defaults. `art/`, `tools/`, and `test-results/` are
excluded from Godot scanning via `.gdignore`, keeping review material and caches
out of the resource import/export set.

GIMP 3.2.6 showed false transparent stripes when loading some indexed originals.
Never overwrite those originals to fix the editor display. Run
`uv run --with pillow python tools/assets/prepare_gimp_inputs.py` to create
pixel-identical RGBA working copies in ignored `test-results/ps-009/gimp-rgba`.
GIMP performs the actual image composition using those copies. The preparation
script verifies each round-trip; it does not modify source files.
For review regeneration, set `PLAY_SHAPES_ROOT` to the checkout path in GIMP's
Python console, execute `tools/assets/compose_gimp_review.py`, call
`review('Default')` or `review('Double')`, and export that image as PNG.
Open the XCF to edit feet; save source before downscaling a duplicate for Default.
Update both atlas shelves and XML entries after any dimension/shape changes.

### Validation evidence and caveats

From the Godot project root:

```powershell
uv run --with pillow python tools/assets/validate_character_pack.py
godot --headless --editor --path . --quit-after 30
godot --path . --resolution 1152x800 --script res://tests/character_assets_test.gd
```

- **Automated image checks: passed.** 105 names per atlas, complete source sets,
  no overlaps, all rectangles in bounds, preserved original pixel hashes and
  source-file hashes, exact new-foot atlas pixels, transparent antialiased feet,
  exact 2x dimensions throughout, and intentional standalone import settings.
  Baselines in `art/character-feet/original_{manifest,file_hashes}.json` describe
  the supplied originals. Do not regenerate them to conceal a mismatch.
- **Editor load: passed** on Godot 4.7.2. No script or import failures on the final
  run. Early editor shutdown emits the existing MCP resource-cleanup warnings
  (68 objects / 33 resources), separately from loading errors. The initial
  sandboxed attempt could not access Godot's normal settings/cache directories;
  rerunning with access resolved that environmental failure.
- **Real renderer tests: passed** with GL Compatibility on RTX 5070. Six independent
  parts, per-instance material isolation, mirrored feet, changed body pixels after
  tinting, unchanged other player, and 260 unchanged opaque facial pixels.
  The test uses a five-source-pixel interior mask to exclude mipmapped alpha edges;
  a tighter mask falsely included blended body/face edge pixels. It has a timeout
  so an assertion cannot leave a test process running indefinitely.
- **Visual inspection: performed.** Both source-resolution sheets, the vector
  overview, live Godot window through Computer Use, and final renderer capture
  were inspected. Very dark tints were lifted after the first runtime comparison.
- **Human art approval: approved on 2026-09-13.** The owner explicitly approved
  the foot art and requested PS-009 be marked done. The comparison images retain
  their original review-time "art approval pending" captions as historical evidence;
  this approval record supersedes those captions.
  Physical-phone checks, game-feel playtesting, final dance readability, and
  exported-build verification are outside this asset task's technical evidence.

The image scripts were verified with Pillow 12.3.0 (`get_flattened_data`); the `uv --with`
commands install an isolated tool dependency, not a game runtime dependency.
If the normal uv cache is blocked, set `UV_CACHE_DIR` to an ignored folder under
`test-results/`. Renderer-test output is in `test-results/ps-009/render-test.log`
when launched with `--log-file`; its committed screenshot is refreshed each run.

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
