---
id: PS-005
title: Define multi-phone and agent validation strategy
type: design
status: done
release:
owner: shared
priority:
depends_on: []
---

# Goal

Define a practical evidence model for agent-generated gameplay and networking changes so routine checks are reliable without pretending automation replaces devices, the Godot editor, or human play judgment.

# Scope

- Separate pure logic, protocol, integration, Godot load/runtime, browser, physical-device, LAN, performance, accessibility, and human playtest evidence.
- Recommend a minimum routine device/network matrix and when broader coverage is warranted.
- Define how to capture reproducible environments, logs, screenshots, timings, failures, and caveats.
- Define validation expectations for authoritative state, malformed client input, disconnect/reconnect behavior, and simultaneous phones.
- Define when implementation completion must create a separate human validation task.

# Non-Goals

- Implementing test harnesses, CI, device farms, telemetry, or profiling tools.
- Choosing console certification requirements before a console target is selected.
- Requiring every test layer for every task.
- Treating subjective game-feel evaluation as an automatable pass/fail check.

# Acceptance Criteria

- A small validation matrix maps change risk to the evidence expected.
- The strategy states what agents can verify independently and what needs human/device participation.
- Routine multi-phone scenarios, device/network recording, and failure reproduction are defined.
- Automated, editor, desktop-browser, physical-phone, exported-build, and human play evidence use distinct labels.
- Guidance explains when a failed check blocks completion and when it creates follow-up work.
- Any desired tooling is captured as separate, bounded tasks rather than implemented here.

# Game Feel / Player Experience

The strategy must preserve observations about responsiveness, feedback timing, readability from couch distance, phone attention, accessibility, and group play. Where timings or thresholds are measured, connect the measurement to a human experiment rather than declaring the feel correct from numbers alone.

# MVP Validation Strategy

The MVP routine device matrix is deliberately small and concrete:

- Host: the Godot project running on the owner's computer over normal home Wi-Fi.
- Phone A: iPhone 16 Pro, with Safari as the default physical-phone browser.
- Phone B: Pixel 7, using Chrome.
- Browser spot check: iPhone 16 Pro Chrome is exercised when a browser-facing change affects compatibility, layout, storage, or connection behavior. It does not require a third simultaneous phone.
- Routine simultaneous target: two phones. Larger playtests are future coverage and are not required to close the MVP strategy.
- Routine network: host and phones on the normal private home Wi-Fi. VPN, guest-network isolation, hotspot, packet shaping, and unusual multi-interface setups are escalation coverage, not MVP gates.

## Risk-to-evidence matrix

| Change or risk | Minimum evidence | Who can provide it | Completion rule |
| --- | --- | --- | --- |
| Pure rules, identity, protocol, malformed input, or deterministic data | `[AUTO]` focused tests with assertions and logs | Agent | Required when the changed behavior is covered by the task; a failed assertion blocks the related implementation. |
| Godot scripts, scenes, resources, or Inspector-facing settings | `[EDITOR]` editor-load/Inspector evidence and, where relevant, `[GODOT-RUNTIME]` host execution | Agent can collect technical evidence; human reviews feels or visuals | Parse/load failures block. Visual or feel claims remain human-owned. |
| Browser source, bundled assets, or host/browser integration | `[AUTO]` build/check/integration results plus `[DESKTOP-BROWSER]` for visible desktop behavior | Agent | Required for changed paths. Desktop evidence never counts as phone evidence. |
| Phone layout, touch behavior, QR/address reachability, WebSocket recovery, or simultaneous real clients | `[PHYSICAL-PHONE]` two-phone routine scenario using the MVP matrix | Human performs the physical check; agent may guide and record | Required for a player-facing networking or mobile change unless an existing validation task explicitly covers it. Missing or failed required evidence blocks that acceptance claim. |
| Export filters, packaged assets, or release-build startup | `[EXPORTED-BUILD]` run from the actual export | Agent can run the host check; human must check phones when the export changes phone-facing behavior | Required when export configuration or release packaging changes. Editor success does not substitute for it. |
| Performance, latency, responsiveness, readability, accessibility, or group play | Measured `[AUTO]`/`[GODOT-RUNTIME]` evidence where useful, followed by `[HUMAN-PLAY]` for the experience | Agent measures; human judges | Numbers describe conditions and trends; they do not declare game feel correct. A required human review cannot be silently replaced by a benchmark. |

## Routine two-phone scenarios

Use the smallest scenario that exercises the changed risk. The normal pair is the iPhone 16 Pro in Safari and the Pixel 7 in Chrome. Repeat with iPhone Chrome for browser-facing changes.

