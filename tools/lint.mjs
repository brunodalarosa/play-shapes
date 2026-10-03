#!/usr/bin/env node
// Development-only. Lints the project's GDScript, TypeScript and JavaScript and
// reports every source line longer than the limit, one finding per line.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { root, webDirectory } from "./environment.mjs";
import { formatterPath } from "./gdscript_formatter.mjs";
import { LINE_LENGTH, gdscriptFiles, mayExceedLineLength, webSourceFiles } from "./sources.mjs";

// Temporary: the tests reach into private members of the code they test, which
// this rule reports. Remove this exception when the tests are given proper
// ways in, so the rule covers them again.
const RULES_OFF_IN_TESTS = ["private-access"];

const USAGE = `Usage: node tools/lint.mjs

Lints every GDScript file outside addons/ with the pinned GDScript formatter's
linter, and the TypeScript and JavaScript sources of web/ and tools/ with
ESLint. Reports lines over ${LINE_LENGTH} characters in all of them, and in
the hand-written CSS. Prints one finding per line and fails when
there is any.
`;

/** Lints GDScript files. Returns findings as "file:line: rule: message", or an error. */
function gdscript(linter, files, disabledRules) {
  if (files.length === 0) return { findings: [] };

  const args = ["lint", "--max-line-length", String(LINE_LENGTH)];
  if (disabledRules.length > 0) args.push("--disable", disabledRules.join(","));
  const result = spawnSync(linter, [...args, ...files], { cwd: root, encoding: "utf8" });
  if (result.error)
    return { error: `could not start the GDScript linter: ${result.error.message}` };

  // Each finding is "file:line:rule:severity: message".
  const findings = [];
  for (const line of `${result.stdout}${result.stderr}`.split(/\r?\n/)) {
    const match = /^(.+?):(\d+):([a-z-]+):(?:error|warning): (.+)$/.exec(line);
    if (match) findings.push(`${match[1]}:${match[2]}: ${match[3]}: ${match[4]}`);
  }

  if (result.status !== 0 && findings.length === 0) {
    return { error: `the GDScript linter failed: exit code ${result.status}` };
  }
  return { findings };
}

/** Lints the TypeScript and JavaScript sources with the rules in web/eslint.rules.mjs. */
function eslint() {
  const program = join(webDirectory, "node_modules", "eslint", "bin", "eslint.js");
  if (!existsSync(program)) return { error: 'ESLint is not installed; run "node tools/setup.mjs"' };

  const result = spawnSync(process.execPath, [program, ".", "--format", "json"], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });

  let files;
  try {
    files = JSON.parse(result.stdout);
  } catch {
    const reason = result.stderr.trim().split(/\r?\n/)[0] || `exit code ${result.status}`;
    return { error: `ESLint failed: ${reason}` };
  }

  const findings = files.flatMap((file) => {
    const path = relative(root, file.filePath).split(sep).join("/");
    return file.messages.map(
      (message) => `${path}:${message.line}: ${message.ruleId ?? "syntax"}: ${message.message}`,
    );
  });
  return { findings };
}

/**
 * Reports lines over the limit in the sources Prettier formats, which it cannot always
 * shorten.
 */
function longLines() {
  const findings = [];
  for (const file of webSourceFiles()) {
    const lines = readFileSync(join(root, file), "utf8").split(/\r?\n/);
    for (const [index, line] of lines.entries()) {
      if (line.length <= LINE_LENGTH || mayExceedLineLength(file, line)) continue;

      findings.push(
        `${file}:${index + 1}: max-line-length: Line is too long. ` +
          `Found ${line.length} characters, maximum allowed is ${LINE_LENGTH}`,
      );
    }
  }
  return { findings };
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    process.stdout.write(USAGE);
    return 0;
  }
  if (args.length > 0) {
    process.stderr.write(`Unknown option ${args[0]}\n\n${USAGE}`);
    return 2;
  }

  const linter = formatterPath();
  if (!linter || !existsSync(linter)) {
    process.stderr.write('the GDScript linter is not installed; run "node tools/setup.mjs"\n');
    return 1;
  }

  const scripts = gdscriptFiles();
  const isTest = (file) => file.startsWith("tests/");
  const results = [
    gdscript(
      linter,
      scripts.filter((file) => !isTest(file)),
      [],
    ),
    gdscript(linter, scripts.filter(isTest), RULES_OFF_IN_TESTS),
    eslint(),
    longLines(),
  ];

  const errors = results.flatMap((result) => result.error ?? []);
  for (const error of errors) process.stderr.write(`${error}\n`);
  if (errors.length > 0) return 1;

  const findings = results.flatMap((result) => result.findings);
  if (findings.length === 0) {
    process.stdout.write("No lint findings.\n");
    return 0;
  }

  for (const finding of findings) process.stdout.write(`${finding}\n`);
  process.stdout.write(`${findings.length} lint findings\n`);
  return 1;
}

process.exitCode = main();
