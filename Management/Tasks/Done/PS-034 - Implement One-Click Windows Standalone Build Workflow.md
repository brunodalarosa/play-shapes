---
id: PS-034
title: Implement one-click Windows standalone build workflow
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-033 - Design Standalone Windows and Linux Build Workflow]]"
---

# Goal

Let the project owner create a repeatable Windows x86_64 release ZIP from the
open Godot editor through one native command: `Project > Tools > Build
Standalone Host`. The command must show honest progress, produce a portable
standalone host without Node.js, and open the resulting artifact folder in the
operating system file manager when the build succeeds.

# Scope

- Add a small project-local Godot editor plugin under `addons/` for the build
  workflow. Register the command with `EditorPlugin.add_tool_menu_item()` and
  remove it cleanly when the plugin is disabled. Do not modify or extend the
  third-party `addons/godot_mcp/` addon.
- Enable the new plugin in `project.godot` beside the existing MCP plugin, with
  a human-readable plugin name and description. Keep the plugin editor-only;
  it must not add runtime autoloads or game-scene dependencies.
- Add a named Windows release export preset for the current Godot 4.7.2,
  Windows Desktop, GL Compatibility project. Target x86_64, use a release
  template, keep the console wrapper off for the normal artifact, and leave
  PCK embedding off for the first portable-folder recommendation.
- Preserve the confirmed runtime export boundary. Include the committed
  `web/public/*.html`, `web/public/*.css`, and `web/public/*.js` files, including
  the four routes loaded by `host/http_service.gd`. Exclude source browser
  files, `web/node_modules`, browser tests, Godot tests, test results, tools,
  archival source art, the runtime asset manifest, editor/MCP tooling, and
  other files proven not to be runtime inputs. Do not replace the allowlist
  with an unverified broad filter just to make the export pass.
- Export into the tool-owned, Git-ignored staging directory
  `builds/standalone/windows-x86_64/`. Clean only that directory before a new
  build, preserve the source checkout, and keep the output path out of the
  committed source asset tree. Create the final
  `builds/standalone/Play-Shapes-windows-x86_64.zip` containing the portable
  folder with `Play Shapes.exe`, its external `Play Shapes.pck`, and a small
  `build-info.json` with the preset, architecture, Godot version, renderer,
  build time, and source revision when available.
- Keep the normal command target-free: on Windows it builds Windows x86_64; on
  an unsupported editor host it reports that the current platform is not yet
  supported instead of opening a target-selection dialog or attempting a
  cross-platform export.
- Resolve the named preset rather than relying on a fragile numeric preset
  index. Fail before export with an actionable dialog if the preset is absent,
  the required Windows release template is unavailable, the staging directory
  cannot be prepared, or the project/export configuration is invalid.
- Keep the editor responsive while exporting. Prefer a non-blocking Godot
  export process with captured output, such as `OS.execute_with_pipe()` using
  the matching editor executable and `--headless --export-release`, or use a
  proven editor export API path that provides equivalent responsiveness and
  error reporting. Do not call a blocking process on the editor's main thread.
- Show a modal build-progress dialog with:
  - a clear title and target path;
  - a determinate preflight stage;
  - an honest export stage, using exact progress only when the chosen API
    provides it and otherwise an indeterminate/busy `ProgressBar` with an
    `Exporting...` label;
  - a determinate artifact-verification and ZIP stage;
  - a Cancel action while cancellation is safe, with no source deletion;
  - disabled duplicate build actions while a build is active; and
  - success and failure states that remain readable long enough for the owner
    to understand what happened.
- On success, verify the expected executable/PCK/metadata files, confirm the
  required bundled browser assets are present in the exported pack or artifact
  using a deterministic check, create the ZIP, update the dialog, and open the
  extracted staging directory through the OS file manager. Do not launch the
  game automatically and do not open Explorer after a failed or cancelled
  build.
- On failure or cancellation, keep the editor usable, show the actionable
  error and relevant captured export output, and leave no false success state.
  Partial output may remain only inside the tool-owned build directory and
  must be clearly marked or safely replaceable on the next run.
- Add focused checks for preset name/platform/architecture/options, include
  and exclude filters, output-path ownership, ZIP contents, metadata shape, and
  failure paths for missing templates or export errors. Keep build-specific
  logic separate from game runtime code.
- Update [[DEVELOPMENT]] with the menu path, required matching export templates,
  output layout, cleanup behavior, progress limitations, troubleshooting, and
  the distinction between editor checks and exported-build evidence.

# Non-Goals

- Linux export or Linux runtime support. Create a separate follow-up only after
  a real Linux x86_64 template and runtime are available for verification.
- PCK embedding as the default, a single-file Windows executable, installers,
  code signing, SmartScreen remediation, auto-update, stores, crash reporting,
  CI/release automation, or public distribution policy.
- A debug/console build in the one-click action. Keep debug export available
  through Godot's normal export workflow or a later explicitly scoped action.
- Changing the HTTP/WebSocket protocol, ports, firewall configuration, browser
  assets, runtime asset ownership, renderer, gameplay, or host lifecycle.
- Starting Node.js, rebuilding TypeScript, launching a second web server, or
  modifying compiled browser files as part of a standalone build.
- Treating an editor menu check, headless export, or desktop-browser smoke test
  as physical-phone or human-play approval.

# Acceptance Criteria

- With the plugin enabled in Godot 4.7.2, `Project > Tools > Build Standalone
  Host` is visible exactly once and starts the workflow without requiring a
  terminal, Node.js, or manual export-dialog setup.
- A build request performs preflight validation and either reports an
  actionable error before export or opens the progress dialog before doing
  export work. A second click cannot start a concurrent build.
- The editor remains responsive while the export is running. The dialog shows
  the current stage and an honest progress state; it never displays fabricated
  byte/file precision when the export API cannot supply it.
