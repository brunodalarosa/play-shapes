# Task System

Use one Markdown file per substantial task in `Tasks/`. The system intentionally tracks only the information needed to understand, assign, execute, and evaluate work.

## Task types

- `exploration`: reduce uncertainty through research, comparison, experiments, or paper prototypes. Owner may be human, AI, or shared.
- `design`: define intended behavior or experience before implementation. Its output is normally documentation.
- `implementation`: make a bounded change to the actual product. It must include a draft execution prompt.
- `validation`: determine whether behavior, quality, or player experience meets an explicit expectation.

Do not add a new type until recurring work clearly fails to fit these four.

## Statuses

- `backlog`: identified but not selected for active work.
- `ready`: sufficiently understood and unblocked; this does not assign priority.
- `in-progress`: currently being worked.
- `blocked`: selected work cannot continue until a named condition changes.
- `done`: acceptance criteria are met and the outcome is recorded.

## Ownership and priority

`owner` is `human`, `ai`, or `shared`. Ownership identifies the expected executor, not who decides priority. The human project owner controls priority and release scope. Leave `priority` and `release` blank until the human chooses them; do not infer urgency from a task's ID or file order.

## IDs, filenames, and links

- Assign the next unused sequential ID: `PS-001`, `PS-002`, and so on.
- IDs never encode type, release, status, or priority and are never reused.
- Name files `PS-### - Short Task Title.md`.
- Link dependencies and related work with Obsidian wikilinks.
- Add a dependency only when work genuinely should not begin before another task's result exists.

## Required task shape

```yaml
---
id: PS-###
title: Short task title
type: exploration | design | implementation | validation
status: backlog | ready | in-progress | blocked | done
release:
owner: human | ai | shared
priority:
depends_on: []
---
```

Follow the frontmatter with these sections:

1. `Goal`
2. `Scope`
3. `Non-Goals`
4. `Acceptance Criteria`
5. `Game Feel / Player Experience` when relevant
6. `Open Questions`
7. `Notes / Findings`
8. `Draft Execution Prompt` for every implementation task, and for other tasks only when useful
9. `Outcome`, left empty until completion

Acceptance criteria must be observable. Open questions should remain unanswered rather than being filled with guesses.

## Implementation prompt minimum

Every implementation task's draft prompt tells the coding agent to:

- Read the task and linked design/decision documents first.
- Inspect the existing implementation before changing it.
- Respect project instructions and conventions.
- Implement only the stated scope and avoid unrelated refactors.
- Keep game-feel parameters designer-accessible.
- Add appropriate tests and distinguish automated evidence from live/editor/device evidence.
- Update relevant Markdown when implementation discoveries affect planning.
- Report assumptions and deviations.
- Summarize what changed and how the human can tune player-facing values.

## Lifecycle

1. Create a backlog task with blank priority and, unless explicitly assigned, blank release.
2. Refine its goal, boundaries, questions, and acceptance criteria.
3. The human assigns priority/release and moves it to `ready` when appropriate.
4. The executor moves it to `in-progress` and records findings in the same file.
5. If blocked, record the precise blocker and required resolution.
6. When acceptance criteria are met, fill `Outcome`, capture durable decisions in [[Decision Log]], create only necessary follow-ups, and move the task to `done`.
7. Keep [[Task Index]] synchronized. [[Task board]] reads the same frontmatter automatically.
