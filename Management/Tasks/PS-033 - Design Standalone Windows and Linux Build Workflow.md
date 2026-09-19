---
id: PS-033
title: "Design standalone Windows and Linux build workflow"
type: design
status: backlog
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define a simple, repeatable way to produce standalone Play Shapes host builds,
starting with Windows and adding Linux only if the extra support is genuinely
low-cost and reliable. The design should explain Godot's export model in
project-specific terms, resolve whether a single `.exe` is practical, and give
the human owner an implementation-ready scope to approve before build tooling
is added.

# Scope

- Inspect the current Godot 4.7.2 project, `project.godot`,
  `export_presets.cfg`, `.gitignore`, runtime asset boundaries, and host boot
  flow before proposing packaging changes.
- Establish the intended first release target for Windows, including the
  architecture, debug/release distinction, output naming, output folder or
  archive shape, required Godot export templates, and whether a portable build
  is sufficient.
- Evaluate the requested single-file goal honestly. Determine whether the
  Godot version and available export templates can embed the project pack in a
  Windows executable, whether any runtime DLL or companion file is still
  required, and whether embedding changes startup, patchability, diagnostics,
  or antivirus/SmartScreen expectations. Recommend single `.exe`, portable
  folder, or zipped folder as the first supported distribution shape.
- Define the assets and generated browser files that must be present in an
  exported host build. In particular, account for the host's local HTTP server
  serving the committed `web/public/*.html`, `*.css`, and `*.js` files without
  Node.js or an external web server at runtime.
- Define what must remain excluded from release output, such as source-only
  browser files, `web/node_modules`, tests, test captures, development tools,
  archival source art, manifests that are not runtime inputs, and editor/MCP
  tooling, while preserving every asset actually loaded at runtime.
- Validate Linux feasibility as a bounded design investigation. Check whether
  the installed Godot/export-template setup can produce a runnable Linux
  desktop build with the same project and renderer, identify any script,
  filesystem, socket, asset, or browser-hosting incompatibilities, and compare
  the effort and verification burden with Windows. Do not commit Linux support
  merely because an export command accepts the preset.
- Define the minimum build and verification workflow an agent can later
  implement: command or editor path, prerequisites, clean output location,
  repeatability, version metadata, smoke test, and artifact inspection.
- Define exported-build acceptance evidence separately from editor/headless
  checks. Include host startup, lobby display, local HTTP/WebSocket services,
  browser join over LAN when practical, restart/return-to-lobby behavior, and
  Windows firewall/permission handoff boundaries.
- Produce a recommendation and a bounded follow-up implementation task or
  task set. Keep product implementation, final export presets, installers,
  code signing, auto-update, and release automation out of this design task.

# Non-Goals

- Do not add or modify export presets, build scripts, CI workflows, installers,
  packaging files, project settings, or release binaries in this task.
- Do not implement Linux support, a Windows installer, auto-update, code
  signing, notarization, store packaging, crash reporting, or a public release
  pipeline.
- Do not change gameplay, browser UI, networking protocol, ports, firewall
  configuration, or runtime asset ownership merely to make packaging easier.
- Do not treat the existing validation-pack `.pck` as a finished standalone
  game build, and do not treat a successful export command as proof that the
  exported host runs correctly.
- Do not assume that “single `.exe`” is automatically better than a portable
  folder if Godot runtime files, debugging, patching, or Windows security make
  the folder safer for the first release.

# Acceptance Criteria

- The design records the current export baseline, including existing presets,
  their runnable/non-runnable purpose, pack embedding state, included browser
  files, excluded development files, and the absence or presence of Linux
  presets.
- The design gives a clear recommendation for the first Windows artifact:
  single `.exe`, portable folder, or zipped portable folder. It explains the
  trade-offs and explicitly lists every companion file required at runtime.
- The design answers whether the current Godot project can run without Node.js
  after export, and identifies the exact committed `web/public` assets and
  other runtime resources that must survive export filtering.
- The design states whether Windows should be 64-bit only, what Godot export
  templates are required, whether a debug build is needed in addition to a
  release build, and how output names/locations should be kept out of the
  repository or intentionally tracked.
- Linux feasibility is classified as one of: support in the same first
  implementation task, a small separately scoped follow-up, or defer. The
  classification is based on an actual template/export/runtime probe or a
  clearly documented environment blocker, not assumption alone.
