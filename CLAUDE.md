# Claude's working notes

Orientation for a new session. [AGENTS.md](AGENTS.md) is the contract for how work is done
here and wins over anything below. What the project knows lives in the knowledge base: start
at [Home](KnowledgeBase/Home.md), then the hub of the area the task touches.

## The project in brief

A local-network party game. A Godot 4.7.2 PC host is the single authority; phones are a bundled
TypeScript web client served by that host over HTTP and WebSockets on the LAN. Players join by
QR, pick a Cubio colour and a name, and steer their Cubio around the Playground lobby until the
host starts a minigame through the shared Pre-minigame screen.

| Minigame | Hub |
| --- | --- |
| 004 Bubbles and jellyfishes 3D | [004 Bubbles and Jellyfishes](KnowledgeBase/Notebook/Minigames/004%20Bubbles%20and%20Jellyfishes/004%20Bubbles%20and%20Jellyfishes.md) |
| 005 Tilt Shift 3D | [005 Tilt Shift](KnowledgeBase/Notebook/Minigames/005%20Tilt%20Shift/005%20Tilt%20Shift.md) |
| 006 Flappy Race | [006 Flappy Race](KnowledgeBase/Notebook/Minigames/006%20Flappy%20Race/006%20Flappy%20Race.md) |

001, 002 and 003 are retired; numbers are never reused.

## The current endeavor

- The 3D low-poly rework: every scene shares the live 3D Cubio and runs on Jolt with bodies
  locked to one plane. Its intent is in
  [Art Direction](KnowledgeBase/Architecture/Art%20Direction.md).
- Commits for the rework go to `feature/3d-low-poly-project-rework`, as the owner asked;
  Flappy Race work goes to `feature/006-flappy-race-design`.
- Ready-made assets first; author new ones only when strictly necessary.

## Working rules I must not drift from

The full set is in AGENTS.md and the
[Tooling and Verification](KnowledgeBase/Notebook/Tooling%20and%20Verification/Tooling%20and%20Verification.md)
hub. The ones I'm most likely to forget:

- Five phases; phases 1 and 2 end at a checkpoint where I stop and wait. The implementation
  plan is never committed.
- Commit locally in small, working steps. Never push or open a pull request without the
  owner's approval. Commit messages carry no tool or assistant trailers.
- Format, then lint, before committing; `node tools/check.mjs` is the only meaning of `[AUTO]`.
- No ticket numbers anywhere. Decisions go in numbered records, never edited to change a
  decision; the next free number is in
  [Decisions](KnowledgeBase/Architecture/Decisions/Decisions.md).
- At the end of a task, propose knowledge base learnings and friction; write them only after
  the owner approves.

## This machine

- Windows 11; Bash and PowerShell are both available. `GODOT_BIN` points at
  `C:\Users\backup pc\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe`; there is no
  `godot` on PATH. Node is v24. Blender 5.2 is at
  `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
- Run `node tools/setup.mjs` in a fresh worktree before formatting, linting or checking.
- The repository root is also opened as an Obsidian vault (its `.obsidian/` is ignored); the
  shared vault is `KnowledgeBase/`.
