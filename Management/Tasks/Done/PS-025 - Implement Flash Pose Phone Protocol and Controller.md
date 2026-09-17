---
id: PS-025
title: "Implement Flash? Pose! phone protocol and controller"
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]]"
  - "[[PS-006 - Implement Player Join and Host-Owned Registry]]"
  - "[[PS-013 - Implement Pose Charge and Evaluation Rules]]"
  - "[[PS-024 - Implement Flash Pose Host Round Controller]]"
---

# Goal

Extend the existing versioned WebSocket and bundled browser controller so a
registered phone can play Flash? Pose! with press-and-hold directional input
while the host remains authoritative for timing, charge, lives, and outcomes.

# Scope

- Add the post-handshake message adapter for `pose_down` and `pose_up`,
  validating direction, active-minigame phase, player ownership, and
  `input_seq` before forwarding a narrow action to PS-024. Free posing remains
  active while music plays; only evaluation is grace-window-bound. Host receipt
  time is authoritative; ignore client-authored player IDs and timestamps.
- Add host-to-browser state messages for minigame start/countdown, challenge
  start, per-player pose result/lives, exact elimination copy, results, and
  return-to-lobby. Send a current snapshot after a valid reconnect without
  restoring a held pointer lost by disconnect; an uninterrupted pointer may
  remain held across a genuine stop.
- Keep transport handshake `protocol: 1` and the existing hello/join/leave/
  reconnect behavior. New players remain lobby-only; existing players may
  resume but cannot join a new place in the middle of a round.
- Add the phone journey to the current offline HTML/CSS/TypeScript client:
  waiting/watch state, two-to-four large square controls, pointer/touch
  capture and release/cancel cleanup, success/failure/lives feedback,
  elimination, results, and lobby return.
- Give every pose region a text/accessible label plus a distinct icon and
  color. Prevent accidental page scrolling or double-submit behavior while a
  region is held, and keep the control usable with one thumb.
- Add focused protocol/browser tests for valid holds, releases, duplicate and
  late messages, malformed actions, reconnect snapshots, elimination, and
  simulated coverage up to ten connected players. Rebuild the committed
  `web/public/app.js` from `web/src/app.ts`.

# Non-Goals

- Deciding pose success, changing charge, applying lives, ranking, or
  advancing the round; those remain host/controller responsibilities.
- Rendering the shared screen, characters, music, camera flash, or results
  groups; those belong to [[PS-026 - Implement Flash Pose Shared Screen Feedback and Results]].
- Adding a new transport protocol version, authentication system, client-side
  player identity, simulated-player runtime, or next-minigame queue.
- Claiming physical-phone usability or accessibility approval from desktop
  browser tests.

# Acceptance Criteria

- A registered browser can receive the current Flash? Pose! phase and send
  only its own valid `pose_down`/`pose_up` actions throughout the active
  minigame. Inputs animate free poses while music plays; the host grace window
  alone decides stop outcomes. The client cannot choose a player, target,
  deadline, charge, life, or outcome.
- Pressing and holding one region sends a bounded start action, releasing or
  cancelling sends a matching release, and a new direction is visible without
  duplicate held inputs. Unknown/late/duplicate/out-of-order actions do not
  mutate the authoritative state.
- The browser shows a clear non-game waiting state, a usable two-, three-, or
  four-input grid, result/lives feedback, the exact text `You've been
  eliminated :(` when eliminated, and a lobby state after return.
- Reconnect receives a current snapshot, preserves the host-owned player
  identity, clears local pointer state lost by disconnect, and does not invent
  or resume a held input after reconnect. An uninterrupted pointer remains
  held across a genuine stop and continues to drive the character pose.
- Existing hello/join/leave/reconnect tests remain green, TypeScript builds and
  checks, and focused browser/host tests cover at least ten simulated clients.
- Host protocol and browser automated evidence is labeled `[AUTO]` or
  `[DESKTOP-BROWSER]`; no such result is described as `[PHYSICAL-PHONE]` or
  `[HUMAN-PLAY]` evidence.
- `DEVELOPMENT.md` documents message shapes, ownership, client states,
  pointer cancellation behavior, the bundled build step, and known mobile
  caveats.

# Game Feel / Player Experience

The phone should stay peripheral: the player can find a large icon-and-label
region with one thumb, hold it, and return attention to the shared display.
Explicit state copy prevents a silent network or elimination state from being
mistaken for a missed pose. The controller may provide immediate local visual
press feedback, but only host results change the authoritative lives display.

# Open Questions

- Human two-phone review should assess whether persistent holds and the
  confirmed reconnect behavior feel fair; do not add latency compensation
  based only on desktop tests.
- If a device/browser exposes a touch-capture limitation, record the named
  device and create a focused compatibility follow-up rather than adding a
  broad input abstraction.

# Notes / Findings

The current `web/src/app.ts` only handles lobby identity and has no gameplay
controls. The current `WebsocketService` stores transport clients privately and
does not broadcast gameplay messages, so the implementation must add a narrow
host-owned adapter rather than letting the scene inspect `_clients`.

# Draft Execution Prompt

Read this task, [[PS-019 - Plan the 001 - Dancer Simon Says Minigame Implementation]], [[PS-024 - Implement Flash Pose Host Round Controller]], [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-006 - Implement Player Join and Host-Owned Registry]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], [[Decision Log]], and
[[DEVELOPMENT]]. Inspect the current WebSocket service, registry mapping,
browser source/public build, and tests before editing. Implement only the
host-owned message adapter and the bundled phone press-and-hold states. Keep
protocol version 1, reject client-authored authority fields, route timing and
outcomes through the round controller, handle pointer cancellation and
reconnect snapshots, and preserve offline/local-network behavior. Rebuild
`web/public/app.js`, run focused browser/host checks, document message shapes
and mobile caveats, and distinguish automated/desktop evidence from physical
phone and human-play evidence. Follow GitHub Flow and keep unrelated changes
out of the pull request.

# Outcome

Completed on 2026-09-17. The protocol-1 WebSocket service now resolves each
registered connection to its host-owned player, rejects authority-shaped or
malformed pose packets, and forwards only validated direction/held/sequence
actions with host receipt time to the PS-024 controller. Controller signals
produce personalized phase snapshots, challenges, pose results/lives, exact
elimination copy, rankings, and lobby return. Reconnect embeds a current
snapshot while disconnected held input remains cleared; new players remain
lobby-only during a round.

The committed offline TypeScript controller keeps two-to-four accessible square
hold regions available from minigame start through completion, including while
music plays, with pointer capture and all cancellation
paths, authoritative result/lives feedback, elimination, results, and lobby
return. Focused `[AUTO]` Godot and served-bundle checks cover valid, duplicate,
late, malformed, reconnect, elimination, and ten-client cases. TypeScript
build/check and the full browser/host suite pass. No `[DESKTOP-BROWSER]`,
`[PHYSICAL-PHONE]`, accessibility approval, or `[HUMAN-PLAY]` claim is made.
