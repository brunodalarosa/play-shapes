# Play Shapes Project Overview

Play Shapes is a local-network-first multiplayer party game. The shared game world runs on a computer or console connected to a display, while players use smartphone web pages as controllers. Normal local play must not fundamentally depend on Internet access; individual future modes may explicitly opt into online requirements.

## Product principles

- The host device is authoritative. Phones submit player actions and choices, not authoritative game state.
- Joining and controlling the game should feel approachable on an ordinary phone browser.
- The shared display carries the common game world; phones provide private or contextual controls when useful.
- Playable milestones should prove a player experience, not merely the existence of code.
- Characters should feel alive, not like rigid assemblies: use natural blinking,
  varied context-appropriate facial expressions, and expressive hand shapes and
  gestures. Occasional subdued or sad expressions can add personality, but
  animation variety must preserve gameplay-pose readability and emotional intent.
- Automated checks, editor checks, device checks, and human playtests are distinct evidence and must be reported separately.

## Current technical baseline

- Godot 4.7.2 with the GL Compatibility renderer is the current host runtime.
- The smartphone client uses bundled HTML, CSS, TypeScript/JavaScript, and WebSockets.
- The host serves the controller locally over HTTP and communicates through a versioned WebSocket protocol.
- Phase 1 is merged: the host can display a LAN join URL and QR code, serve an offline Hello world controller, and accept a versioned browser handshake.
- Desktop-browser and automated checks passed for Phase 1. Physical-phone scanning, mobile layout, and cross-device LAN access still require human validation; see [[PS-002 - Validate Phase 1 on a Physical Phone]].

Implementation details and operational caveats live in [[DEVELOPMENT]] and [[Stack]].

## Human and AI collaboration

The human project owner leads creative direction, game design, game-feel judgment, high-level UX, minigame concepts, prioritization, play evaluation, and release decisions.

AI agents support technical investigation, architecture proposals, planning, implementation, refactoring, testing, documentation, debugging, technical validation, and repetitive production work. Some investigations and validations are shared because an agent can collect evidence while only a human can judge the resulting player experience.

Important uncertainty should become an exploration or design task before a large implementation commitment. Agents must explain unfamiliar Godot, networking, web/mobile, art, audio, optimization, console, and release-pipeline issues without pretending those areas are settled.

## Designer-controlled game feel

Anything that directly affects responsiveness, feedback, timing, motion, audiovisual emphasis, or controller feel must remain easy for a human designer to experiment with.

Relevant tasks must identify:

1. Which values affect player feel.
2. Where each value is exposed.
3. How the human changes it.
4. Whether it can be changed without code.
5. How an implementation agent documents the controls.
6. Which experiments or playtests should evaluate the behavior.

Prefer designer-facing Godot resources, inspector properties, data/configuration assets, or focused editor tools when evidence supports them. This principle does not preselect one technical mechanism for every system. The project-wide convention is defined in [[PS-004 - Define the Game-Feel Tuning Strategy]]; implementation work is tracked in [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]].

## Major known unknowns

- What the first complete gameplay milestone should prove.
- The intended player identity, joining, disconnection, and reconnection experience.
- How session discovery should evolve beyond the current QR/manual-address foundation, especially for consoles and unusual networks.
- How game-feel controls should be organized for fast human experimentation.
- How many physical devices and network conditions are needed for useful routine validation.
- The first minigame's rules, controls, accessibility needs, art direction, audio language, content requirements, and production scope.
- Future console restrictions, packaging, certification, performance budgets, and optional online modes.

## Planning map

- Start work: [[Workflow]]
- Understand task records: [[Task System]]
- See current work: [[Task Index]] or [[Task board]]
- See milestones: [[Releases]]
- Review durable choices: [[Decision Log]]
- Capture a new idea: [[Human Drafts]]