1. Start the host on normal home Wi-Fi and record the selected reachable address, build mode, Godot version, and renderer.
2. Open the displayed URL or scan the QR code on both phones. Join with two distinct names and confirm that each phone shows its actionable joined state and that the shared display shows both authoritative player records.
3. When the change touches identity, session, or connection lifecycle, reload one phone and observe reconnecting/resumed behavior within the configured grace period. Record what was observed rather than inventing a universal timing target.
4. When the change touches simultaneous gameplay input, perform the smallest two-player action sequence that exercises both clients. Confirm outcomes from the shared host state, not from client display alone.
5. Repeat the relevant step in iPhone Chrome when the browser spot check applies. Do not imply that testing both browsers on one phone proves Android/iOS coverage beyond the named devices.

Malformed JSON, unsupported actions, client-selected identity fields, capacity boundaries, duplicate resume, and other adversarial protocol cases remain `[AUTO]` checks. They should not be treated as manually proven merely because two phones joined successfully.

## Evidence labels and report shape

Every reported result uses one or more of these labels and keeps them separate:

- `[AUTO]` — deterministic unit, protocol, integration, browser-build, or scripted checks.
- `[EDITOR]` — Godot editor load, Inspector, scene, or editor-visible evidence.
- `[GODOT-RUNTIME]` — the host or game running on the current computer, including debug scenarios.
- `[DESKTOP-BROWSER]` — a desktop browser, including an in-app browser viewport.
- `[PHYSICAL-PHONE]` — a named real phone and browser on a real network.
- `[EXPORTED-BUILD]` — the actual exported host build, not an editor run.
- `[HUMAN-PLAY]` — human judgment of feel, readability, accessibility, group coordination, or fun.

Each record should include:

```text
Label(s):
Date/time:
Revision or branch:
Host: OS, Godot version, renderer, editor/export mode, network mode
Clients: device model, OS version, browser/version, orientation
Scenario and exact steps:
Player count:
Result: pass / fail / not-run / blocked
Artifacts: log, screenshot, recording, or test-results path
Caveats and follow-up:
```

Use ignored `test-results/ps-005/` subfolders for bulky logs, screenshots, and recordings when artifacts are useful. Do not record Wi-Fi passwords, reconnect tokens, or other secrets. A result may only claim the environment named in its record.

## Completion, failure, and follow-up rules

- A failed or missing check blocks completion when it covers an acceptance criterion, the normal MVP path, authoritative state integrity, or a player-facing behavior that the implementation claims to have validated.
- A reproducible failure gets a focused bug or validation follow-up, but the original task remains open when the failed check is required for its acceptance.
- A failure in explicitly deferred coverage—such as more than two players, a guest network, a hotspot, a VPN, an unlisted browser/device, or performance on another machine—does not block the MVP if the required matrix passes. Record the limitation and create a bounded follow-up when it is worth pursuing.
- An environmental failure, such as firewall or client isolation, is not a product pass. Record it as blocked or as an environment follow-up until the required scenario is rerun successfully.
- An implementation task that changes mobile UX, LAN reachability, reconnect behavior, shared-screen readability, accessibility, timing/feel, or export packaging must link an existing suitable human-validation task or create a separate bounded validation task before the related release claim is closed. Purely internal changes do not need a new device task.

## Tooling boundaries

Device farms, automated multi-browser matrices, network emulation, telemetry, profiling infrastructure, and export/CI automation are not part of PS-005. If repeated work justifies any of them, create a separate bounded implementation or exploration task with its own acceptance criteria.

# Open Questions

- What exact iOS, Android, Safari, and Chrome versions should be recorded at each run as the devices update?
- When a future playtest is organized, what larger simultaneous player count and room layout should be added beyond the two-phone MVP matrix?
- Which non-routine network variations, if any, become important enough to promote into a future release gate?

# Notes / Findings

Phase 1 already demonstrates why evidence labels matter: automated integration checks and desktop Chrome passed, while physical-phone behavior remained unverified.

The owner confirmed on 2026-09-15 that the routine physical matrix is an iPhone 16 Pro (Safari and Chrome available) plus a Pixel 7 (Chrome), with two simultaneous phones sufficient for the MVP. The host and phones will use normal home Wi-Fi with no VPN. Larger group playtests are intentionally future work.

The current project already has useful `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`, and `[DESKTOP-BROWSER]` evidence patterns. There is no export preset yet, and physical-phone checks remain owner-performed. Existing PS-002 coverage can be reused for the foundational join path rather than duplicated.

# Draft Execution Prompt

Read [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], [[Decision Log]], [[PS-002 - Validate Phase 1 on a Physical Phone]], [[PS-006 - Implement Player Join and Host-Owned Registry]], and the validation sections of [[DEVELOPMENT]]. Use the confirmed MVP matrix in this task: iPhone 16 Pro Safari/Chrome, Pixel 7 Chrome, two simultaneous phones, and normal home Wi-Fi with the host on Wi-Fi. Inventory current test capabilities, keep evidence labels distinct, and record what remains human-owned. Do not install tools, alter CI, or modify implementation. Leave larger player counts and unusual networks as explicitly bounded future coverage.

# Outcome
