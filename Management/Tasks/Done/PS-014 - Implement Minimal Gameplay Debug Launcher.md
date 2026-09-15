---
id: PS-014
title: Implement minimal gameplay debug launcher
type: implementation
status: done
release: Milestone 1
owner: ai
priority:
depends_on:
  - PS-007
---

# Goal

Implement the smallest reusable host-side debug launcher needed to enter and
repeat Milestone 1 development scenarios without restarting LAN services or
building a general-purpose debug console.

# Scope

- Add an F12-toggleable overlay owned by the host Godot application and available
  from every host scene.
- Keep the underlying scene, animation, clocks, and network services running while
  the overlay is open; do not change global pause state.
- Provide a small scenario registration boundary so a task can add a named launch
  destination without editing unrelated launcher presentation or lifecycle code.
- Initially expose the hybrid character animation lab when its scene becomes
  available through [[PS-011 - Implement Hybrid Character Animation Lab]]. A
  disabled or clearly unavailable entry may exist beforehand; do not invent the
  animation lab inside this task.
- Support immediate restart of the current debug scenario from its clean starting
  state and immediate return to the lobby.
- Preserve the `SessionHost` LAN services and existing connections across launcher
  navigation. Preserve registered players when [[PS-006 - Implement Player Join and Host-Owned Registry]] provides that lifecycle.
- Reserve a one-player Dancer Simon Says entry that becomes enabled only when the
  scenario exists and at least one real registered player is present. Do not use
  raw connection count as player identity and do not create simulated players.
- Show a persistent in-scene marker formatted as `DEBUG — <scenario name>` for
  every debug-launched scenario. Remove it on return to the normal lobby.
- Keep availability enabled in both editor runs and exported builds for this early
  project phase.
- Update [[DEVELOPMENT]] with ownership, registration, navigation, state-preservation,
  input-handling, extension, and validation guidance.

# Non-Goals

- Pausing, time scaling, runtime tuning controls, a command console, live state
  editing, event logs, replay, simulated players, input recording, or forced game
  outcomes.
- Adding debug controls to the phone browser.
- Implementing the animation lab, Dancer Simon Says gameplay, player registry, or
  a new persistent session model as part of this task.
- Hiding or removing debug functionality from exported builds in this iteration.
- Treating debug convenience as multiplayer, physical-phone, or player-experience
  validation.

# Acceptance Criteria

- F12 opens and closes the same overlay from the lobby and every currently
  reachable host scene; the shortcut has no browser-client behavior.
- Opening and closing the overlay does not pause or restart the scene, network
  services, animations, or clocks.
- Selecting a valid scenario changes immediately without confirmation, while
  `SessionHost` remains running.
- Restart reconstructs the active debug scenario's clean state without restarting
  LAN services or intentionally dropping connected/registered players.
- Return to lobby exits debug scenario state, removes the persistent marker, and
  preserves the session/player state supported by the current architecture.
- Debug scenarios display `DEBUG — <scenario name>` continuously and clearly.
- Scenario entries have explicit available/disabled state. One-player Simon Says
  cannot launch from a raw browser connection and requires one registered player
  once the registry API exists.
- Adding the PS-011 animation lab requires only a small scenario registration and
  does not require redesigning launcher lifecycle code.
- Focused automated checks cover registry/availability logic where practical;
  Godot editor/runtime checks cover F12 toggling, navigation, restart, marker
  lifecycle, and LAN-service continuity. Physical-phone and full gameplay checks
  remain separate evidence.

# Game Feel / Player Experience

The launcher should reduce iteration friction without becoming part of normal
play. It must stay fast, obvious, and disposable: one key, a few named actions,
and no nested tooling surface.

# Open Questions

- The eventual scene and registry APIs for one-player Simon Says do not exist yet;
  keep their launcher entries disabled or omit them until integration is real.
- Exported-build removal may become necessary before public distribution, but no
  environment or build-mode system should be added preemptively.

# Draft Execution Prompt

Read [[PS-014 - Implement Minimal Gameplay Debug Launcher]], the approved [[PS-007 - Define the Gameplay Debug Suite]], [[PS-001 - Define the First Gameplay Milestone]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[PS-011 - Implement Hybrid Character Animation Lab]], and [[DEVELOPMENT]]. Inspect the current boot, lobby, SessionHost, scene-change, and input setup before editing. Implement a small F12 host overlay with a narrow scenario-registration boundary, immediate navigation, clean scenario restart, lobby return, persistent scenario naming, and explicit availability. Do not pause the tree, restart LAN services, infer players from raw connections, create simulated players, or add general debug tooling. Make absent future scenarios safely unavailable rather than implementing them here. Add focused checks, validate in the Godot editor/runtime, verify service continuity, and document extension guidance. Follow GitHub Flow and open a pull request.

# Outcome
