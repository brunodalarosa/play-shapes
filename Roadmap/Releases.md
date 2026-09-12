# Releases

A release is a meaningful playable proof, not a sprint. The human project owner decides release scope and whether its completion bar has been met.

## Local Connection Proof

**State:** Active; implementation is merged and physical-phone acceptance is pending.

**What this release proves:** A host can start a local Play Shapes session and an ordinary phone on the same LAN can reach the bundled controller page and establish the initial versioned connection without an Internet-hosted service.

**What should be playable:** This is a connection foundation, not a game. The host displays a join URL/QR code and connection feedback; the phone loads the local Hello world controller and connects to the host.

**Completion conditions:**

- The existing automated, Godot-load, and desktop-browser checks remain recorded in [[DEVELOPMENT]].
- At least one physical phone can scan the QR code or enter the local URL, load the bundled page, and connect on a normal private LAN.
- The controller remains legible and usable in portrait orientation.
- Reload/reconnection behavior is observed and any failure is recorded as follow-up work.
- The validation record distinguishes device/network evidence from automated evidence.

**Included managed tasks:**

- [[PS-002 - Validate Phase 1 on a Physical Phone]]

## Next milestone

Not yet named or scoped. [[PS-001 - Define the First Gameplay Milestone]] exists so the human can choose what the first actual gameplay release should prove before related tasks are assigned to it.
