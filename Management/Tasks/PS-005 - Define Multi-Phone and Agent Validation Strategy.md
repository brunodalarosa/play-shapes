---
id: PS-005
title: Define multi-phone and agent validation strategy
type: design
status: backlog
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

# Open Questions

- Which phones and browsers are reliably available to the human for routine checks?
- What simultaneous player count should routine LAN validation target before a gameplay milestone is chosen?
- Which network variations are common enough to test regularly?
- What evidence can agents collect from the Godot editor without interrupting human playtests?

# Notes / Findings

Phase 1 already demonstrates why evidence labels matter: automated integration checks and desktop Chrome passed, while physical-phone behavior remained unverified.

# Draft Execution Prompt

Read [[PS-005 - Define Multi-Phone and Agent Validation Strategy]], [[Project Overview]], [[Decision Log]], and the validation sections of [[DEVELOPMENT]]. Inventory current test capabilities and ask the human which real devices and network setups are routinely available. Produce a proportionate validation matrix and evidence-reporting convention. Do not install tools, alter CI, or modify implementation.

# Outcome
