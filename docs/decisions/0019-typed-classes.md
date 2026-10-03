# 0019. Typed classes inside the host; dictionaries only at the edges

Decided by the project owners on 2026-10-03.

## Situation

Players, results and snapshots are dictionaries in 226 declarations. A misspelled key is found only when that line runs.

## Decision

Data inside the host uses typed classes. A dictionary appears in only two places: where JSON arrives from or leaves for a phone, and where an engine API hands one over. In both, it is converted and validated at once.

## What follows

- The lint command holds a list of the files still allowed to declare a dictionary, and fails when any other file does. The list only shrinks.
- The conversion goes module by module with the refactor, and is tracked in the roadmap until the list is down to the two edges.
