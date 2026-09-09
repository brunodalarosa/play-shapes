# AGENTS.md

## Project

- Local-network multiplayer party game built with Godot
- This directory is the Godot project root. `project.godot` must remain here.
- The project currently targets Godot 4.7 and the GL Compatibility renderer.
- Use Godot 4.4 or newer because the installed Godot MCP requires it.

## Architecture

- Godot runs the authoritative game on the host PC.
- Smartphones are browser clients.
- Browser client uses TypeScript/HTML/CSS.
- Communication uses WebSockets.

## Godot game development guidelines

- Use GDScript unless there is a strong reason not to.
- Prefer typed GDScript.
- Prefer composition over deep inheritance.
- Keep scenes small and reusable.
- UI should primarily use Control and Container nodes.
- Do not hard-code viewport dimensions.
- Use signals for loosely coupled systems.
- Code should be human readable. Add comments explaining particularly complex parts of the code.

## Networking

The PC is authoritative.

Clients may send:
- UI actions
- player choices
- controller input

Clients must never directly modify authoritative game state.

## Local Godot setup

- `godot` is available from PowerShell and cmd through the user-level shim at `C:\Users\backup pc\.local\bin\godot.cmd`.
- The shim invokes `C:\Users\backup pc\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- The GUI editor is `C:\Users\backup pc\Documents\Godot\Godot_v4.7.2-stable_win64.exe`.
- Check the installed editor with `godot --version`.
- Run commands from this project root. When PATH inheritance is uncertain, use the absolute executable paths above.

## Godot MCP setup

- hybridindie's `godot-editor-mcp` 2026.09.02 is installed as an isolated `uv` tool.
- The server executable is `C:\Users\backup pc\.local\bin\godot-editor-mcp.exe`.
- The official editor addon is vendored at `addons/godot_mcp/`.
- The addon is enabled in `project.godot` as `res://addons/godot_mcp/plugin.cfg`.
- The addon connects to the local bridge at `ws://127.0.0.1:9080` and reconnects automatically.
- Do not edit files inside `addons/godot_mcp/` unless the task explicitly requires changing or upgrading the third-party addon.

## OpenCode integration

- Project-local MCP configuration lives in `opencode.json` under the server name `godot`.
- OpenCode executes `C:\Users\backup pc\.local\bin\godot-editor-mcp.exe` using stdio transport.
- The configuration supplies these environment variables:
  - `GODOT_MCP_GODOT_BIN=C:\Users\backup pc\Documents\Godot\Godot_v4.7.2-stable_win64.exe`
  - `GODOT_MCP_PROJECT_DIR=C:\Users\backup pc\Documents\Codex\Play Shapes\play-shapes`
- Start OpenCode from this directory so it discovers `opencode.json`.
- Only one MCP server process can own the editor bridge at a time. If port 9080 is already occupied, stop the stale MCP process before retrying; do not start competing stdio and HTTP servers.

## Using the MCP tools

1. Open this project in Godot and keep the editor running.
2. Start OpenCode from this project root. It launches the `godot` MCP server automatically.
3. Begin with the always-available core and inspection tools. Use `godot_get_server_info` or `godot_list_toolsets` to inspect capabilities and connection state.
4. Enable only the additional toolset needed for the current task, such as `scene_edit`, `scripts`, `runtime`, or `testing`.
5. Prefer read-only inspection before mutation. Use `dry_run` where supported, and supply explicit confirmation only for an intended destructive MCP operation.
6. Save scenes/resources through Godot after MCP edits and validate scripts for parse errors.

## Verification and troubleshooting

- Confirm Godot resolution: `godot --version`.
- Confirm OpenCode discovery: `opencode mcp list`. The expected status is `godot connected` while OpenCode owns the server.
- Confirm configuration resolution when needed: `opencode debug config`.
- If the MCP reports that the bridge is disconnected, confirm that Godot is open, the Godot MCP plugin is enabled, and no stale process owns port 9080. The addon should then reconnect automatically.
- A headless editor-load check can be run with:
  `godot --headless --editor --path . --quit-after 10`
- Treat an exit code of zero and absence of addon/script parse errors as the relevant result. Forced early shutdown may emit resource-cleanup warnings that do not indicate a project-load failure.

## Change discipline

- Keep changes scoped to the requested feature and preserve unrelated project settings.
- Prefer small, readable GDScript components over a single large script.
- Keep scenes and resources editor-loadable, and verify meaningful changes in Godot when possible.
- Do not reinstall or move Godot, replace the MCP configuration, or upgrade the addon/package unless explicitly requested.

## Before completing a task

1. Check scripts for parse errors.
2. Run relevant tests.
3. Inspect the Godot output for errors.