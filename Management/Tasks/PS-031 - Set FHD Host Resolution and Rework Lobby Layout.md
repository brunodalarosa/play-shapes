---
id: PS-031
title: Set FHD host resolution and rework lobby layout
type: implementation
status: done
release:
owner: ai
priority:
depends_on: []
---

# Goal

Set the host game's default rendering/window resolution to 1920×1080 (FHD)
with a 16:9 aspect ratio, then recompose the Godot lobby so the information
fits in a compact horizontal layout without requiring a lobby scrollbar at
normal 16:9 sizes.

# Scope

- Add explicit Godot project settings for a 1920×1080 default viewport/window
  and preserve a 16:9 presentation when the host window is resized. Preserve
  the current GL Compatibility renderer and responsive stretch behavior unless
  inspection shows a setting must change for the requested result.
- Rework `scenes/lobby.tscn` and its supporting layout code only as needed. Keep
  the `PLAY SHAPES` title green, horizontally centered, and visually centered
  at the top of the lobby.
- Replace the current vertically stacked lobby composition with two horizontal
  sections below the title:
  - Left section: `Lobby playground · Phase 1`, `Join session`, QR code,
    connection instructions, join address, address selection/refresh controls,
    and `Copy link`.
  - Right section: `Players`, player count, empty/active roster, `Start
    minigame`, and its explanatory/status text.
- Use Godot `Control`/`Container` layout relationships, anchors, minimum sizes,
  and responsive spacing rather than hard-coded viewport coordinates. Keep the
  two sections visually balanced and readable at both 1920×1080 and the
  existing 1152×648 16:9 size.
- Remove the lobby's current default scrolling presentation. The lobby should
  not show a scrollbar in its normal empty state or while showing a realistic
  roster. If the maximum roster needs denser presentation at a shorter 16:9
  height, compact the spacing or arrange roster entries into multiple readable
  columns instead of bringing back a page-level scrollbar.
- Preserve existing lobby behavior: LAN address refresh/selection, QR updates,
  copy-link behavior, player-list updates, start-button availability, and
  navigation into Flash? Pose!.
- Update `DEVELOPMENT.md` with the new project resolution settings, the lobby
  layout structure, any responsive thresholds or roster-layout decision, and
  the verification evidence.

# Non-Goals

- Do not change browser phone-controller layout, shared Flash? Pose! gameplay,
  networking, player-capacity rules, QR generation, or lobby behavior beyond
  the host display composition.
- Do not replace the existing visual identity, recolor the title away from
  green, introduce a new art direction, or add decorative content that makes
  the lobby taller.
- Do not solve overflow by silently clipping the QR code, controls, player
  names, start controls, or status text.
- Do not hard-code a single screenshot-sized layout or remove responsive
  behavior just to make one editor viewport pass.

# Acceptance Criteria

- `project.godot` contains explicit default viewport/window settings for
  1920×1080, and the effective default presentation is 16:9. Existing
  `canvas_items`/`expand` behavior is preserved unless a documented,
  evidence-based adjustment is required.
- In the lobby scene, `PLAY SHAPES` remains green and centered across the top.
  The title does not become left-aligned as a side effect of the two-column
  layout.
- Below the title, the join/QR/link group is visibly aligned to the left and
  the player/start/status group is visibly aligned to the right. The groups
  read as two intentional sections rather than one long vertical stack.
- At 1920×1080 and 1152×648, the initial lobby shows all required content
  without a visible vertical or horizontal scrollbar, clipped controls, or
  unexpected overlap. The 1152×648 check is required because it represents
  the current host size while the default is being raised to FHD.
- A roster-growth check with representative joined players, including the
  maximum supported roster when practical, keeps names and start/status
  controls readable without reintroducing a lobby scrollbar. If a compact or
  multi-column roster is used, its reading order and alignment remain clear.
- The QR code remains large enough to scan in the intended host setup, and the
  address picker, `Refresh`, and `Copy link` controls remain usable in the
  left section.
- Existing lobby behavior remains functional: address refresh and selection
  update the join address and QR code, copying copies the current link, roster
  updates remain visible, and the start button retains its existing enabled /
  disabled rules and scene transition.
- Automated checks and a Godot/editor or runtime visual inspection are reported
  separately. The visual inspection explicitly covers both 16:9 sizes and a
  roster-growth state; automated checks are not presented as visual-layout or
  physical-device evidence.
- `DEVELOPMENT.md` records the implementation details, any layout trade-offs,
  verification results, and known caveats for future agents.

# Game Feel / Player Experience

The host should understand the lobby at a glance: the green game title anchors
the screen, joining information and the QR code form one left-side action area,
and the current players plus start state form one right-side status area. The
screen should feel deliberately compact and stable at 16:9 rather than like a
mobile-oriented page that happens to run on the host.

# Open Questions

- If a full 20-player roster is too tall for a 1152×648 host window after
  reasonable typography and spacing, choose between a compact single-column
  roster and a readable multi-column roster based on the existing visual
  language. Record the choice in `DEVELOPMENT.md`; do not make the lobby
  scrollable solely to preserve the current vertical list.

# Notes / Findings

- The current `scenes/lobby.tscn` places all content under
  `Scroll/Center/Billboard`, including the title, join controls, roster, and
  start controls.
- The current lobby has a `ScrollContainer` covering the viewport. This task
  should replace that default composition with a responsive horizontal layout,
  not merely hide the scrollbar while allowing content to remain vertically
  oversized.
- The current scene labels are `Lobby playground · Phase 1`, `Copy link`,
  `Players`, `Start minigame`, and `StartHelp`; preserve their meaning and
  existing signal/script behavior.
- `project.godot` currently declares stretch mode `canvas_items` and aspect
  `expand` but does not explicitly declare the requested viewport dimensions.

# Draft Execution Prompt

Read this task, [[Project Overview]], [[Workflow]], [[Task System]], [[Decision Log]],
[[DEVELOPMENT]], and the project-root `AGENTS.md` before changing anything.
Inspect the current `project.godot`, `scenes/lobby.tscn`, `scenes/lobby.gd`,
boot flow, relevant tests, and any existing visual-check conventions first.
Implement only the FHD host-resolution and lobby-layout scope in this task;
avoid unrelated refactors and preserve the authoritative networking and lobby
behavior.

Set explicit 1920×1080 project defaults with a 16:9 presentation, then use
responsive Godot Control/Container layout to keep the title centered at the
top and divide the remaining content into the specified left join section and
right player/status section. Remove the lobby's default scroll presentation.
Keep the maximum-roster case readable at the shorter 1152×648 16:9 size by
using compact spacing or a clearly readable roster arrangement, never by
clipping content or hiding an overflow problem. Preserve QR generation, LAN
address selection, refresh, copy-link, roster updates, start availability, and
scene navigation.

Run relevant automated checks, perform Godot/editor or runtime visual checks at
1920×1080 and 1152×648 with both an empty lobby and roster-growth state, and
report `[AUTO]` and visual evidence separately. Do not claim physical-phone,
browser, or human game-feel evidence from this host-only layout check. Update
`DEVELOPMENT.md` with the final layout structure, resolution settings,
responsive decisions, caveats, and exact verification results. Report any
assumptions or deviations, summarize the changed files, and explain which
player-facing values/layout constants a human can tune. Follow the repository's
normal GitHub Flow instructions when implementing the task and keep unrelated
changes out of the work.

# Outcome

