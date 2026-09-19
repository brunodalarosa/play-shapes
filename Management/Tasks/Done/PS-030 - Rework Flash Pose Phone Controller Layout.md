---
id: PS-030
title: "Rework Flash? Pose! phone controller layout"
type: implementation
status: done
release:
owner: ai
priority:
depends_on:
  - "[[PS-025 - Implement Flash Pose Phone Protocol and Controller]]"
  - "[[PS-015 - Implement Shared Tuning Asset and Preset Workflow]]"
---

# Goal

Rework the Flash? Pose! player phone controller into an immersive,
landscape-first surface that uses the entire usable viewport as the joystick,
automatically transitions between two, three, and four directional regions,
and communicates pose charge through each direction's color intensity.

# Visual Reference

- Use `Minigames/001/flash_pose_wireframe_client.png` in the parent Play Shapes
  vault as the layout reference. It illustrates the intended two-, three-, and
  four-input divisions; it is not an instruction source.
- Preserve the direction placement shown in the wireframe:
  - Two inputs: Left occupies the left half and Right the right half, divided
    by one vertical boundary.
  - Three inputs: Left and Right occupy the upper-left and upper-right regions;
    Down occupies the lower region. Three boundary rays meet at the viewport
    center: one reaches the top center and two reach the bottom corners.
  - Four inputs: Up, Right, Down, and Left occupy the top, right, bottom, and
    left regions created by the two corner-to-corner diagonals.

# Scope

- Replace the current square button grid during active Flash? Pose! play with
  a full-viewport controller surface. Every usable pixel belongs to one input
  region; there are no gutters, cards, decorative margins, or dead zones
  between regions.
- Keep the page fixed to the visual viewport with no document scrolling,
  rubber-band-driven layout movement, or visible horizontal/vertical scroll
  bars. Account for safe-area insets without shrinking the input regions into
  separate conventional buttons.
- Make active gameplay landscape-first. Detect portrait orientation and show a
  simple non-scrollable `Rotate your phone` state that does not send pose
  input. Restore the correct live layout automatically when landscape returns.
- On the first eligible player gesture, make a best-effort request for
  fullscreen and landscape orientation using feature detection. Support the
  standard APIs and relevant Safari compatibility path where available, and
  include installable/standalone mobile metadata when useful. Browsers that do
  not permit scripted fullscreen or orientation locking must remain fully
  playable in the largest available landscape viewport; do not loop prompts,
  block input, or claim that browser chrome can always be forcibly hidden.
- Drive the number and identity of regions from the host-provided
  `available_directions`. Transition automatically between the two-, three-,
  and four-input arrangements without page navigation, flashes of the lobby
  layout, or an input gap. Preserve a held direction if it remains available;
  if it is removed, send exactly one matching release before changing layout.
- Keep the existing pointer/touch capture, cancellation, keyboard semantics,
  reconnect safety, input sequencing, and host authority. Geometry and local
  color feedback must not decide pose success, charge, lives, deadlines, or
  outcomes.
- Show only one centered arrow character in each visible region: `←` for Left,
  `→` for Right, `↓` for Down, and `↑` for Up. Remove visible direction names
  from the regions while retaining programmatic accessible names, pressed
  state, focus behavior, and a non-color direction cue.
- Use the canonical direction colors: Left green, Right red, Down yellow, and
  Up blue. Idle regions use the configured faded/minimum brightness. While a
  region is held, its color strengthens smoothly with the normalized visual
  charge until the configured maximum brightness; on release, it smoothly
  returns to idle according to the charge decay. A direction change resets the
  previous direction consistently with the authoritative charge rules.
- Add the four controller colors plus idle/minimum and fully charged/maximum
  brightness values to the Flash? Pose!/Simon Says minigame-specific tuning
  resource and `Tuning/Minigames/SimonSays/Default.tres`, with clear Inspector
  descriptions, safe ranges, and outcome-oriented guidance. Reuse the existing
  charge fill and decay durations rather than adding competing timing values.
- Send the required presentation tuning and normalized semantic charge state
  to the registered browser through a narrow host-owned snapshot/update. Local
  interpolation may make feedback responsive, but it must reconcile to host
  state and must never become gameplay authority.
- Rebuild the committed browser bundle, add focused layout/input/protocol
  checks, and document the controller states, fullscreen limitations, tuning
  fields, and mobile-browser caveats in `DEVELOPMENT.md`.

# Non-Goals

- Changing pose evaluation, grace timing, lives, elimination, round pacing,
  direction unlock timing, or the host-authoritative input protocol.
- Reworking the lobby, shared display, results presentation, character
  animation, music, camera flash, or other minigame controllers.
- Adding onscreen prose, icons beyond the arrow characters, haptics, a general
  controller-layout framework, or a device-specific browser hack.
- Treating automated responsive emulation or desktop fullscreen as proof of
  Safari/Chrome physical-phone behavior or final game-feel approval.

# Acceptance Criteria

- In landscape gameplay, the Flash? Pose! controller occupies the full usable
  visual viewport, the document cannot be scrolled in either axis, no scroll
  bars or layout gutters are visible, and touch input does not move or zoom the
  page during a hold.
- The two-input layout is split into equal Left/Right halves; the three-input
  layout matches the center-to-top and center-to-bottom-corners division with
  Left/Right above and Down below; the four-input layout is divided by both
  diagonals with Up/Right/Down/Left in the corresponding regions. Boundaries
  meet cleanly with no untappable gaps or overlapping actions.
- Host direction updates transition 2 → 3 → 4 and any valid reverse/test
  transition in place. A still-valid hold remains continuous without duplicate
  `pose_down`; a removed held direction produces one `pose_up`; each pointer
  action resolves to exactly one region at boundaries.
