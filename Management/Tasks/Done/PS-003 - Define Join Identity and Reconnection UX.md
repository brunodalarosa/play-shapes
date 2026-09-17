---
id: PS-003
title: Define join identity and reconnection UX
type: design
status: done
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define how a person becomes a player and how the host and phone explain connection changes before player identity is implemented.

# Scope

- Define the session-scoped identity lifecycle for a browser player.
- Map host and phone behavior for initial connection, name entry, acceptance, rejection, disconnection, recovery, explicit leave, capacity, and host restart.
- Define the relationship between a temporary browser connection, stable player identity, and browser-held reconnect token.
- Define the minimum public roster information, private phone information, accessibility requirements, and actionable feedback states.
- Refine [[PS-006 - Implement Player Join and Host-Owned Registry]] without adding a general networking framework or a late-join queue.

# Non-Goals

- Implementing protocol messages or a player registry.
- Implementing the future “connect now to join next minigames” queue.
- Deciding gameplay consequences when a player is absent during a particular minigame.
- Designing gameplay controller inputs.
- Solving Internet matchmaking, accounts, cross-household identity, or persistent profiles.
- Selecting a console networking solution.

# Acceptance Criteria

- A readable state flow covers the scoped happy path and important failure/recovery paths.
- Host and phone behavior is specified for each state.
- Player identity is explicitly distinguished from connection identity.
- Name rules, lobby capacity behavior, leave/rejoin behavior, reconnect grace, and host-restart expectations are decided.
- Player-facing copy/feedback requirements and proportionate validation expectations are documented.
- The approved design is sufficient to refine [[PS-006 - Implement Player Join and Host-Owned Registry]].

# Game Feel / Player Experience

Connection delay, retry timing, timeout timing, confirmation feedback, error persistence, and transition timing affect perceived responsiveness. PS-006 keeps the existing provisional values, exposes the new 60-second reconnect grace period and 20-player capacity through host settings, and documents the values until [[PS-004 - Define the Game-Feel Tuning Strategy]] establishes the broader convention.

# Approved Design

## Session and identity

- A host process creates one session identity. The in-memory player registry survives Godot scene changes while `SessionHost` remains alive.
- A host restart creates a new session. Player records and reconnect tokens from the previous session are invalid.
- `connection_id` identifies one WebSocket connection and may change on every reconnect or reload.
- `player_id` is an opaque host-generated identity that remains stable for the player during the current session.
- The browser stores an opaque reconnect token and the last-used name in `localStorage`. The token provides session continuity, not Internet-grade authentication; local-network play remains trusted-room software.

## Join flow

1. The browser establishes the existing versioned transport handshake and optionally presents its stored reconnect token.
2. A valid token resumes the existing player automatically. The phone shows its joined state and the host restores the connection association.
3. A first-time browser, an expired token, or a token from an older host session shows a name form. The last-used name may be prefilled after a host restart or expired grace period, but the player submits it again.
4. The host validates the name and automatically accepts a valid join. No host approval step is required.
5. The host rejects invalid names, duplicate names, and new joins when the 20-player capacity is full. Duplicate names use the exact actionable copy `Name already in use`.
6. A successful join creates or updates the host-owned player record and shows the player as connected on the shared display and phone.

## Disconnect, recovery, and leave

- A normal socket loss, page reload, screen lock, or brief Wi-Fi loss is treated as an uncertain disconnect. The host marks the player as reconnecting and reserves the slot for 60 seconds.
- A reconnect with the valid token before expiry restores the same `player_id`, name, and slot. No connection-quality meter is needed; use actionable states such as connecting, joined, reconnecting, and expired.
- After 60 seconds, the host removes the player record and the token can no longer resume it. A new join may use the released capacity and name.
- A phone `Leave`/`Change player` action removes the record immediately and invalidates its token. Closing a page without that action cannot be assumed to be deliberate leave.
- A single browser token represents one player. Multiple tabs are not a supported way to create multiple players; the implementation should keep one active connection per resumed player and resolve a duplicate resume deterministically.

## Host restart and gameplay boundary

- After a host restart, phones may reconnect to the new session but cannot resume an old player. They show a session-restarted message, prefill the prior name where possible, and require a new join submission.
- New players join through the lobby only. The future “connect now to join next minigames” queue is explicitly deferred. Until that feature exists, a new join during active gameplay receives an actionable game-in-progress response.
- Existing players may reconnect during gameplay. The player registry reports connection state; each minigame separately decides the gameplay consequence of temporary absence.

## Shared display and phone information

- The shared display shows the public player roster, names, join order or seat, and actionable connection states such as connected or reconnecting.
- The phone shows its own name, join/reconnect state, validation errors, and leave/change-player action. It does not need to show other players or connection quality.
- Status must not depend on color alone. Name input needs a visible label, usable focus and tap targets, and an `aria-live` status region for connection and validation feedback.

# Open Questions

- The exact future queue design and its relationship to gameplay phase remain a separate task.
- Gameplay consequences of a disconnected player remain owned by each minigame design.
- [[PS-004 - Define the Game-Feel Tuning Strategy]] may later reorganize where timing values are exposed; PS-006 uses the existing host settings convention until then.

# Notes / Findings

The Phase 1 protocol currently assigns a connection ID after a versioned `hello` message. It has no player identity, player names, or authoritative player registry. The existing transport limit remains 32 connections; PS-006 adds a separate default player capacity of 20 and a 60-second player reconnect grace period.

# Draft Execution Prompt

Read [[PS-003 - Define Join Identity and Reconnection UX]], [[Project Overview]], [[Decision Log]], [[DEVELOPMENT]], and current host/browser connection behavior. Facilitate a design session centered on the player journey and recovery states. Explain technical tradeoffs in plain language, distinguish decisions from open questions, and produce documentation detailed enough to refine the linked implementation task. Do not write code or silently choose release scope or priority.

# Outcome

Approved by the project owner on 2026-09-14. The design uses a session-scoped host-owned `player_id`, an ephemeral transport `connection_id`, and a browser-held reconnect token. Valid names are automatically accepted; duplicate names are rejected with `Name already in use`; the player cap is 20; disconnected players retain their slot for a tunable 60-second grace period; explicit leave removes them immediately; host restart starts a fresh session; and no next-minigame join queue is included. [[PS-006 - Implement Player Join and Host-Owned Registry]] is the single bounded implementation task.
