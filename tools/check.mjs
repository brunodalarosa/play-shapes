#!/usr/bin/env node
// Development-only. Runs every automated check and reports each failure in one line.
// Full output for every check is written under test-results/check/.
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import {
  exportTemplatesFolder,
  godotBinary,
  godotTemplateName,
  godotVersion,
  missingWindowsTemplates,
  root,
  webDirectory,
} from "./environment.mjs";
import { godotFailureLines, withoutLevel } from "./godot_output.mjs";
import { includeGodotTest } from "./check_selection.mjs";

const logDirectory = join(root, "test-results", "check");
const GODOT_TIMEOUT_MSEC = 180_000;
const WEB_TIMEOUT_MSEC = 300_000;
const E2E_TIMEOUT_MSEC = 900_000;

// Needs an installed export and writes builds/, so it only runs with --release.
const RELEASE_TESTS = { standalone_build_editor_integration_test: ["--editor"] };

const USAGE = `Usage: node tools/check.mjs [--full] [--release] [filter ...]

Runs the Godot test scripts, the format, lint and document checks, the tests
of these tools, the browser type check and tests, verifies that web/public
matches a fresh build, then plays Bubbles and Tilt Shift with two emulated phones against the
real host.

  filter      Run only checks whose name contains one of the filters,
              for example "bubbles", "web" or "e2e".
  --full      Add larger Tilt Shift phone rosters, workshop preview and
              extended rotation contacts; play Bubbles at full length.
  --release   Also run the Windows export test. Needs Godot export templates.
`;

function run(command, args, { cwd = root, timeout, shell = false, env = process.env } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { cwd, shell, windowsHide: true, env });
    let output = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill();
    }, timeout);
    child.stdout.on("data", (chunk) => {
      output += chunk;
    });
    child.stderr.on("data", (chunk) => {
      output += chunk;
    });
    child.on("error", (error) => {
      clearTimeout(timer);
      resolve({ code: -1, output, timedOut, spawnError: error });
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({ code, output, timedOut });
    });
  });
}

function writeLog(name, output) {
  writeFileSync(join(logDirectory, `${name}.log`), output);
  return `test-results/check/${name}.log`;
}

