# Contributor guidance

This directory is the Godot project root. Work on a new local branch and commit implementation changes locally. Do not push or open a pull request until the project owner approves publication.

## Architecture and coding

- Godot is the authoritative PC host. Phones are TypeScript/HTML/CSS browser clients over HTTP and WebSockets. Clients send input and choices; only the host changes game state.
- Use typed GDScript where practical, small reusable scenes, composition, signals for loose coupling, and Control/Container nodes for UI. Avoid fixed viewport dimensions and duplicate behavior. Explain complex code in comments.
- Preserve the bundled runtime assets and `web/public/` output. Rebuild the browser bundle after changing `web/src/`.
- Minigame numbers are stable identifiers. 001 was retired; 002 is the first approved game. Never reuse or renumber IDs.
- A Shape Character is a player-owned geometric character with floating hands and feet. Keep poses and expressions readable, including natural blinking and context-appropriate gestures.

## Visual direction

Play Shapes is a playful imagined world of living toys and crafts. Draw from toys, school supplies, papercraft, plushies, colorful foods and plants, action figures, blocks, and pencil drawings. Favor stylized, recognizable forms over photorealism. Apply this to UI, environments, characters, effects, shaders, and animation.

## Setup and verification

- Use Godot 4.7.2 or newer with the GL Compatibility renderer. Run `godot --version` and `godot --path .` from this repository root. Set `GODOT_BIN` to a Godot executable when it is not on PATH.
- Run relevant Godot scripts with `godot --headless --path . --script tests/<name>.gd` and check output for parse or runtime errors.
- For browser work, run `npm install`, `npm run check`, `npm run build`, and `npm test` in `web/`.
- Keep changes scoped. Update `DEVELOPMENT.md` when current setup, architecture, protocols, or verification steps change.
- The vendored `addons/godot_mcp/` editor integration is optional. Enable it in Godot's Plugin settings only when needed; configure your own local MCP client separately. Do not change the third-party addon unless the task calls for it.

See [README.md](README.md) for clone and play instructions and [DEVELOPMENT.md](DEVELOPMENT.md) for implementation details.
