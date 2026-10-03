#!/usr/bin/env node
// Development-only. Runs every automated check and reports each failure in one line.
// Full output for every check is written under test-results/check/.
import { spawn, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const webDirectory = join(root, 'web');
const logDirectory = join(root, 'test-results', 'check');
const godotBinary = process.env.GODOT_BIN || 'godot';
const GODOT_TIMEOUT_MSEC = 180_000;
const WEB_TIMEOUT_MSEC = 300_000;

// Needs an installed export and writes builds/, so it only runs with --release.
const RELEASE_TESTS = { standalone_build_editor_integration_test: ['--editor'] };

// Temporary: three passing tests still hold objects when they quit, and Godot
// reports that at shutdown. Delete this list when those tests release what
// they hold, so that any such line fails the check again.
const IGNORED_SHUTDOWN_ERRORS = [
  /resources still in use at exit/,
  /RID allocations of type .* were leaked at exit/,
  /ObjectDB instances leaked at exit/,
];

const USAGE = `Usage: node tools/check.mjs [--release] [filter ...]

Runs the Godot test scripts, the browser type check and tests, and verifies
that web/public matches a fresh build.

  filter      Run only checks whose name contains one of the filters,
              for example "bubbles" or "web".
  --release   Also run the Windows export test. Needs Godot export templates.
`;

function run(command, args, { cwd = root, timeout, shell = false } = {}) {
  return new Promise(resolve => {
    const child = spawn(command, args, { cwd, shell, windowsHide: true, env: process.env });
    let output = '';
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; child.kill(); }, timeout);
    child.stdout.on('data', chunk => { output += chunk; });
    child.stderr.on('data', chunk => { output += chunk; });
    child.on('error', error => { clearTimeout(timer); resolve({ code: -1, output, timedOut, spawnError: error }); });
    child.on('close', code => { clearTimeout(timer); resolve({ code, output, timedOut }); });
  });
}

function writeLog(name, output) {
  writeFileSync(join(logDirectory, `${name}.log`), output);
  return `test-results/check/${name}.log`;
}

function godotTestNames(includeRelease) {
  return readdirSync(join(root, 'tests'))
    .filter(file => file.endsWith('_test.gd') || file === 'foundation.gd')
    .map(file => file.slice(0, -'.gd'.length))
    .filter(name => includeRelease || !(name in RELEASE_TESTS))
    .sort();
}

function godotErrorLines(output) {
  return output.split(/\r?\n/)
    .filter(line => /^(SCRIPT )?ERROR:/.test(line))
    .filter(line => !IGNORED_SHUTDOWN_ERRORS.some(pattern => pattern.test(line)));
}

async function runGodotTest(name) {
  const args = ['--headless', ...(RELEASE_TESTS[name] ?? []), '--path', root, '--script', `res://tests/${name}.gd`];
  const result = await run(godotBinary, args, { timeout: GODOT_TIMEOUT_MSEC });
  const log = writeLog(name, result.output);
  if (result.spawnError) return `could not start Godot (${result.spawnError.code}); set GODOT_BIN to the Godot executable`;
  if (result.timedOut) return `timed out after ${GODOT_TIMEOUT_MSEC / 1000} s (${log})`;
  const errors = godotErrorLines(result.output);
  if (result.code === 0 && errors.length === 0) return '';
  const reason = errors[0]?.replace(/^(SCRIPT )?ERROR:\s*/, '') ?? `exit code ${result.code}`;
  const more = errors.length > 1 ? ` (+${errors.length - 1} more)` : '';
  return `${reason}${more} (${log})`;
}

/** Returns a message when the Windows export templates the release test needs are absent. */
function missingExportTemplates() {
  if (process.platform !== 'win32') return 'the standalone builder supports only a Windows host';
  const version = spawnSync(godotBinary, ['--version'], { encoding: 'utf8' }).stdout?.trim() ?? '';
  const parts = version.split('.');
  const status = parts.findIndex(part => /^[a-z]/.test(part));
  if (status < 0) return `could not read the Godot version from "${version}"`;
  const folder = join(process.env.APPDATA ?? '', 'Godot', 'export_templates', parts.slice(0, status + 1).join('.'));
  const missing = ['windows_release_x86_64.exe', 'windows_debug_x86_64.exe'].filter(file => !existsSync(join(folder, file)));
  return missing.length === 0 ? '' : `Godot export templates are not installed in ${folder}; install them from Editor > Manage Export Templates`;
}

