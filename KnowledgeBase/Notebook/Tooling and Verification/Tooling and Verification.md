---
area: Tooling and Verification
tags: [hub]
code: [tools/check.mjs, tools/format.mjs, tools/lint.mjs, tools/docs.mjs, tools/kb_staleness.mjs, tools/setup.mjs, TestScript]
verified: 2026-10-31
branch: feature/knowledge-base
---

# Tooling and Verification

Area hub. Parent: [[Notebook]]. The Node tools that set up, format, lint, check and build the
project, and the evidence rules for saying a change works.

## Notes

- [[Running the Game]]: running the host, joining from a phone, starting a round.
- [[Verification]]: evidence labels, the check command, focused checks per area.
- [[Formatting and Linting]]: what each tool covers, including the document rules.
- [[Branching]]: the branches and how a change travels.
- [[Standalone Build]]: the portable Windows package.
- [[Debug Menu]]: the F12 launcher and labs.

## Rules

- **`node tools/check.mjs` is the only meaning of `[AUTO]` verified.** Use name filters for
  focused runs, `--full` for extended coverage, `--release` for the Windows export.
- Evidence labels never imply one another: `[AUTO]`, `[EDITOR]`, `[GODOT-RUNTIME]`,
  `[DESKTOP-BROWSER]`, `[PHYSICAL-PHONE]`, `[EXPORTED-BUILD]`, `[HUMAN-PLAY]`. What still
  needs a person goes into [[Pending Reviews]].
- Before committing code: `node tools/format.mjs`, then `node tools/lint.mjs`. Lines are 100
  characters or fewer.
- Test scripts extend `TestScript` and put their body in `_run()`. Any logged error fails the
  script, and so does anything still held at exit.
- Run `node tools/setup.mjs` in a fresh worktree before formatting, linting or checking.
- `node tools/docs.mjs` checks every document and this vault; `node tools/kb_staleness.mjs`
  lists vault pages to re-verify.

## Gotchas

- **Known Windows flakes count as failures, reported separately**: some Tilt Shift tests exit
  `3221225477` at native shutdown with zero failures, and the bundle rewrite can hit a
  user-mapped-section lock ([[Roadmap#Known bugs]]).
- Close any running host before the browser suite (ports 18080/18081; the end-to-end test
  uses 18200/18201).
