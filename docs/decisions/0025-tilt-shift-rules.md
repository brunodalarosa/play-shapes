# 0025. Tilt Shift owns rounds and uses complete paddle assignment searches

Implementation plan approved by the project owner on 2026-10-04.

## Situation

Physics, motion, phones and presentation need the same assignments, deadline and scores.
Balanced counts can conflict with spatial separation. Greedy allocation cannot
distinguish an unavoidable compromise from an avoidable poor assignment.

## Decision

An ordinary host controller owns shift rules. Typed Resources describe content and
typed copies publish state. Consumers use its round tokens and registered ball handles;
they do not maintain competing scores. Every catch independently checks the deadline.

Enumerate count-constrained mappings of five paddles at round boundaries. Minimize
neighbor conflicts, then prefer changed ownership among equal optima. Quotas rotate;
one/five teammates retain fixed ownership. Report the exact minimum and actual pairs.

## What follows

- The small search replaces a greedy heuristic without per-frame assignment work.
- Each handle belongs to a shift generation/round; stale callbacks cannot score later.
- Resource graphs are deeply copied, including external presets, to freeze live content.
- Signals publish committed state and reject reentrant mutations. Consumers clear old
  balls and start the next round after the finishing call returns.
- No generic bus, framework, extra autoload or wire message is needed for this foundation.
- The geometric optimum certifies control separation, not strategy, collisions or feel.