/** The folders that hold Godot test scripts: tests/ and the tests/ of each minigame. */
function godotTestFolders() {
  const ofMinigames = readdirSync(join(root, "minigames"), { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => `minigames/${entry.name}/tests`)
    .filter((folder) => existsSync(join(root, folder)));

  return ["tests", ...ofMinigames];
}

/** Lists the test scripts in those folders, by name. */
function godotTests(full, release) {
  return godotTestFolders()
    .flatMap((folder) =>
      readdirSync(join(root, folder))
        .filter((file) => file.endsWith("_test.gd") || file === "foundation.gd")
        .map((file) => ({ name: file.slice(0, -".gd".length), script: `res://${folder}/${file}` })),
    )
    .filter(({ name }) => includeGodotTest(name, { full, release }))
    .sort((a, b) => (a.name < b.name ? -1 : 1));
}

async function runGodotTest({ name, script }) {
  const extra = RELEASE_TESTS[name] ?? [];
  const args = ["--headless", ...extra, "--path", root, "--script", script];
  const result = await run(godotBinary, args, { timeout: GODOT_TIMEOUT_MSEC });
  const log = writeLog(name, result.output);
  if (result.spawnError)
    return `could not start Godot (${result.spawnError.code}); run "node tools/setup.mjs"`;
  if (result.timedOut) return `timed out after ${GODOT_TIMEOUT_MSEC / 1000} s (${log})`;
  const errors = godotFailureLines(result.output, { editor: extra.includes("--editor") });
  if (result.code === 0 && errors.length === 0) return "";
  const reason = errors[0] ? withoutLevel(errors[0]) : `exit code ${result.code}`;
  const more = errors.length > 1 ? ` (+${errors.length - 1} more)` : "";
  return `${reason}${more} (${log})`;
}

/** Returns a message when the Windows export templates the release test needs are absent. */
function missingExportTemplates() {
  if (process.platform !== "win32") return "the standalone builder supports only a Windows host";
  const { error, text } = godotVersion();
  const templateName = godotTemplateName(text);
  if (error || !templateName)
    return `could not read the Godot version (${error || text}); run "node tools/setup.mjs"`;
  const folder = exportTemplatesFolder(templateName);
  return missingWindowsTemplates(folder).length === 0
    ? ""
    : `Godot export templates are not installed in ${folder}; ` +
        "install them from Editor > Manage Export Templates";
}

function npm(script, { timeout = WEB_TIMEOUT_MSEC, env = process.env } = {}) {
  // npm is a .cmd shim on Windows, which Node only starts through a shell.
  return run(`npm run --silent ${script}`, [], { cwd: webDirectory, timeout, shell: true, env });
}

async function webTypes() {
  const result = await npm("check");
  const log = writeLog("web-types", result.output);
  if (result.code === 0) return { failure: "" };
  const first =
    result.output.split(/\r?\n/).find((line) => /error TS\d+/.test(line)) ??
    `exit code ${result.code}`;
  return { failure: `${first.trim()} (${log})` };
}

/** Runs a tool that prints one problem per line and a summary on its last line. */
async function listing(name, args) {
  const result = await run(process.execPath, args, { timeout: WEB_TIMEOUT_MSEC });
  const log = writeLog(name, result.output);
  if (result.code === 0) return { failure: "" };

  // The last line is either the count of problems or the reason the tool could not run.
  const lines = result.output.trim().split(/\r?\n/);
  const first = lines.slice(0, -1).slice(0, 3).join("; ");
  return { failure: `${lines.at(-1)}${first ? `: ${first}` : ""} (${log})` };
}

const format = () => listing("format", ["tools/format.mjs", "--check"]);
const lint = () => listing("lint", ["tools/lint.mjs"]);
const docs = () => listing("docs", ["tools/docs.mjs"]);

async function toolsTests() {
  // Node expands the pattern itself, so no shell is needed on any platform.
  const result = await run(process.execPath, ["--test", "tools/tests/*.test.mjs"], {
    timeout: WEB_TIMEOUT_MSEC,
  });
  return nodeTestResult(result, writeLog("tools-tests", result.output));
}

async function webTests() {
  const result = await npm("test");
  return nodeTestResult(result, writeLog("web-tests", result.output));
}

/** Summarizes the output of the node:test runner. */
function nodeTestResult(result, log) {
  const count = (label) =>
    Number(result.output.match(new RegExp(`^ℹ ${label} (\\d+)`, "m"))?.[1] ?? NaN);
  const total = count("tests");
  const failed = count("fail");
  if (result.code === 0 && failed === 0)
    return { failure: "", detail: `${count("pass")}/${total}` };
  if (result.timedOut) return { failure: `timed out after ${WEB_TIMEOUT_MSEC / 1000} s (${log})` };
  const names = [...result.output.matchAll(/^✖ (.+?)(?: \([\d.]+ms\))?$/gm)].map(
    (match) => match[1],
  );
  const unique = [...new Set(names)];
  const summary = Number.isNaN(failed)
    ? `exit code ${result.code}`
    : `${failed} of ${total} failed`;
  return { failure: `${summary}${unique.length ? `: ${unique.join("; ")}` : ""} (${log})` };
}

function hashTree(directory) {
  const hash = createHash("sha256");
  const visit = (current) => {
    for (const entry of readdirSync(current, { withFileTypes: true }).sort((a, b) =>
      a.name.localeCompare(b.name),
    )) {
      const path = join(current, entry.name);
      if (entry.isDirectory()) visit(path);
      else hash.update(path).update(readFileSync(path));
    }
  };
  visit(directory);
  return hash.digest("hex");
}

async function webBundle() {
  const publicDirectory = join(webDirectory, "public");
  const before = hashTree(publicDirectory);
  const result = await npm("build");
  const log = writeLog("web-bundle", result.output);
  if (result.code !== 0) return { failure: `the browser build failed (${log})` };
  if (hashTree(publicDirectory) === before) return { failure: "" };
  return {
    failure: "web/public did not match web/src and has now been rebuilt; review and commit it",
  };
}

async function e2e(full) {
  const env = { ...process.env, E2E_ROUND: full ? "full" : "quick" };
  const result = await npm("e2e -- --reporter=line", { timeout: E2E_TIMEOUT_MSEC, env });
  const log = writeLog("e2e", result.output);
  const count = (label) => Number(result.output.match(new RegExp(`(\\d+) ${label}`))?.[1] ?? 0);
  const total = count("passed") + count("failed");
  if (result.code === 0)
    return { failure: "", detail: `${count("passed")}/${total}${full ? " full" : ""}` };
  if (result.timedOut) return { failure: `timed out after ${E2E_TIMEOUT_MSEC / 1000} s (${log})` };

  const error = result.output.match(/^\s*Error: (.+)$/m)?.[1] ?? `exit code ${result.code}`;
  return { failure: `${error}; screenshots and traces in test-results/e2e/ (${log})` };
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    process.stdout.write(USAGE);
    return 0;
  }
  const unknown = args.find((arg) => arg.startsWith("-") && !["--release", "--full"].includes(arg));
  if (unknown) {
    process.stderr.write(`Unknown option ${unknown}\n\n${USAGE}`);
    return 2;
  }
  const release = args.includes("--release");
  const full = args.includes("--full");
  const filters = args.filter((arg) => !arg.startsWith("-"));
  const selected = (name) =>
    filters.length === 0 || filters.some((filter) => name.includes(filter));

  rmSync(logDirectory, { recursive: true, force: true });
  mkdirSync(logDirectory, { recursive: true });
  const started = Date.now();
  const failures = [];
  const summary = [];

  const selectedTests = godotTests(full, release).filter(({ name }) => selected(name));
  let godotPassed = 0;
  for (const test of selectedTests) {
    const blocked = test.name in RELEASE_TESTS ? missingExportTemplates() : "";
    const failure = blocked || (await runGodotTest(test));
    if (failure) failures.push(`FAIL ${test.name}: ${failure}`);
    else godotPassed += 1;
  }
  if (selectedTests.length > 0) summary.push(`Godot ${godotPassed}/${selectedTests.length}`);

  const toolChecks = [
    ["format", format, "format"],
    ["lint", lint, "lint"],
    ["docs", docs, "docs"],
    ["tools-tests", toolsTests, "tools tests"],
  ].filter(([name]) => selected(name));
  for (const [name, check, label] of toolChecks) {
    const { failure, detail } = await check();
    if (failure) failures.push(`FAIL ${name}: ${failure}`);
    summary.push(`${label} ${failure ? "FAILED" : (detail ?? "ok")}`);
  }

  const webChecks = [
    ["web-types", webTypes, "types"],
    ["web-tests", webTests, "web tests"],
    ["web-bundle", webBundle, "bundle"],
    // Last, because it serves the bundle the step above rebuilt.
    ["e2e", () => e2e(full), "e2e"],
  ].filter(([name]) => selected(name));
  if (webChecks.length > 0 && !existsSync(join(webDirectory, "node_modules"))) {
    failures.push('FAIL web: dependencies are missing; run "node tools/setup.mjs"');
  } else {
    for (const [name, check, label] of webChecks) {
      const { failure, detail } = await check();
      if (failure) failures.push(`FAIL ${name}: ${failure}`);
      summary.push(`${label} ${failure ? "FAILED" : (detail ?? "ok")}`);
    }
  }

  if (selectedTests.length + toolChecks.length + webChecks.length === 0) {
    process.stderr.write(`No check matches ${filters.join(", ")}\n`);
    return 2;
  }
  for (const line of failures) process.stdout.write(`${line}\n`);
  const seconds = Math.round((Date.now() - started) / 1000);
  process.stdout.write(
    `${failures.length === 0 ? "PASS" : "FAIL"}  ${summary.join(" · ")} · ${seconds} s\n`,
  );
  return failures.length === 0 ? 0 : 1;
}

process.exitCode = await main();
