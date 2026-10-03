# Formatting and linting

The commands that format the code, lint it, and check the documents, and what each one
covers. All three run as steps of `node tools/check.mjs`.

## Formatting

```powershell
node tools/format.mjs           # format everything
node tools/format.mjs --check   # change nothing; list the unformatted files
```

- GDScript: every file outside `addons/`, with the GDQuest GDScript formatter.
- TypeScript, JavaScript, HTML and CSS: the sources of `web/` and `tools/`, with Prettier.
- Both wrap at 100 characters.
- `.editorconfig` states the same rules for editors.
- `.prettierignore` keeps an editor's format-on-save away from compiled and generated files.

Not formatted: Markdown, JSON, Godot's `.tscn` and `.tres` files, the compiled `.js` in
`web/public/`, and the Python art tools.

## The GDScript formatter

Godot has no formatter of its own.

- `node tools/setup.mjs` downloads the pinned formatter version into ignored `local/tools/`
  and verifies it against the SHA-256 recorded in `tools/gdscript_formatter.mjs`.
- Changing the version means recording a new checksum for every platform there, then
  reformatting.
- The formatter runs with its structure check. It refuses a file whose wrapped form it cannot
  prove equivalent, and names only the file.
- So far the cause has always been a long chained call, or an inline `if`/`else` inside a
  longer expression. Splitting that statement into shorter ones fixes it.
- One pass does not always reach its own fixed point, so the command repeats until a pass
  changes nothing.

## Linting

```powershell
node tools/lint.mjs
```

It prints one finding per line and fails when there is any. It runs:

- the GDScript formatter's own linter, over the same GDScript files;
- ESLint, with the recommended JavaScript and typescript-eslint rules, over the TypeScript and
  JavaScript of `web/` and `tools/`;
- a check for lines over 100 characters.

The ESLint rules are in `web/eslint.rules.mjs`, next to the packages they import.
`eslint.config.mjs` at the root re-exports them, so the linter and editors also cover
`tools/`.

## Which files are covered

`tools/sources.mjs` decides which files the format and lint commands cover, from the files
git tracks or would add.

- A folder git ignores, such as an editor's plugins, is never read.
- A TypeScript or JavaScript file that git knows about and no rule covers is reported as
  `uncovered-source`. Code in a new folder therefore cannot go unformatted and unlinted
  unnoticed.
- To resolve that finding, add the folder to `tools/sources.mjs`, or to the places it leaves
  alone on purpose: `web/public/`, `web/src/vendor/`, `addons/` and `art/`.

## Deliberate lint exceptions

- The linter's `private-access` rule is off for `tests/`, where the tests reach into private
  members of the code they test. That is temporary and marked in `tools/lint.mjs`.
- A line of an HTML file may exceed 100 characters, because an attribute value cannot continue
  on another line.
- The line that opens a test with its title may exceed 100 characters, because splitting the
  title makes Prettier indent the whole test body a level deeper.

## Document rules

```powershell
node tools/docs.mjs
```

It checks every Markdown file outside `addons/` and `game-design-documents/`:

- A link inside the repository must point to an existing file, with the exact spelling and
  case, and to an existing heading when it names one.
- No paragraph, list item or table row may be longer than 600 characters.

It also reports a ticket number in any text file or file name. Name the thing itself; nobody
can look a ticket up from the repository.

## Blame

`.git-blame-ignore-revs` lists the commits that only changed layout. GitHub's blame view skips
them. Locally, run this once:

```powershell
git config blame.ignoreRevsFile .git-blame-ignore-revs
```
