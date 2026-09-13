---
id: PS-002
title: Validate Phase 1 on a physical phone
type: validation
status: done
release: Local Connection Proof
owner: shared
priority:
depends_on: []
---

# Goal

Close the remaining gap between desktop/automated Phase 1 evidence and the real experience of joining from a physical phone on the same local network.

# Scope

- Run the merged host build from the Godot project.
- Use at least one physical phone on the same private LAN.
- Scan the displayed QR code or enter the displayed URL.
- Observe page loading, WebSocket connection feedback, host connection feedback, portrait readability, reload, and reconnection.
- Record device, browser, network conditions, evidence, failures, and follow-up tasks.

# Non-Goals

- Adding player names, stable player identity, controller input, characters, or a minigame.
- Changing firewall, router, or VPN configuration without a separate explicit decision.
- Treating a desktop browser or automated test as physical-phone evidence.
- Expanding this check into a comprehensive device compatibility matrix.

# Acceptance Criteria

- The phone reaches the host through the LAN URL without an Internet-hosted controller service.
- The bundled page displays and completes the versioned Hello world connection.
- The host's connection feedback changes consistently with the phone connection.
- The page is legible and operable in portrait orientation at normal handheld distance.
- Reload and a brief loss/recovery scenario are observed; the result is recorded whether they pass or fail.
- The validation note records the phone, operating system, browser, LAN setup, observed results, and any caveats.
- Failures produce focused follow-up tasks rather than silent scope expansion.

# Game Feel / Player Experience

Evaluate join clarity, perceived delay, QR readability from the intended room distance, phone-page legibility, connection-state feedback, and whether recovery feels understandable. No responsiveness target has yet been approved; record observations instead of inventing one.

# Open Questions

- Is one phone sufficient to close this foundational release, or does the human want a second platform represented?
- Which brief recovery scenario should be standard: page reload, screen lock/unlock, Wi-Fi toggle, or host restart?
- What room distance should be used for QR readability checks?

# Notes / Findings

Existing evidence is documented in [[DEVELOPMENT]]: build/type checks, six integration tests, Godot load/runtime checks, desktop Chrome connection, and desktop reconnection passed. These do not satisfy this task.

# Draft Execution Prompt

Read [[PS-002 - Validate Phase 1 on a Physical Phone]], [[Releases#Local Connection Proof]], and the Phase 1 verification and troubleshooting sections of [[DEVELOPMENT]]. Guide the human through a bounded physical-phone check, collect the specified evidence, and update only Markdown findings and follow-up task notes. Do not change implementation files or claim automated/desktop evidence proves phone behavior.

# Outcome