- The design lists the smallest exported-build smoke test that proves the
  artifact starts the authoritative host, shows the lobby, serves the bundled
  phone page, opens HTTP and WebSocket listeners, and preserves the existing
  host/browser flow. It identifies which steps require a real LAN/device and
  which can be automated.
- The design explicitly separates `[AUTO]`, `[GODOT-RUNTIME]`, and
  `[EXPORTED-BUILD]` evidence, and does not claim editor/headless success as
  exported-build or physical-phone evidence.
- The design calls out Windows Firewall/private-network permission as a human
  handoff and preserves the existing 8080 HTTP / 8081 WebSocket assumptions
  unless a separate decision changes them.
- The design ends with an implementation-ready recommendation, open decisions
  for the human owner, and one or more focused follow-up task scopes. No
  product/build files are changed by completing this design task.

# Game Feel / Player Experience

Packaging should make it easy to launch the shared host on a Windows PC and
begin a normal local-network session without opening Godot, installing Node.js,
or understanding the project internals. The first artifact should be
predictable and diagnosable for the owner, even if that means choosing a small
portable folder instead of forcing an opaque single executable. Linux should
only be presented as supported if the same lobby-and-phone experience remains
reliable enough to justify telling players it works.

# Open Questions

- Is the first standalone build intended only for the project owner and local
  testing, or should the design already account for sharing it with other
  Windows users who may see SmartScreen or lack Godot export templates?
- Should a future build expose a visible version/build identifier in the host
  UI or only in artifact metadata and logs?
- If Linux export is technically easy but LAN/firewall/device verification is
  not available in the current environment, should Linux be documented as
  experimental or deferred until a Linux runtime can be tested?
- Is a portable zip acceptable for the first user-facing workflow if a truly
  single `.exe` would reduce diagnostics or make patching less practical?

# Notes / Findings

- `export_presets.cfg` currently contains `PS-021 Validation Pack` on
  `Windows Desktop`, marked `runnable=false`, with no export path and
  `binary_format/embed_pck=false`. It is a validation pack, not a playable
  standalone host preset.
- The current preset explicitly includes `web/public/*.html`,
  `web/public/*.css`, and `web/public/*.js`, while excluding source browser
  files, tests, tools, test results, `web/node_modules`, the archival Kenney
  pack, and the runtime character manifest. The design must verify that these
  boundaries still match actual runtime loads before recommending a release
  preset.
- The host starts Godot-owned HTTP and WebSocket services on ports 8080 and
  8081 and serves the committed browser client from the project. A standalone
  build therefore needs both the host executable/runtime and the bundled web
  assets; Node.js is a development-time dependency only.
- `DEVELOPMENT.md` already states that exported builds require separate
  validation and that the export boundary must include the web assets. It also
  records Windows Firewall/private-network permission as an owner-handled
  boundary rather than something the project changes automatically.
- The current project targets Godot 4.7.2 and GL Compatibility. The design
  should preserve that renderer unless a platform probe demonstrates a real
  export blocker.

# Design Session Prompt

Read this task, [[Project Overview]], [[Workflow]], [[Task System]], [[Decision Log]],
[[DEVELOPMENT]], [[README]], and the project-root `AGENTS.md` before making
recommendations. Inspect the current `project.godot`, `export_presets.cfg`,
`.gitignore`, boot/host services, runtime asset manifests, `web/public`, and
existing export-boundary checks. Treat the existing validation-pack preset as
evidence about current filtering, not as the final product-build design.

Explain Godot 4.7.2 desktop export in project-specific language for a human
who is new to Godot builds. Establish the Windows-first artifact recommendation
and evaluate whether a single executable is practical without hiding required
companion files or making the result hard to debug. Verify the exact browser
and runtime-resource export boundary. Perform only safe, bounded feasibility
probes needed to classify Linux; do not commit product/build changes or create
release artifacts as part of the design work.

Separate confirmed facts, probe results, assumptions, trade-offs, open human
decisions, and proposed follow-up implementation tasks. Include the exact
future build commands/editor actions, required export templates, artifact
layout, clean-output policy, smoke-test matrix, evidence labels, and known
Windows Firewall/SmartScreen/LAN caveats. Update `DEVELOPMENT.md` only if the
design session uncovers durable project facts that belong there; otherwise keep
the design result in this task note. Do not begin implementation until the
human owner has reviewed and accepted the recommendation.

# Outcome

