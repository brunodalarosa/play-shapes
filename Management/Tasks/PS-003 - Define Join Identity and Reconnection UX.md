---
id: PS-003
title: Define join identity and reconnection UX
type: design
status: backlog
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define how a person becomes a player and how the host and phone explain connection changes before player identity is implemented.

# Scope

- Map host and phone states for initial connection, name entry, acceptance, rejection, disconnection, and successful recovery.
- Define the relationship between a temporary browser connection and stable player identity.
- Decide expected behavior for duplicate/invalid names, page reload, screen lock, temporary Wi-Fi loss, deliberate leaving, host restart, and a full lobby.
- Define which information appears privately on the phone and publicly on the shared display.
- Identify accessibility, privacy, latency-feedback, and error-copy requirements.

# Non-Goals

- Implementing protocol messages or a player registry.
- Designing gameplay controller inputs.
- Solving Internet matchmaking, accounts, cross-household identity, or persistent profiles.
- Selecting a console networking solution.

# Acceptance Criteria

- A readable state flow covers the scoped happy path and important failure/recovery paths.
- Host and phone behavior is specified for each state.
- Player identity is explicitly distinguished from connection identity.
- Name rules, lobby capacity behavior, leave/rejoin behavior, and host-restart expectations are either decided or clearly left open.
- Player-facing copy/feedback requirements and validation scenarios are documented.
- The approved design is sufficient to refine [[PS-006 - Implement Player Join and Host-Owned Registry]].

# Game Feel / Player Experience

Connection delay, retry timing, timeout timing, confirmation feedback, error persistence, and transition timing affect perceived responsiveness. Identify them as tunable values, say where the human should eventually adjust them, and propose experiments using ordinary phones without choosing final values prematurely.

# Open Questions

- Is a player name required before the host creates a player record?
- What survives a page reload or brief disconnection, and for how long?
- Can a disconnected player's slot be reclaimed from the host?
- How are duplicate names presented and resolved?
- Should the lobby show connection quality or only actionable connection states?

# Notes / Findings

The merged Phase 1 protocol assigns a connection ID after a versioned Hello message. It has no player identity, player names, or authoritative player registry.

# Draft Execution Prompt

Read [[PS-003 - Define Join Identity and Reconnection UX]], [[Project Overview]], [[Decision Log]], [[DEVELOPMENT]], and current host/browser connection behavior. Facilitate a design session centered on the player journey and recovery states. Explain technical tradeoffs in plain language, distinguish decisions from open questions, and produce documentation detailed enough to refine the linked implementation task. Do not write code or silently choose release scope or priority.

# Outcome
