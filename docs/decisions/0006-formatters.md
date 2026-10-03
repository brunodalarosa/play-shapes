# 0006. Formatters: the GDQuest formatter and Prettier, at 100 characters

Decided by the project owners on 2026-10-03.

## Situation

The code had no agreed layout, and lines ran to hundreds of characters. Godot has no formatter of its own.

Two GDScript formatters were tried on all 87 scripts. `gdformat` formatted every file in one pass and left fewer long lines, but needs Python. The GDQuest formatter is one small program with an editor addon and frequent releases, but refused five statements and needs repeated passes to settle.

## Decision

GDScript is formatted with the GDQuest formatter, pinned to one version and verified by checksum. TypeScript, JavaScript, HTML and CSS are formatted with Prettier. Both wrap at 100 characters, and the check command fails on an unformatted file.

## What follows

- A statement the formatter refuses is split by hand into shorter ones.
- The format command repeats the GDScript pass until nothing changes.
- If the formatter proves troublesome, `gdformat` is the fallback. Switching means one more repository-wide reformat.
- The existing code is no model for style. Logical steps inside a function are separated by blank lines, which the formatters keep but do not add.
