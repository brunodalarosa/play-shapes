# 0001. Evolve the code; rewrite a part when that makes it better

Decided by the project owners on 2026-10-03.

## Situation

The project has to support many minigames built from shared parts, and quick iteration on each. An architecture review found the stack sound and one layer missing: a framework for minigames, covering a catalog, a shared round lifecycle, a stage kit, and an input pipeline with reusable controls.

## Decision

The host stays Godot with GDScript and the phones stay plain TypeScript. The missing layer is built into the existing code step by step, keeping the game playing the same throughout.

This is a default, not a ban. Where rewriting a part would make it better than reshaping it, rewriting that part is a valid choice.

## What follows

- Each refactor step is a small change that leaves every check passing.
- A proposal to rewrite a part says why reshaping it would be worse.
