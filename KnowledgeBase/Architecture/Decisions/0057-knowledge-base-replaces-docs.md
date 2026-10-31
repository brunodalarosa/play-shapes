---
tags: [decision]
decided: 2026-10-31
---

# 0057. The knowledge base replaces docs/

Decided by the owner on 2026-10-31.

## Situation

The project's documents lived in `docs/`, with design documents in a nested
`game-design-documents/` folder, decision records in `docs/decisions/`, and more guides as
READMEs beside the code. Agents read them on almost every task, but nothing told an agent which
page to read for an area, pages had no anchors to the code they describe, and nothing flagged a
page whose code had moved on.

The alternatives were to keep `docs/` and add an index, or to make `docs/` an earlier attempt
at a knowledge base and reorganize it into one.

## Decision

`KnowledgeBase/` is an Obsidian vault in the repository that replaces `docs/`. It has a
Notebook for agents, one hub per area and one folder per minigame, Architecture for people,
with the decision records, and Reference for outside documentation. Pages link by unique name
with wikilinks and carry frontmatter that names their kind, their code anchors and when they
were last verified.

## What follows

- New documentation is a vault page. `docs/` no longer exists, and READMEs beside the code
  are one-line pointers into the vault.
- Each minigame's folder takes whatever shape it needs; only its hub follows the shared
  Minigame Hub template.
- `node tools/docs.mjs` checks wikilinks and frontmatter; `node tools/kb_staleness.mjs` lists
  pages to re-verify.
- Architecture docs are owned by people: an agent's edit stays a draft.
- Agents propose what they learned at the end of a task, and write it only once the owner
  approves.
