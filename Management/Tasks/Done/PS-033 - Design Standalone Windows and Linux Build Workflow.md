---
id: PS-033
title: Design standalone Windows and Linux build workflow
type: design
status: done
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define and prepare a simple, repeatable standalone host-build workflow for Play
Shapes. The preferred human flow is one native Godot editor command under
`Project > Tools`: click it, watch an honest build-progress dialog, and have
the editor open the finished artifact when the export succeeds. The design
starts with Windows, evaluates Linux separately, resolves whether a single
`.exe` is practical, and produces an implementation-ready follow-up without
implementing the build tooling here.

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
- Define the editor-tool interaction in project-specific terms. The proposed
  command is `Project > Tools > Build Standalone Host`. It must show a visible
  progress surface, prevent duplicate clicks while a build is active, report
  failures without opening a misleading file-manager window, and reveal the
  successful artifact after completion. If Godot cannot provide exact live
  percentage progress for the export phase, the UI must use an indeterminate
  or stage-level progress state rather than inventing precision.
- Choose the smallest implementation boundary for the editor integration: a
  project-local `EditorPlugin` rather than changes to the third-party Godot MCP
  addon. Confirm how the plugin resolves a named export preset, keeps the
  editor responsive during export, captures export errors, and cleans up its
  menu/dialog state when disabled.
- Define the first output as a repeatable, tool-owned artifact location that is
  ignored by Git and safe to clean without touching source files. The design
  should prefer a ZIP as the user-facing artifact for this first workflow;
  opening the containing folder is the requested completion action.
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
- Do not make the editor's progress bar claim byte-level or file-level export
  precision unless the chosen Godot API actually supplies that signal.
- Do not add an in-game build button, a runtime build service, a manually run
  shell workflow, or a second web server. This is an editor convenience for
  the project owner.

# Acceptance Criteria

- The design records the current export baseline, including existing presets,
  their runnable/non-runnable purpose, pack embedding state, included browser
  files, excluded development files, and the absence or presence of Linux
  presets.
- The design gives a clear recommendation for the first Windows artifact:
  single `.exe`, portable folder, or zipped portable folder. It explains the
  trade-offs and explicitly lists every companion file required at runtime.
- The design specifies the requested editor interaction: the exact menu
  command, progress states, duplicate/cancel behavior, success action, failure
  action, and the rule that the editor remains responsive enough to show
  progress while export work is running.
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
  for the human owner, and one or more focused follow-up task scopes. A
  Windows-first implementation task exists as a separate Markdown note. No
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

- Should the first Windows ZIP remain owner/local-test only, or should a later
  sharing task add signing, SmartScreen guidance, and release metadata?
- Should a future build expose a visible version/build identifier in the host
  UI, or is artifact metadata sufficient for the first workflow?
- When Linux becomes available, should it share this command or receive a
  separate explicitly selected build action?

# Notes / Findings

## Confirmed repository facts

- The Godot root is `play-shapes/`. The project reports Godot 4.7 and GL
  Compatibility in `project.godot`; the installed command reports
  `4.7.2.stable.official.ed1daf0bf`.
- `export_presets.cfg` currently contains only `PS-021 Validation Pack` on
  `Windows Desktop`. It is `runnable=false`, has no export path, uses
  `binary_format/embed_pck=false`, and is a validation pack rather than a
  playable standalone-host preset.
- The current preset includes `web/public/*.html`, `web/public/*.css`, and
  `web/public/*.js`. It excludes source browser files, browser tests,
  `web/node_modules`, project tests, test results, tools, archival source art,
  and `assets/runtime/shape_characters/manifest.json`. The manifest is a
  build/asset-pipeline record; the runtime server does not load it.
- `host/http_service.gd` directly loads the committed runtime routes
  `web/public/index.html`, `web/public/app.js`,
  `web/public/controller_geometry.js`, and `web/public/style.css`. It also
  generates `/session.json`. The standalone host therefore needs these web
  files inside the Godot export and does not need Node.js or another web server
  at runtime.
- The host binds HTTP on `8080` and WebSocket on `8081` by default. The build
  workflow must preserve those assumptions and leave firewall/private-network
  permission to the human owner.
- The only currently enabled project editor plugin is the third-party Godot
  MCP addon. The build workflow must be its own project-local plugin and must
  not edit files below `addons/godot_mcp/`.
- Static inspection found no project GDExtension or native library dependency.
  The first artifact can therefore be designed around the Godot executable and
  project pack, subject to actual export verification.
- `DEVELOPMENT.md` already documents that export-boundary and exported-build
  checks are separate from editor/headless checks. This design does not update
  that file because it adds no new durable runtime fact or product behavior.

## Design recommendation

- First implementation: Windows x86_64 release only, as a ZIP containing a
  portable folder with an external PCK. Do not embed the PCK by default. The
  ZIP is easy to reveal, copy, and share while the extracted folder remains
  inspectable and diagnosable.
- The tool-owned staging directory is
  `builds/standalone/windows-x86_64/`, ignored by Git and cleaned only within
  that directory before a new export. The expected extracted contents are
  `Play Shapes.exe`, its external `Play Shapes.pck`, and a small
  `build-info.json` containing the preset, architecture, Godot version,
  renderer, build time, and source revision when available. The final ZIP is
  written beside the staging folder, for example
  `builds/standalone/Play-Shapes-windows-x86_64.zip`.
