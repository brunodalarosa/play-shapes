# Human Draft to Validated Learning

Use this workflow for a new minigame, redesign, controller change, platform effort, or other substantial feature. The purpose is to expose important uncertainty early while keeping the process light.

## 1. Human-written draft

The human records the idea informally in `Drafts/`. A few sentences are enough. Preserve the original draft; later conclusions belong in linked planning or task notes. See [[Human Drafts]].

## 2. Planning session

An AI planning agent reads the draft, [[Project Overview]], relevant decisions, current tasks, and the existing implementation before proposing work. Its first goal is understanding.

Ask feature-specific questions about the intended player experience, rules, controls, failure states, feedback, accessibility, networking, host/client behavior, content, risks, and validation. Use the `grill-me` skill when it is available and useful. Do not mechanically ask about every category or try to erase all uncertainty.

Record confirmed conclusions separately from open questions. Create exploration tasks where evidence is missing and design tasks where behavior needs definition.

## 3. Task breakdown

Create small tasks that can be completed and evaluated independently. Use real dependencies only. Avoid broad tasks such as “implement multiplayer.” Every implementation task includes a draft execution prompt and links to its source design decisions.

## 4. Human prioritization

Agents may recommend sequence and dependencies. The human owns priority and release scope. Newly identified work stays in the backlog unless the human promotes or assigns it.

## 5. Execution

Before implementation, the coding agent reads the task and linked sources, inspects the current project, and reports assumptions that would alter scope. It implements only the accepted boundary, preserves conventions, exposes player-feel controls, validates proportionally, and updates planning notes when implementation reveals durable information.

The draft execution prompt is a starting point, not permission to run. Refine it when necessary and begin implementation only in a separate execution session.

## 6. Validation and learning

Code completion does not prove a feature is done. Create or perform the relevant automated, editor, device, network, performance, accessibility, and human play checks. Record the environment and evidence. Human feel/readability judgments cannot be replaced by passing automated tests.

Findings may reopen a task, update a decision, or create focused follow-up tasks.

## Before a planning agent finishes

- Preserve the original draft.
- Link rather than duplicate canonical context.
- Surface consequential assumptions and unanswered questions.
- Identify player-facing and game-feel consequences.
- Leave priority and release assignment to the human unless explicitly directed.
- Update [[Task Index]], [[Releases]], and [[Decision Log]] only where the session changed them.