- Cancel stops the owned build operation or records that cancellation is not
  safe at the current substage, then returns to a usable editor without opening
  the output folder or deleting source files.
- A successful Windows release produces the intended Git-ignored staging
  directory and final ZIP, including the portable executable, external PCK,
  and valid `build-info.json`. The next build is repeatable after cleaning only
  the tool-owned paths.
- ZIP inspection confirms that the exported pack contains the four committed
  browser routes required by `HttpService`, the loaded runtime scenes/resources,
  and the required QR/runtime assets, while documented development-only files
  are absent.
- After a successful build the extracted staging folder containing the
  standalone executable opens in the OS file manager; the ZIP remains beside
  it. Failed, cancelled, missing-template, and missing-preset paths do not
  claim success and do not open a misleading folder.
- The exported executable starts without the Godot editor or Node.js, shows
  the lobby, serves the bundled phone page, binds the existing HTTP 8080 and
  WebSocket 8081 services, and completes the existing desktop-browser join/
  handshake smoke flow. This is recorded as `[EXPORTED-BUILD]` evidence.
- `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, `[DESKTOP-BROWSER]`,
  `[EXPORTED-BUILD]`, `[PHYSICAL-PHONE]`, and `[HUMAN-PLAY]` evidence are not
  conflated. This task may pass without physical-phone or human-feel approval;
  any release claim requiring those checks links a separate validation task.
- `DEVELOPMENT.md` explains how another agent can find the plugin, confirm
  templates, run the one-click build, inspect output, recover from failure,
  and distinguish exported-build proof from editor/headless proof.

# Game Feel / Player Experience

This is an owner workflow rather than game feel. The experience should be
predictable and low-friction: one menu action, visible status while waiting,
clear failure recovery, and a ZIP plus extracted folder that can be copied
without understanding Godot internals. It must not hide a failed export behind
an Explorer window or imply that a build is playable before artifact checks
complete.

# Open Questions

- Whether a later owner-facing release workflow should add signing,
  SmartScreen guidance, additional release metadata, or a visible in-game
  version remains outside this implementation.
- Whether Linux should later share this menu item or receive a separate target
  action depends on a real Linux template/runtime probe.

# Notes / Findings

Implement from [[PS-033 - Design Standalone Windows and Linux Build Workflow]].
The current `PS-021 Validation Pack` is not the product preset and must not be
silently repurposed. The first supported artifact is intentionally a portable
Windows x86_64 release folder wrapped in a ZIP. The supplied screenshot is
only a reference for the `Project > Tools` location.

# Draft Execution Prompt

Read this task, [[PS-033 - Design Standalone Windows and Linux Build Workflow]],
[[Project Overview]], [[Workflow]], [[Task System]], [[Decision Log]],
[[DEVELOPMENT]], [[README]], and `AGENTS.md` before editing. Inspect the current
`project.godot`, `export_presets.cfg`, `.gitignore`, `host/http_service.gd`,
runtime scenes/assets, existing tests, and the third-party MCP plugin without
modifying that addon. Implement only the Windows x86_64 one-click editor
workflow described here: a project-local `EditorPlugin`, named release preset,
ignored clean output directory, honest progress/error/cancel UI, artifact
metadata, deterministic export-boundary checks, ZIP creation, and Explorer
reveal on success. Keep the editor responsive, avoid blocking the main thread,
and never run Node or a second web server. Do not implement Linux, signing,
installers, auto-update, or unrelated refactors. Add focused automated checks,
perform the Godot editor/load verification, run one real exported-build smoke
test, and report `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, `[DESKTOP-BROWSER]`,
and `[EXPORTED-BUILD]` evidence separately. Do not claim `[PHYSICAL-PHONE]` or
`[HUMAN-PLAY]` approval. Update [[DEVELOPMENT]] with exact usage and caveats,
report assumptions/deviations, keep all changes local for this task, and do not
open a pull request unless the owner later requests one.

## Implementation Findings — 2026-09-19

Implementation is present on `codex/ps-034-windows-standalone-build`: a
project-local editor plugin, named Windows release preset, strict export
boundary, ignored owned output area, non-blocking export process, honest staged
progress/cancellation, artifact metadata, PCK route verification, portable ZIP,
and Explorer reveal on verified success. Focused automated checks and a normal
Godot 4.7.2 editor load pass.

The first owner run correctly exposed missing Godot 4.7.2 Windows x86_64 export
templates, and its dialog also proved too tall/narrow under Windows display
scaling. The exact official debug/release templates are now installed. The
dialog opens at a bounded 960×540 logical 16:9 size with a shorter expandable
details area.

The first landscape-size correction still allowed an extreme vertical opening
because `popup_centered(size)` treats `size` as a minimum and the wrapped target
path calculated its minimum height before it had a usable width. The final fix
assigns the window size before calling parameterless `popup_centered()`, keeps
the target path to one ellipsized line with a full tooltip, and live-checks the
result. The headless editor reproduced 878×3098 before the correction and
878×450 afterward.

A real export then exposed and fixed two export-boundary defects: development
JSON files were being packaged, while the runtime Kenyoni QR addon had been
excluded with editor tooling and prevented the lobby from loading. The final
filter excludes the MCP/builder addons and browser tooling but preserves the QR
dependency. The actual plugin workflow now produces and verifies the EXE, PCK,
metadata, and ZIP. `[EXPORTED-BUILD]` localhost evidence confirms all four
bundled browser routes return HTTP 200, `/session.json` is valid, port 8081 is
listening, and the exported process has empty stderr. `[DESKTOP-BROWSER]`,
`[PHYSICAL-PHONE]`, and `[HUMAN-PLAY]` remain unclaimed.

# Outcome