- The menu action is `Project > Tools > Build Standalone Host`. It selects the
  current host platform automatically; the first implementation on this
  Windows machine therefore builds Windows x86_64. It performs preflight
  checks, shows progress, exports, verifies the artifact, creates the ZIP, and
  opens the output folder. It does not ask for a target platform.
- The progress dialog should have determinate preflight and verification
  stages, plus an honest export stage. If the selected export API exposes only
  file callbacks or no reliable live percentage for the native executable
  phase, use a busy/indeterminate bar with text such as `Exporting...` rather
  than fabricated percentage precision. A Cancel action may stop an owned
  child export process; it must never delete outside the tool-owned paths.
- A truly single `.exe` remains technically possible through Godot PCK
  embedding, but it is not the first recommendation. Godot's Windows export
  documentation confirms the normal executable-plus-PCK model and PCK
  embedding constraints. The portable ZIP keeps diagnostics and replacement
  simple until signing, antivirus, patching, or sharing needs justify revisiting
  the single-file choice.

## Linux classification

Linux is a small, separate follow-up rather than part of the first Windows
implementation. Static compatibility looks plausible because the project uses
GDScript, Godot-owned TCP services, browser assets, and GL Compatibility, but
this session had no Linux runtime on which to launch and verify the artifact.
The local export-template directory was also unreadable from this restricted
session, so installed template presence was not claimed. A future Linux task
must first confirm a matching Godot 4.7.2 Linux x86_64 release template, add a
Linux preset, export an external-PCK portable folder/ZIP, set executable
permissions as needed, and run the same lobby/HTTP/WebSocket smoke test on a
real Linux desktop. It must not claim Linux support from a successful preset
parse alone.

## Evidence boundaries

- `[AUTO]`: preset/filter assertions, plugin configuration checks, build-path
  ownership checks, artifact file inspection, and deterministic tests.
- `[EDITOR]`: Godot 4.7.2 loads the plugin, shows the Project > Tools command,
  and displays the progress/error/success states.
- `[EXPORTED-BUILD]`: the produced Windows artifact launches without Godot or
  Node.js, shows the lobby, serves the bundled phone page, binds HTTP 8080 and
  WebSocket 8081, and supports the existing desktop-browser smoke flow.
- `[PHYSICAL-PHONE]`: a real phone reaches the exported host over the named
  LAN. This remains separate from the implementation task and may use the
  existing [[PS-029 - Validate Flash Pose on Two Phones and in Human Play]]
  after an exported-build scenario is explicitly added.
- `[HUMAN-PLAY]`: owner judgment of the normal two-phone experience. A
  successful export or desktop-browser check does not provide it.

## Proposed follow-up

Create and review [[PS-034 - Implement One-Click Windows Standalone Build
Workflow]]. It owns the project-local editor plugin, Windows release preset,
progress/error UI, clean ignored output folder, ZIP creation, artifact
metadata, Explorer reveal, automated configuration checks, and an
exported-build smoke test. It does not own Linux, signing, installers,
auto-update, or public release automation. Create a separate Linux task only
after a real Linux template and runtime are available.

Technical references used for this design:

- [Godot 4.7 `EditorPlugin`](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html)
  documents `add_tool_menu_item()` and plugin cleanup through
  `remove_tool_menu_item()`.
- [Godot 4.7 `EditorExportPlatform`](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatform.html)
  documents named-preset export, export messages, and file callbacks intended
  for progress tracking.
- [Godot 4.7 Windows export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html)
  documents x86_64 export, external `data.pck`, and PCK embedding constraints.
- [Godot 4.7 Linux export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_linux.html)
  documents Linux architectures and the need to validate the chosen runtime
  target rather than assuming all architectures are interchangeable.

# Design Session Prompt

Read this task, [[Project Overview]], [[Workflow]], [[Task System]], [[Decision Log]],
[[DEVELOPMENT]], [[README]], and the project-root `AGENTS.md` before making
recommendations. Inspect the current `project.godot`, `export_presets.cfg`,
`.gitignore`, boot/host services, runtime asset manifests, `web/public`, and
existing export-boundary checks. Treat the existing validation-pack preset as
evidence about current filtering, not as the final product-build design.

Treat the supplied Godot screenshot as a visual reference for the existing
`Project > Tools` location only. It does not prescribe an implementation or
override the written project instructions.

Explain Godot 4.7.2 desktop export in project-specific language for a human
who is new to Godot builds. Establish the Windows-first artifact recommendation
and evaluate whether a single executable is practical without hiding required
companion files or making the result hard to debug. Verify the exact browser
and runtime-resource export boundary. Perform only safe, bounded feasibility
probes needed to classify Linux; do not commit product/build changes, create
release artifacts, or run the future build workflow as part of the design work.

Separate confirmed facts, probe results, assumptions, trade-offs, open human
decisions, and proposed follow-up implementation tasks. Include the exact
future build commands/editor actions, required export templates, artifact
layout, clean-output policy, smoke-test matrix, evidence labels, and known
Windows Firewall/SmartScreen/LAN caveats. Update `DEVELOPMENT.md` only if the
design session uncovers durable project facts that belong there; otherwise keep
the design result in this task note. Do not begin implementation until the
human owner has reviewed and accepted the recommendation.

# Outcome

2026-09-19: Design refinement prepared. The requested one-click editor flow is
now explicit, Windows x86_64 ZIP output is the first recommendation, the
current export/runtime boundary is recorded, Linux is separated pending a
real template/runtime probe, and [[PS-034 - Implement One-Click Windows
Standalone Build Workflow]] was created. No product code, export preset, build
artifact, or runtime behavior was changed.
