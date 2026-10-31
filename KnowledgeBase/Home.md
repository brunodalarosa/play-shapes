---
tags: [hub]
code: []
verified: 2026-10-31
branch: feature/knowledge-base
---

# Home

The Play Shapes knowledge base: what the code doesn't say. Where things are, rules, traps,
design intent and the reasons behind decisions. It lives in the repository, so it branches and
merges with the code. Open `KnowledgeBase/` as a vault in Obsidian, or read it as Markdown.

Play Shapes is a local-network party game. A Godot PC host is the single authority; phones
are a bundled TypeScript web client the host serves on the LAN. Players join by QR, pick a
Cubio colour and a name, gather in the Playground lobby and play minigames together.

## Sections

- [[Notebook]]: working notes, agents first. Short and dense, read on almost every task.
- [[Architecture]]: explanations, humans first. How systems are meant to work and why, plus
  every [[Decisions|decision record]].
- [[External]]: the outside documentation the project relies on, and how far to trust it.

Start a task from the area hub: [[Host and Session]], [[Phone Client]], [[Playground Lobby]],
[[Minigames]], [[Workshops and Tuning]], [[Art Pipeline]] or [[Tooling and Verification]].
Project state is in [[Roadmap]] and [[Pending Reviews]].

## Conventions

- **Stale is worse than missing: when the code disagrees with a page, the code wins.** Fix the
  page in the same change as the code.
- What stays out: what the code states plainly (signatures, class lists, call graphs), logs of
  what was done on a task, personal preferences and anything machine-specific.
- Page names are unique across the vault, so `[[Name]]` means `Name.md` wherever it lives.
  Link liberally: a link to a page that doesn't exist yet marks a gap.
- Code references go in backticks, by symbol or path, never by line number.
- Diagrams are Mermaid. Images go in `_Attachments/`, or in a minigame's own folder.
- Paragraphs, list items and table rows stay under 600 characters, and no ticket numbers
  appear anywhere. `node tools/docs.mjs` checks both, plus links and frontmatter.

## Frontmatter

| Property | Meaning |
| --- | --- |
| `tags` | one of `hub`, `system`, `architecture`, `reference`, `decision`, `stub` |
| `area` | the Notebook area of a note |
| `level`, `parent`, `status` | for Architecture docs: `macro`/`system`/`implementation`, the doc one level up, `draft`/`reviewed` |
| `code` | the main symbols or paths the page relies on, spelled exactly as in the code |
| `verified`, `branch` | when and where the page was last checked against the code |

`stub` marks a page moved in from the old `docs/` folder and not yet re-checked against the
code. `node tools/kb_staleness.mjs` reads `code` and `verified` and lists pages to re-check.

## Templates

[[System Note]], [[Architecture Doc]], [[Minigame Hub]], [[Minigame Design Doc]] and
[[Tuning Experiment]], in `_Templates/`.

## Glossary

- **Cubio**: the one player character, a bevelled cube with floating hands and feet. Earlier
  designs had several shape bodies; Cubio is now the only one.
- **Playground lobby**: where players gather after joining, steering their Cubio around a 3D
  café plaza until the host starts a minigame.
- **Minigame**: one game mode, with a stable number. Minigames share building blocks so the game
  feels consistent across very different mechanics.
- **Pre-minigame screen**: the shared Ready screen in front of every normal minigame launch.
- **Workshop**: a minigame's design window, where its presets are edited against the real game.
