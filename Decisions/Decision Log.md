# Decision Log

Record durable architectural, production, and game-design choices here so future agents can distinguish intention from incidental implementation. Keep entries concise and link related tasks.

## DEC-001 — Local-network-first normal play

- **Date:** 2026-09-12
- **Decision:** Normal local play must not fundamentally require Internet connectivity. Specific future modes may opt into an Internet requirement when explicitly designed that way.
- **Reason:** The core party-game experience should work in the room where players are gathered.
- **Alternatives:** Internet-hosted sessions as the default were rejected for the core experience.
- **Related tasks:** [[PS-002 - Validate Phase 1 on a Physical Phone]]
- **Revisit:** When defining an online-only mode or platform requirement.

## DEC-002 — Host-authoritative shared game

- **Date:** 2026-09-12
- **Decision:** The computer or console runs the authoritative game and renders the shared world. Smartphone clients send UI actions, choices, and controller input but do not directly mutate authoritative state.
- **Reason:** This keeps rules and trust centralized while allowing thin browser controllers.
- **Alternatives:** Peer-authoritative phones were not selected.
- **Related tasks:** [[PS-003 - Define Join Identity and Reconnection UX]], [[PS-006 - Implement Player Join and Host-Owned Registry]]
- **Revisit:** Only if a future mode has materially different networking needs.

## DEC-003 — Browser-based smartphone controllers

- **Date:** 2026-09-12
- **Decision:** Phones use a normal browser client built with HTML, CSS, and TypeScript/JavaScript, communicating with the host through WebSockets. The host serves required controller files locally.
- **Reason:** Players should join without installing a dedicated controller app, and local play should remain self-contained.
- **Alternatives:** Native phone applications are not part of the current core plan.
- **Related tasks:** [[PS-002 - Validate Phase 1 on a Physical Phone]], [[PS-003 - Define Join Identity and Reconnection UX]]
- **Revisit:** If platform/browser limits prevent an accepted player experience.

## DEC-004 — Godot host runtime

- **Date:** 2026-09-12
- **Decision:** Develop the host game in Godot. The current project targets Godot 4.7 and the GL Compatibility renderer.
- **Reason:** This is the selected engine and current repository baseline.
- **Alternatives:** No engine migration is under consideration.
- **Related tasks:** [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-005 - Define Multi-Phone and Agent Validation Strategy]]
- **Revisit:** Only through an explicit project-level decision.

## DEC-005 — Human ownership of feel, priority, and release calls

- **Date:** 2026-09-12
- **Decision:** The human leads creative direction, game design, gameplay evaluation, game-feel iteration, high-level UX, prioritization, and release decisions. Agents may investigate, recommend, implement, and validate but do not silently make those ownership decisions.
- **Reason:** These choices depend on creative intent and direct evaluation of the player experience.
- **Alternatives:** Fully autonomous product prioritization was rejected.
- **Related tasks:** [[PS-001 - Define the First Gameplay Milestone]], [[PS-004 - Define the Game-Feel Tuning Strategy]]
- **Revisit:** If the human explicitly delegates a bounded decision.

## DEC-006 — Player-feel controls remain designer-accessible

- **Date:** 2026-09-12
- **Decision:** Values that affect responsiveness, timing, motion, feedback, audio balance, haptics, or other player-feel qualities must be deliberately exposed for human experimentation without requiring knowledge of their underlying implementation.
- **Reason:** Generated code is not the end of gameplay iteration; the human must be able to tune and compare behavior efficiently.
- **Alternatives:** Hard-coded feel values inside implementation logic were rejected.
- **Related tasks:** [[PS-004 - Define the Game-Feel Tuning Strategy]]
- **Revisit:** The exposure mechanism may vary by system; the principle remains.

## DEC-007 — Lightweight Markdown planning layer

- **Date:** 2026-09-12
- **Decision:** Use one Markdown note per substantial task, small YAML frontmatter, stable sequential IDs, wikilinks, a manual index, and an embedded Obsidian Base for Kanban. Use only exploration, design, implementation, and validation task types until a demonstrated need arises.
- **Reason:** The system must remain Git-friendly, human-readable, AI-readable, and usable without heavy process or a required query plugin.
- **Alternatives:** Jira-like workflow replication and Dataview-dependent indexing were rejected.
- **Related tasks:** [[Task System]], [[Task Index]], [[Task board]]
- **Revisit:** When repeated friction provides evidence for a small process change.

## DEC-008 — First gameplay proof is one Simon Says dance minigame

- **Date:** 2026-09-12
- **Decision:** Milestone 1 proves one complete 2–10 player loop from the lobby through a Simon Says-style dance minigame, a two-tier results scene, and back to the lobby. One-player start is debug-only. The scoreboard, multi-minigame sequencing, and fake music stops are excluded.
- **Reason:** The milestone should prove a coherent shared-screen and phone-controller experience without expanding into the broader party-game session architecture.
- **Alternatives:** Implementing the scoreboard, sequencing multiple minigames, or adding fake stops in the first gameplay milestone were deferred.
- **Related tasks:** [[PS-001 - Define the First Gameplay Milestone]], [[PS-007 - Define the Gameplay Debug Suite]], [[PS-008 - Design Fake Music Stops]]
- **Revisit:** After Milestone 1 playtesting or when defining the next gameplay iteration.

## DEC-009 — Hybrid detached-sprite character animation

- **Date:** 2026-09-13
- **Decision:** Animate Shape Characters with authored transforms on independent body, face, hand, and foot sprites, shared semantic pose data, and limited procedural bounce/jiggle. Gameplay supplies semantic state and normalized pose charge; animation never decides authoritative outcomes. Skeletal rigging is not used for Milestone 1.
- **Reason:** Detached parts need precise, readable silhouettes and playful secondary motion but gain little from bone weighting or limb deformation. The hybrid keeps poses authorable, reusable, tint-compatible, and maintainable while preserving a clean gameplay boundary.
- **Alternatives:** Bone-based cutout rigging was rejected as unnecessary complexity for non-bending detached parts. Pure procedural motion was rejected because it weakens direct control of command silhouettes. Fully hand-authored secondary motion was rejected because it duplicates common bounce and phase behavior.
- **Related tasks:** [[PS-010 - Explore Character Animation Strategy]], [[PS-011 - Implement Hybrid Character Animation Lab]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-013 - Implement Pose Charge and Evaluation Rules]]
- **Revisit:** If the prototype fails human visual review or future characters require bending/deforming connected limbs.
