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
- **Decision:** Use one Markdown note per substantial task, small YAML frontmatter, stable sequential IDs, wikilinks, a manual index, and an embedded Obsidian Base for Kanban. Start with exploration, design, implementation, and validation task types; add a specialized type only when recurring work demonstrates the need.
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

## DEC-010 — Minimal host-side debug scenario launcher

- **Date:** 2026-09-13
- **Decision:** The first debug suite is an F12-toggleable, non-pausing overlay in the host Godot application. It launches named development scenarios, restarts the active debug scenario, and returns to the lobby while preserving LAN services. Debug scenarios display `DEBUG — <scenario name>`. The launcher remains available in exported builds during early development.
- **Reason:** The project needs a fast route into focused experiments without prematurely building a console, simulated-player framework, or broad state editor.
- **Alternatives:** A visible lobby button was rejected in favor of a host-only shortcut. Automatic pause, phone-side debug controls, runtime tuning, simulated players, and general-purpose debugging tools were deferred until a concrete need appears.
- **Related tasks:** [[PS-007 - Define the Gameplay Debug Suite]], [[PS-014 - Implement Minimal Gameplay Debug Launcher]], [[PS-011 - Implement Hybrid Character Animation Lab]]
- **Revisit:** Add capabilities only when active development workflows require them; remove or gate exported-build access before public distribution.

## DEC-011 — Session-scoped browser player identity and reconnect grace

- **Date:** 2026-09-14
- **Decision:** A browser connection keeps its transport `connection_id`, while the host owns a separate session-scoped `player_id`. The browser may store an opaque reconnect token and last-used name locally. The registry survives scene changes but resets on host restart. Valid names are automatically accepted, duplicate names are rejected with `Name already in use`, the player capacity is 20, and a disconnected player reserves its slot for a tunable 60-second grace period. Explicit leave removes the player immediately. New players join through the lobby only; the future next-minigame queue is deferred.
- **Reason:** This gives a small local-party flow that survives ordinary phone interruptions without introducing accounts, persistent profiles, host approval, or a general networking framework.
- **Alternatives:** Using display names as identity, persisting identity across host restarts, allowing duplicate names without a disambiguation rule, and implementing a late-join queue in the registry task were deferred or rejected.
- **Related tasks:** [[PS-003 - Define Join Identity and Reconnection UX]], [[PS-006 - Implement Player Join and Host-Owned Registry]]
- **Revisit:** When the next-minigame queue, persistent profiles, or an online mode is explicitly designed.
- **Implementation:** PS-006 keeps the registry as a typed session-lifetime data owner under `SessionHost`; WebSocket code adapts validated messages to it, the lobby only controls whether new joins are open, and gameplay scenes continue to permit valid resumes.

## DEC-012 — Shared editor-first tuning assets and named presets

- **Date:** 2026-09-14
- **Decision:** Play Shapes uses a shared editor-first tuning system. Each minigame has one umbrella tuning asset shape with grouped sections, reusable concerns live in shared category assets, and a project-level `Active Presets` asset selects the named preset used after relaunch. Every preset has a known-good `Default` baseline, clear human-facing labels and Inspector/Markdown guidance, and automated invariant validation. Cross-platform values share a source only when host and browser genuinely need synchronized behavior; otherwise they remain platform-local.
- **Reason:** A Unity-experienced but Godot-new designer needs to find and change values without reading AI-generated implementation code, while the system remains navigable as the game grows.
- **Alternatives:** One monolithic tuning asset, scattered script constants, runtime-first tuning UI, and Git-history-only experiment copies were rejected or deferred because they reduce discoverability or add unnecessary early complexity.
- **Ownership:** Agents may prepare candidate presets, validation, and experiment notes. Only the human may approve subjective feel, promote a preset to `Default`, or declare an experiment successful.
- **Related tasks:** [[PS-004 - Define the Game-Feel Tuning Strategy]], [[PS-015 - Implement Shared Tuning Asset and Preset Workflow]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-013 - Implement Pose Charge and Evaluation Rules]]
- **Revisit:** After the first tuning foundation and a real Milestone 1 playtest reveal navigation, validation, or cross-platform synchronization friction.

## DEC-013 — Specialized asset and visual-planning task types

- **Date:** 2026-09-15
- **Decision:** The task system adds `asset-hunt`, `asset-rework`, and `wireframes-and-art-mockups` types. Asset hunts and wireframes/art mockups are human-owned for now. Asset rework is normally AI-owned or shared and uses computer-based editing tools; generative image creation is not the default and must be explicitly requested in a task.
- **Reason:** Sourcing, treating, and visually planning content have different ownership, evidence, and completion criteria from general design or implementation work.
- **Alternatives:** Keeping all asset and mockup work under generic design or implementation tasks was rejected because it hides human approval boundaries and asset provenance.
- **Related tasks:** [[Task System]], [[PS-016 - Create Wireframe for 001 - Dancer Simon Says]], [[PS-017 - Find Environment Assets for 001 - Dancer Simon Says]], [[PS-020 - Find Music and SFX for 001 - Dancer Simon Says]]
- **Revisit:** When repeated work shows that ownership defaults, evidence, or additional specialized types should change.

## DEC-014 — Manifest-owned runtime art boundary

- **Date:** 2026-09-16
- **Decision:** Preserve complete supplied and project-created source packs as provenance archives, but ship only manifest-selected, stable-path copies under `assets/runtime/`. Godot ignores source archives; release presets explicitly exclude them. Character bodies, hands, and feet retain shaded Double-resolution sources at half scale with runtime tinting, while faces remain untinted.
- **Reason:** A small explicit runtime set prevents color/resolution variants and future authoring material from becoming accidental imports or release content without destructively rewriting the source archive.
- **Alternatives:** Deleting redundant archive variants, converting art to grayscale, and generating an atlas without measured benefit were rejected.
- **Related tasks:** [[PS-009 - Create and Import Character Feet Assets]], [[PS-012 - Implement Milestone 1 Character Animation System]], [[PS-021 - Implement Curated Runtime Asset Pipeline]]
- **Revisit:** If measured packaging or runtime behavior justifies an atlas, or if a future asset family needs a different derivation policy.
