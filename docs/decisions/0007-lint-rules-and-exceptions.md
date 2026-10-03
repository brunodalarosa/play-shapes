# 0007. Lint rules and their exceptions

Decided by the project owners on 2026-10-03.

## Situation

The formatters cannot shorten a long string or catch a mistake. A linter can, but three of its findings could not be fixed without a worse result.

## Decision

GDScript is linted with the GDQuest formatter's linter, and TypeScript and JavaScript with ESLint's recommended rules. Every source line stays within 100 characters. Both commands cover the files git knows about, and a script no rule covers is itself a finding.

Three exceptions stand. The `private-access` rule is off for `tests/`, because the tests reach into private members in over a hundred places. A line of an HTML file may be long, because an attribute value cannot be split. The line that opens a test with its title may be long, because splitting the title re-indents the whole test.

## What follows

- The `private-access` exception is temporary. It ends when the tests are given proper ways into the code they test.
- A long line is shortened by naming part of the expression, by parentheses, or by joining strings, never by rewording a message.