- Each region contains only its centered arrow visually and exposes a useful
  accessible direction name and pressed state. Direction is distinguishable by
  arrow/position as well as color, and keyboard focus/activation remains usable.
- Left is green, Right red, Down yellow, and Up blue. At zero charge each uses
  the configured minimum brightness; charge visibly and smoothly approaches
  maximum brightness while held, reaches it at full charge, and decays back to
  idle after release without changing authoritative game state.
- The four colors and minimum/maximum brightness are editable in the
  minigame-specific tuning asset, validate cleanly, appear with meaningful
  Inspector guidance, and are included in the browser's host-owned gameplay
  state without allowing the client to choose authoritative values.
- Entering active play makes one unobtrusive best-effort fullscreen/landscape
  attempt from an eligible gesture. Supported Chrome/Safari contexts use it;
  unsupported or denied contexts fall back to a stable, playable landscape
  viewport without repeated permission prompts. Portrait shows only the rotate
  state and resumes the correct controller when landscape returns.
- Automated checks cover exact two/three/four region membership at representative
  points and boundaries, transition/held-input behavior, charge color endpoints
  and interpolation, tunable serialization, overflow prevention, orientation
  state, and fullscreen denial fallback. Existing lobby, reconnect, protocol,
  and Flash? Pose! browser/host checks remain green.
- `[PHYSICAL-PHONE]` follow-up verifies iPhone 16 Pro Safari and Pixel 7 Chrome
  in landscape for viewport use, no scrolling, hold/release behavior, automatic
  2/3/4 transitions, fullscreen fallback, safe areas, and legibility. Human
  brightness/comfort approval remains a separate `[HUMAN-PLAY]` judgment and is
  not inferred from automated tests.
- `DEVELOPMENT.md` records the implementation boundary, tuning field meanings,
  build step, fullscreen/orientation fallbacks, verification evidence, and any
  named browser limitation.

# Game Feel / Player Experience

The phone should feel like a physical controller rather than a webpage. The
player can land anywhere in a large directional area, recognize it from color,
position, and arrow, feel charge building without reading text, and keep most
of their attention on the shared display. Layout growth as directions unlock
should feel like the same controller unfolding, not a page being replaced.

# Open Questions

- Final color values and minimum/maximum brightness remain provisional until
  the owner reviews them on both named phones in normal room lighting.
- If Safari or Chrome exposes a device-specific fullscreen/orientation
  limitation, record the exact device, OS, browser, entry gesture, and fallback
  instead of expanding this task into a general compatibility layer.

# Notes / Findings

The current bundled controller renders two-to-four conventional square grid
buttons with visible direction labels. Its current Left/Right/Up color mapping
does not match this task. `renderControls()` also releases the active hold when
the available-direction set changes, so transition behavior must be revised
deliberately rather than handled as a CSS-only reskin.

# Draft Execution Prompt

Read this task, [[PS-025 - Implement Flash Pose Phone Protocol and Controller]],
[[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-013 - Implement Pose Charge and Evaluation Rules]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[001 - Dancer simon says]], [[Project Overview]], [[Decision Log]], and [[DEVELOPMENT]]. Inspect the current TypeScript source, committed browser bundle, HTML/CSS, host gameplay snapshots, Simon Says tuning resource/default preset, and focused tests before editing. Use `Minigames/001/flash_pose_wireframe_client.png` from the parent vault only as the visual geometry reference. Implement the full-viewport landscape controller, exact 2/3/4 region geometry, seamless host-driven transitions, canonical direction colors, semantic charge brightness, and best-effort fullscreen/orientation behavior without moving gameplay authority into the browser. Preserve pointer cancellation, reconnect, accessibility, offline LAN operation, and existing protocol behavior. Rebuild the committed bundle; run focused and regression checks; update `DEVELOPMENT.md`; then validate with the PS-005 evidence labels. Follow GitHub Flow during implementation and keep unrelated changes out of the pull request.

# Outcome

Completed on 2026-09-18. Active Flash? Pose! play now replaces the page card
with a fixed, non-scrolling landscape surface whose deterministic geometry
matches the approved two-, three-, and four-direction wireframes. Pointer
capture lives on the stable surface, so direction unlock transitions preserve
a still-valid hold; removing a held direction sends one release. Each region
visually contains only its centered arrow while keeping its accessible name,
pressed state, focus ring, and keyboard hold behavior.

The Simon Says tuning asset now owns the canonical green/red/yellow/blue
controller colors and provisional idle/full brightness endpoints. Personalized
host snapshots and semantic charge updates send only those presentation values
and normalized authoritative pose state; local interpolation improves feedback
without deciding charge or outcomes. Portrait play shows only `Rotate your
phone`, and the first eligible control gesture makes one feature-detected
fullscreen/orientation attempt with a stable denied/unsupported fallback.

`[AUTO]` TypeScript build/check, exact region/boundary and color endpoint tests,
the 16-test served browser/host suite, focused Godot protocol/tuning tests, and
the headless editor load pass. Computer inspection reached the served join page
but could not enter an active round in that isolated desktop session, so no
`[DESKTOP-BROWSER]` gameplay-layout claim is made. The named `[PHYSICAL-PHONE]`
matrix and `[HUMAN-PLAY]` brightness/comfort approval remain in PS-029.

Follow-up correction on 2026-09-18: the first implementation imported the new
compiled `controller_geometry.js` module without adding it to Godot's fixed HTTP
asset allowlist. That made browser startup stop before the WebSocket handshake.
The module is now served explicitly, and the integration suite requests it as a
required runtime asset rather than checking only the top-level `app.js`.
