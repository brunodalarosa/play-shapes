---
id: PS-006
title: Implement player join and host-owned registry
type: implementation
status: backlog
release:
owner: ai
priority:
depends_on:
  - PS-003
---

# Goal

After the join/reconnection design is approved, add the smallest host-authoritative player identity layer that turns a browser connection into a named lobby player while preserving the local-network-first foundation.

# Scope

- Refine this section from the approved outcome of [[PS-003 - Define Join Identity and Reconnection UX]] before moving the task to `ready`.
- Add only the protocol, validation, host-owned player registry, and host/phone presentation required by that approved design.
- Keep transport connection IDs separate from stable player identity.
- Expose any player-facing retry, timeout, transition, or feedback timing according to [[PS-004 - Define the Game-Feel Tuning Strategy]] if that decision is available.
- Add proportionate automated checks and identify required live phone validation.

# Non-Goals

- Gameplay controller input or authoritative minigame state.
- Character selection, persistence across sessions, Internet accounts, matchmaking, or online hosting.
- A general-purpose networking framework.
- Unrelated refactors of the existing HTTP/WebSocket foundation.

# Acceptance Criteria

- These criteria must be refined from the approved design before execution.
- The host remains authoritative for creating, validating, updating, and removing player records.
- Client input cannot directly mutate authoritative state outside explicitly validated messages.
- Connection identity and player identity have distinct documented lifecycles.
- Approved join, rejection, disconnect, and reconnection states are represented consistently on host and phone.
- Relevant feel/feedback values are designer-accessible and documented.
- Automated results and required Godot/browser/physical-phone checks are reported separately.
- [[DEVELOPMENT]] and this task's findings/outcome reflect important implementation discoveries.

# Game Feel / Player Experience

Likely feel-sensitive values include name-validation feedback delay, handshake/join timeout, reconnect grace period, retry cadence, transition duration, and audiovisual confirmation. The approved design must state which apply; implementation must expose and explain them rather than burying them in connection logic. Human validation should evaluate clarity and perceived responsiveness on a real phone.

# Open Questions

- All unresolved behavior in [[PS-003 - Define Join Identity and Reconnection UX]].
- Whether [[PS-004 - Define the Game-Feel Tuning Strategy]] must finish before this task is ready or can supply a smaller interim convention.
- The minimum physical-device scenarios required for acceptance.

# Notes / Findings

This task is intentionally not ready. Its scope and observable behavior depend on PS-003, and its release remains unassigned until the human prioritizes it.

# Draft Execution Prompt

Read this task first and treat it as the source of truth. Then read the completed [[PS-003 - Define Join Identity and Reconnection UX]], relevant entries in [[Decision Log]], [[Project Overview]], [[DEVELOPMENT]], and [[PS-004 - Define the Game-Feel Tuning Strategy]] if completed. Inspect the existing host, lobby, browser client, protocol tests, and project instructions before changing anything. Implement only the refined scope; preserve the host-authoritative model and current conventions; avoid unrelated refactors. Keep all retry, timeout, transition, and feedback values that affect player experience designer-accessible, and document exactly where and how the human can tune them without changing logic. Add proportionate automated validation, run relevant project checks, and clearly separate automated results from Godot editor/runtime, desktop-browser, and physical-phone evidence. Update relevant Markdown when discoveries affect planning. Report assumptions or deviations before making scope-changing decisions, then summarize what changed, known caveats, validation evidence, and all player-facing tuning controls.

# Outcome
