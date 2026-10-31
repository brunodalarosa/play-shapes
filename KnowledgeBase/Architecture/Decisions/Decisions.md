---
tags: [hub]
---

# Decisions

Why the project is the way it is. Each record is one decision: the situation that called
for it, what was decided, and what follows from it. The other documents say what is true
now; these say why.

## When to write one

Write a record when a change makes a choice between real alternatives and the reason will
not be visible in the code or the documents. A fact that the documents already state, such
as a port number or a frame count, needs no record.

- One decision per file, named `NNNN-short-title.md` with the next free number.
- Say who decided and when, then give the three sections below.
- A record is not edited to change its decision. A new record replaces it and says which
  one it replaces; the old one gets a line pointing to the new one.

```markdown
# NNNN. The decision in a few words

Decided by ... on YYYY-MM-DD.

## Situation

What called for a decision, and the alternatives.

## Decision

What was decided.

## What follows

- What this commits the project to, and what it rules out.
```

## Records

| Number | Decision |
| --- | --- |
| [[0001-evolve-the-code|0001]] | Evolve the code; rewrite a part when that makes it better |
| [[0002-one-check-command|0002]] | One command defines verified |
| [[0003-setup-checks-tools|0003]] | The setup script checks tools; it does not install them |
| [[0004-end-to-end-test|0004]] | The end-to-end test drives the real game |
| [[0005-test-layers-and-boot|0005]] | End-to-end tests go through boot; quick tests do not |
| [[0006-formatters|0006]] | Formatters: the GDQuest formatter and Prettier, at 100 characters |
| [[0007-lint-rules-and-exceptions|0007]] | Lint rules and their exceptions |
| [[0008-bots|0008]] | Bots that fill a game are wanted |
| [[0009-ticket-free-and-true-now|0009]] | No ticket numbers; documents say what is true now |
| [[0010-no-mdns|0010]] | Phones find the host by IP address, not by name |
| [[0011-local-https-trust|0011]] | Local HTTPS never changes trust by itself |
| [[0012-no-service-worker|0012]] | No service worker and no cache on the phone |
| [[0013-shared-input-tuning|0013]] | Phone and host share one input tuning |
| [[0014-rejected-actions-are-dropped|0014]] | A rejected jump or fall is dropped, and a fall passes one surface |
| [[0015-one-folder-per-minigame|0015]] | One folder per minigame |
| [[0016-bundle-the-phone-client|0016]] | Bundle the phone client into one file |
| [[0017-one-input-message|0017]] | One message for gameplay input |
| [[0018-ui-with-containers|0018]] | Screens are rebuilt with containers, keeping their design |
| [[0019-typed-classes|0019]] | Typed classes inside the host; dictionaries only at the edges |
| [[0020-roadmap-in-the-repository|0020]] | The plan lives in the repository |
| [[0021-no-cloud-ci|0021]] | No cloud CI for now; verification is local |
| [[0022-git-flow|0022]] | Git Flow: `main` holds releases, `develop` holds the work |
| [[0023-shared-test-base|0023]] | Test scripts share one base of our own, and any logged error fails them |
| [[0024-minigame-catalog|0024]] | The minigame catalog is an explicit list of definitions that hold paths |
| [[0025-tilt-shift-rules|0025]] | Tilt Shift owns rounds and uses complete paddle assignment searches |
| [[0026-tilt-shift-physics|0026]] | Tilt Shift shares native physics and integrates a delivery budget |
| [[0027-calibrated-multiplayer-motion|0027]] | Calibrated multiplayer motion uses physical gravity phase |
| [[0028-tilt-shift-editor-workshop|0028]] | Tilt Shift edits isolated drafts and previews ordinary gameplay |
| [[0029-tilt-shift-session|0029]] | Tilt Shift carries prepared calibration through its normal gameplay flow |
| [[0030-tilt-shift-round-preparation|0030]] | Tilt Shift prepares selected players inside each mapped round |
| [[0031-tilt-shift-initial-calibration|0031]] | Tilt Shift waits for initial calibration before a skipped-panel countdown |
| [[0032-mandatory-pre-minigame-screen|0032]] | Every normal minigame starts at the shared Pre-minigame screen |
| [[0033-plaza-lobby-plane-simulation|0033]] | The 3D Playground lobby simulates its characters on a 2D plane |
| [[0034-bubbles-3d-jolt-plane|0034]] | Bubbles and jellyfishes 3D simulates on Jolt with plane-locked bodies |
| [[0035-phone-three-js|0035]] | The phone draws 3D with three.js, loaded only when a 3D screen needs it |
| [[0036-tilt-shift-3d-generated-paddle|0036]] | Tilt Shift 3D builds its paddles in code with a rounded convex collider |
| [[0037-shape-face-system|0037]] | Shape character faces are composed from parts, with expressions in a stack |
| [[0038-tilt-shift-3d-full-width-frame|0038]] | Tilt Shift 3D fills the full width and raises its floor for the bins |
| [[0039-minigame-session-scripts|0039]] | A minigame that prepares its players names a session script in the catalog |
| [[0040-cubio-live-previews|0040]] | Cubio uses one animated model in gameplay and setup |
| [[0041-rooftop-logo-sign|0041]] | The logo is a 3D sign on the café roof, and the billboard shows only the QR |
| [[0042-plaza-lobby-jolt-plane|0042]] | The Playground lobby simulates its characters on Jolt with plane-locked bodies |
| [[0043-cubio-shape-face|0043]] | Cubio's face is the shape face system, drawn on an anchor in the model |
| [[0044-one-face-style|0044]] | Every shape face is named for its emoji and drawn to the originals' measurements |
| [[0045-shared-face-frame|0045]] | Every shape face shares one frame and scale |
| [[0046-shape-face-for-every-character|0046]] | Every Shape Character wears the shared shape face |
| [[0047-shared-deterministic-simulation|0047]] | Phone-predicted characters run a shared deterministic simulation, not Jolt |
| [[0048-predicted-input-carries-a-tick|0048]] | Predicted input carries a simulation tick, settled one window behind the host |
| [[0049-minimum-players-per-minigame|0049]] | Each minigame sets its own minimum number of players |
| [[0050-random-order-for-exact-ties|0050]] | Exact ties in gameplay results may be settled at random |
| [[0051-dithered-overlap-on-a-shared-plane|0051]] | Characters sharing a plane take depth slots, and the one in front dithers |
| [[0052-a-workshop-for-every-minigame|0052]] | Every minigame has a workshop built on one shared design |
| [[0053-boot-steps-and-entry-points|0053]] | Every launch runs one boot made of Essential and Optional steps |
| [[0054-workshop-phone-view-in-godot-wry|0054]] | The workshop phone view is the real phone page in a godot-wry web view |
| [[0055-material-design-3-for-workshops|0055]] | Workshops follow Material Design 3 |
| [[0056-podium-arrivals-teleport|0056]] | Flappy Race finishers teleport to the podium instead of flying there |
