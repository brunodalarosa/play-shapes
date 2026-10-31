---
tags: [hub]
code: []
verified: 2026-10-31
branch: feature/knowledge-base
---

# Notebook

Working notes, agents first. Parent: [[Home]]. Read the hub of the area a task touches, then
the notes for the systems involved.

## Areas

| Hub | Covers |
| --- | --- |
| [[Host and Session]] | boot, `SessionHost`, services, registry, message routing |
| [[Phone Client]] | the web client, its build, motion input and HTTPS |
| [[Playground Lobby]] | the plaza, the platform motor and Cubio |
| [[Minigames]] | the catalog, the Ready screen, and one folder per minigame |
| [[Workshops and Tuning]] | presets, the selector and the workshop window |
| [[Art Pipeline]] | sources in `art/` and verified copies in `assets/runtime/` |
| [[Tooling and Verification]] | setup, format, lint, check, builds and evidence |

Across areas: [[Codebase]] (where each part lives), [[Improvements]] (friction),
[[Roadmap]] and [[Pending Reviews]].

## Note conventions

- One note per system, in its area folder, linked from the area hub. Start from
  [[System Note]].
- What goes in: what cost real effort to find, what a reader would get wrong after reading the
  code, and knowledge people share. Point to where to start reading rather than describing
  what the code does.
- Terse and factual. **Bold the rules that cause bugs when ignored.**
- Friction goes in the note's `## Friction and improvements` section, or in [[Improvements]]
  when it isn't specific to one system. A recurring item gets another `Seen:` date.
- When an Architecture doc covers the system, link it instead of re-explaining it.
- A minigame's folder is its own: only its hub has a fixed shape ([[Minigame Hub]]).
