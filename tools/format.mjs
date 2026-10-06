#!/usr/bin/env node
// Development-only. Formats the project's GDScript, TypeScript, JavaScript, HTML
// and CSS, or with --check reports the files that are not formatted.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { root, webDirectory } from "./environment.mjs";
import { formatterPath } from "./gdscript_formatter.mjs";
import { LINE_LENGTH, gdscriptFiles, webSourceFiles } from "./sources.mjs";

const GDSCRIPT_PASSES = 5;

const USAGE = `Usage: node tools/format.mjs [--check]

Formats project GDScript, including the owned Tilt Shift workshop addon, with its formatter,
and the TypeScript, JavaScript, HTML and CSS sources of web/ and tools/ with
Prettier. Lines wrap at ${LINE_LENGTH} characters.

  --check   Change nothing; list the files that are not formatted and fail.
`;

/**
 * Runs the GDScript formatter once over files. Returns the unformatted files (check
 * only), or an error.
 */
function runGdscriptFormatter(formatter, files, check) {
  // The structure check makes the formatter refuse a file rather than change what its code means.
  const args = ["--max-line-length", String(LINE_LENGTH), "--verify-structure", "--verbose"];
  const result = spawnSync(formatter, [...args, ...(check ? ["--check"] : []), ...files], {
    cwd: root,
    encoding: "utf8",
  });
  const output = `${result.stdout}${result.stderr}`;
  const unformatted = [...output.matchAll(/^Checking (.+)\.\.\. needs formatting$/gm)].map(
    (match) => match[1],
  );

  if (result.error)
    return { error: `could not start the GDScript formatter: ${result.error.message}` };
  if (result.status !== 0 && unformatted.length === 0) {
    const reason =
      output.split(/\r?\n/).find((line) => /error/i.test(line)) ?? `exit code ${result.status}`;
    return { error: `the GDScript formatter failed: ${reason.trim()}` };
  }
  return { unformatted };
}

/** Formats or checks GDScript. Returns the unformatted files, or an error. */
function gdscript(check) {
  const formatter = formatterPath();
  if (!formatter || !existsSync(formatter)) {
    return { error: 'the GDScript formatter is not installed; run "node tools/setup.mjs"' };
  }

  let files = gdscriptFiles();
  if (check) return runGdscriptFormatter(formatter, files, true);

  // One pass can leave a long expression wrapped in a way the next pass wraps differently,
  // so the files it would still change are formatted again until none is left.
  for (let pass = 1; pass <= GDSCRIPT_PASSES; pass += 1) {
    const formatted = runGdscriptFormatter(formatter, files, false);
    if (formatted.error) return formatted;

    const remaining = runGdscriptFormatter(formatter, files, true);
    if (remaining.error || remaining.unformatted.length === 0) return remaining;
    files = remaining.unformatted;
  }
  const unsettled = files.join(", ");
  return {
    error: `the GDScript formatter did not settle after ${GDSCRIPT_PASSES} passes on: ${unsettled}`,
  };
}

/** Formats or checks the web and tools sources. Returns the unformatted files, or an error. */
function prettier(check) {
  if (!existsSync(join(webDirectory, "node_modules", "prettier"))) {
    return { error: 'Prettier is not installed; run "node tools/setup.mjs"' };
  }

  // Prettier runs in web/, where it is installed, so the files are named from there.
  const files = webSourceFiles().map((file) =>
    file.startsWith("web/") ? file.slice("web/".length) : `../${file}`,
  );
  // --list-different prints one unformatted file per line and nothing else.
  const mode = check ? ["--list-different"] : ["--write", "--log-level", "warn"];
  const prettierProgram = join(webDirectory, "node_modules", "prettier", "bin", "prettier.cjs");
  const result = spawnSync(process.execPath, [prettierProgram, ...mode, ...files], {
    cwd: webDirectory,
    encoding: "utf8",
    env: { ...process.env, NO_COLOR: "1" },
  });
  const errors = result.stderr.trim();
  if (errors) return { error: `Prettier failed: ${errors.split(/\r?\n/)[0]}` };
  if (result.status !== 0 && !check)
    return { error: `Prettier failed: exit code ${result.status}` };

  const unformatted = result.stdout
    .split(/\r?\n/)
    .filter(Boolean)
    .map((file) => file.replaceAll("\\", "/"))
    .map((file) => (file.startsWith("../") ? file.slice("../".length) : `web/${file}`));
  return { unformatted };
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    process.stdout.write(USAGE);
    return 0;
  }
  const unknown = args.find((arg) => arg !== "--check");
  if (unknown) {
    process.stderr.write(`Unknown option ${unknown}\n\n${USAGE}`);
    return 2;
  }
  const check = args.includes("--check");

  const results = [gdscript(check), prettier(check)];
  const errors = results.flatMap((result) => result.error ?? []);
  for (const error of errors) process.stderr.write(`${error}\n`);
  if (errors.length > 0) return 1;

  const unformatted = results.flatMap((result) => result.unformatted);
  if (!check) {
    process.stdout.write("Formatted.\n");
    return 0;
  }
  if (unformatted.length === 0) {
    process.stdout.write("Every file is formatted.\n");
    return 0;
  }

  for (const file of unformatted) process.stdout.write(`${file}\n`);
  process.stdout.write(
    `${unformatted.length} files are not formatted; run "node tools/format.mjs"\n`,
  );
  return 1;
}

process.exitCode = main();