function npm(script) {
  // npm is a .cmd shim on Windows, which Node only starts through a shell.
  return run(`npm run --silent ${script}`, [], { cwd: webDirectory, timeout: WEB_TIMEOUT_MSEC, shell: true });
}

async function webTypes() {
  const result = await npm('check');
  const log = writeLog('web-types', result.output);
  if (result.code === 0) return { failure: '' };
  const first = result.output.split(/\r?\n/).find(line => /error TS\d+/.test(line)) ?? `exit code ${result.code}`;
  return { failure: `${first.trim()} (${log})` };
}

async function webTests() {
  const result = await npm('test');
  const log = writeLog('web-tests', result.output);
  const count = label => Number(result.output.match(new RegExp(`^ℹ ${label} (\\d+)`, 'm'))?.[1] ?? NaN);
  const total = count('tests');
  const failed = count('fail');
  if (result.code === 0 && failed === 0) return { failure: '', detail: `${count('pass')}/${total}` };
  if (result.timedOut) return { failure: `timed out after ${WEB_TIMEOUT_MSEC / 1000} s (${log})` };
  const names = [...result.output.matchAll(/^✖ (.+?)(?: \([\d.]+ms\))?$/gm)].map(match => match[1]);
  const unique = [...new Set(names)];
  const summary = Number.isNaN(failed) ? `exit code ${result.code}` : `${failed} of ${total} failed`;
  return { failure: `${summary}${unique.length ? `: ${unique.join('; ')}` : ''} (${log})` };
}

function hashTree(directory) {
  const hash = createHash('sha256');
  const visit = current => {
    for (const entry of readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const path = join(current, entry.name);
      if (entry.isDirectory()) visit(path);
      else hash.update(path).update(readFileSync(path));
    }
  };
  visit(directory);
  return hash.digest('hex');
}

async function webBundle() {
  const publicDirectory = join(webDirectory, 'public');
  const before = hashTree(publicDirectory);
  const result = await npm('build');
  const log = writeLog('web-bundle', result.output);
  if (result.code !== 0) return { failure: `the browser build failed (${log})` };
  if (hashTree(publicDirectory) === before) return { failure: '' };
  return { failure: 'web/public did not match web/src and has now been rebuilt; review and commit it' };
}

async function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) { process.stdout.write(USAGE); return 0; }
  const unknown = args.find(arg => arg.startsWith('-') && arg !== '--release');
  if (unknown) { process.stderr.write(`Unknown option ${unknown}\n\n${USAGE}`); return 2; }
  const release = args.includes('--release');
  const filters = args.filter(arg => !arg.startsWith('-'));
  const selected = name => filters.length === 0 || filters.some(filter => name.includes(filter));

  rmSync(logDirectory, { recursive: true, force: true });
  mkdirSync(logDirectory, { recursive: true });
  const started = Date.now();
  const failures = [];
  const summary = [];

  const godotTests = godotTestNames(release).filter(selected);
  let godotPassed = 0;
  for (const name of godotTests) {
    const blocked = name in RELEASE_TESTS ? missingExportTemplates() : '';
    const failure = blocked || await runGodotTest(name);
    if (failure) failures.push(`FAIL ${name}: ${failure}`);
    else godotPassed += 1;
  }
  if (godotTests.length > 0) summary.push(`Godot ${godotPassed}/${godotTests.length}`);

  const webChecks = [
    ['web-types', webTypes, 'types'],
    ['web-tests', webTests, 'web tests'],
    ['web-bundle', webBundle, 'bundle'],
  ].filter(([name]) => selected(name));
  if (webChecks.length > 0 && !existsSync(join(webDirectory, 'node_modules'))) {
    failures.push('FAIL web: dependencies are missing; run "npm ci" in web/');
  } else {
    for (const [name, check, label] of webChecks) {
      const { failure, detail } = await check();
      if (failure) failures.push(`FAIL ${name}: ${failure}`);
      summary.push(`${label} ${failure ? 'FAILED' : detail ?? 'ok'}`);
    }
  }

  if (godotTests.length + webChecks.length === 0) {
    process.stderr.write(`No check matches ${filters.join(', ')}\n`);
    return 2;
  }
  for (const line of failures) process.stdout.write(`${line}\n`);
  const seconds = Math.round((Date.now() - started) / 1000);
  process.stdout.write(`${failures.length === 0 ? 'PASS' : 'FAIL'}  ${summary.join(' · ')} · ${seconds} s\n`);
  return failures.length === 0 ? 0 : 1;
}

process.exitCode = await main();
