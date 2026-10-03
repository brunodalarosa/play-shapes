# Contributor guidance

This directory is the Godot project root. Work on a new local branch and commit implementation changes locally. Do not push or open a pull request until the project owner approves publication.

## Working method

A change has two plans, and they answer different questions.

- **The feature plan is the task.** It says what a player or contributor gets, what counts as done, and which approvals only a person can give. It lives in the planning system under its task ID and belongs to the project owner. It does not say how the code changes.
- **The implementation plan is the branch's.** It says how the code changes to deliver the task. It is written after the task is understood and before any code, and it is approved before implementation starts.

Every non-trivial task runs through the five phases below. Phases 1 and 2 end at a checkpoint: stop and wait for an answer. Scale each phase to the task; a one line plan is a valid plan for a one line change.

### 1. Question the task

- Restate the task in one sentence. If that is not possible, it is not clear enough yet.
- List the loose ends: unstated assumptions, undefined terms, missing acceptance criteria, approvals nobody is named for.
- Push back on a premise that looks wrong, and say so if the task conflicts with the architecture or the visual direction below.
- A gap in the feature plan goes back to the task. Do not fill it with an implementation choice.

"No loose ends, proceeding" is a valid outcome. Do not manufacture questions.

### 2. Plan the implementation

- **Scope**: what is in, what is explicitly out, and which acceptance criteria this branch covers.
- **Changes**: the scenes, scripts, Resources, protocol messages and browser modules touched, added or removed.
- **Ownership**: which node or service owns any new state, and whether a boundary is added: an autoload, a protocol message, an HTTP route, a tuning Resource. Host authority is not negotiable.
- **Forward fit**: sketch how the next minigame, or a plausible next task, would build on this. If it would not fit, the design is wrong now, not later.
- **Risks**: what could break, what is hard to reverse, and what collides with work in progress. A protocol change and a restructured `.tscn` are both expensive to undo and to merge.
- **Budget**: what the change costs the host per frame with ten players, and what it adds per phone in message rate and size. Measure where a test can, estimate where it cannot, and say which.
- **Verification**: which evidence labels phase 4 will produce, and which it cannot and must leave to a person.

If planning shows the task itself should change, stop and say so. Do not reshape the feature inside the implementation plan.

### 3. Implement

- Small, well defined commits. Do not commit a state known to be broken.
- Never add tool or assistant trailers to a commit message: no `Co-Authored-By` line for a tool and no session link.
- Tests land in the commit with the behavior they cover.
- Stay inside the approved plan. Surface what turns up outside it; do not fix it silently.
- Comment the why where the code cannot say it, in a line or two. Do not narrate what the code does, and do not describe the change ("switched to X because Y"): that belongs in the commit message.

### 4. Verify

- Run the checks under Setup and verification, and the focused commands in `DEVELOPMENT.md` for what was touched.
- Report what changed, what was verified under which evidence label, what still needs a person, and what was documented.
- State failures plainly, with output. A task is not done because the code is written.

### 5. Pull request

The phase 4 report is the pull request body, in the shape of [.github/pull_request_template.md](.github/pull_request_template.md). Publication still waits for the owner's approval, as above.

A pull request is history, read later by someone who was not there. Write what is true of the change: no first person, no account of the session, no reference to a chat or a review. The title says what changed, not the branch name. Never add a tool or assistant attribution line, such as "Generated with …", to the title or body. The implementation plan is not committed; what survives of it is the body's decisions and what it left out.

## Architecture and coding

- Godot is the authoritative PC host. Phones are TypeScript/HTML/CSS browser clients over HTTP and WebSockets. Clients send input and choices; only the host changes game state.
- Use typed GDScript where practical, small reusable scenes, composition, signals for loose coupling, and Control/Container nodes for UI. Avoid fixed viewport dimensions and duplicate behavior. Explain complex code in comments.
- Layout is decided by the formatters, not by hand. Run `node tools/format.mjs` before committing: it formats GDScript and the TypeScript, JavaScript, HTML and CSS sources of `web/` and `tools/`, wrapping at 100 characters. Separate the logical steps inside a function with a blank line; the formatters keep those lines but do not add them. When the GDScript formatter refuses a file as "structurally different", it names only the file: the cause is a long chained call or an inline `if`/`else` inside a longer expression, and splitting that statement into shorter ones fixes it. Do not leave the file unformatted.
- Preserve the bundled runtime assets and `web/public/` output. Rebuild the browser bundle after changing `web/src/`.
- Minigame numbers are stable identifiers. 001 was retired; 002 is the first approved game. Never reuse or renumber IDs.
- A Shape Character is a player-owned geometric character with floating hands and feet. Keep poses and expressions readable, including natural blinking and context-appropriate gestures.

## Visual direction

Read game-design-documents/Art Direction.md and apply this to UI, environments, characters, effects, shaders, and animation.

The canonical editable Squircle source and current export tools live in `art/squircle/`. Keep only current source and useful pipeline/review resources there. Prior versions, backups, variant experiments and version comparisons are temporary artifacts: use ignored `scratch/` or `comparisons/` directories and do not commit them or obsolete one-time construction scripts.

## Setup and verification

- Use Godot 4.7.2 or newer with the GL Compatibility renderer, and Node 22 or newer. Run `node tools/setup.mjs` after cloning and whenever a tool may be missing: it checks the required tools, reports the ones some tasks need, and installs `web/` dependencies, Playwright's Chromium and the GDScript formatter. [README.md](README.md#requirements) lists every tool. Set `GODOT_BIN` to a Godot executable when it is not on PATH as `godot`.
- Run `node tools/check.mjs` before reporting a change as verified. It runs every Godot test script, the format check, the tests of `tools/`, the browser type check and tests, confirms `web/public/` matches a fresh build, and plays a shortened Bubbles round with two emulated phones against the real host; it prints one line per failure and writes full output under `test-results/check/`. Pass name filters for a focused run (`node tools/check.mjs bubbles`), `--full` to play that round with every default, and `--release` to add the Windows export test, which needs export templates.
- Run a single Godot script with `godot --headless --path . --script tests/<name>.gd`. For browser work, run `npm run check`, `npm run build`, and `npm test` in `web/`.
- Keep changes scoped. Update `DEVELOPMENT.md` when current setup, architecture, protocols, or verification steps change.
- The vendored `addons/godot_mcp/` editor integration is optional. Enable it in Godot's Plugin settings only when needed; configure your own local MCP client separately. Do not change the third-party addon unless the task calls for it.

See [README.md](README.md) for clone and play instructions and [DEVELOPMENT.md](DEVELOPMENT.md) for implementation details.
