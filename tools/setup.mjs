#!/usr/bin/env node
// Development-only. Checks the tools a contributor needs and installs the
// browser client's npm dependencies. It never installs or changes anything
// outside this repository.
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import {
  MINIMUM_GODOT, MINIMUM_NODE, compareVersions, exportTemplatesFolder, formatVersion, godotBinary, godotTemplateName,
  godotVersion, missingWindowsTemplates, npmInstallNeeded, parseVersion, probe, root, webDirectory,
} from './environment.mjs';

const USAGE = `Usage: node tools/setup.mjs

Checks the required tools (Git, Node, npm, Godot) and fails when one is
missing or too old, reports the tools some tasks need, then runs
"npm ci --ignore-scripts" in web/ when its dependencies are missing or out of
date. README.md lists every tool and what it is for.
`;

const GODOT_DOWNLOAD = 'https://godotengine.org/download';

// npm is a .cmd shim on Windows, which Node only starts through a shell.
const npmShell = process.platform === 'win32';

function versioned(name, minimum, result, install) {
  if (result.error) return { ok: false, text: `${name}: could not be started (${result.error}). ${install}` };
  const version = parseVersion(result.output);
  if (!version) return { ok: false, text: `${name}: could not read the version from "${result.output}". ${install}` };
  if (compareVersions(version, minimum) < 0) {
    return { ok: false, text: `${name} ${formatVersion(version)} is older than ${formatVersion(minimum)}. ${install}` };
  }
  return { ok: true, text: `${name} ${formatVersion(version)}` };
}

function checkGit() {
  return versioned('Git', [0], probe('git'), 'Install it from https://git-scm.com/downloads.');
}

function checkNode() {
  return versioned('Node', MINIMUM_NODE, { error: '', output: process.versions.node },
    `Install Node ${MINIMUM_NODE[0]} or newer from https://nodejs.org.`);
}

function checkNpm() {
  return versioned('npm', [0], probe('npm', ['--version'], { shell: npmShell }), 'npm comes with Node; reinstall Node.');
}

function checkGodot() {
  const where = process.env.GODOT_BIN ? `GODOT_BIN (${godotBinary})` : '"godot" on PATH';
  const install = `Install Godot ${formatVersion(MINIMUM_GODOT)} or newer from ${GODOT_DOWNLOAD}, `
    + 'then put it on PATH as "godot" or set GODOT_BIN to its executable.';
  const { error, text } = godotVersion();
  const result = versioned('Godot', MINIMUM_GODOT, { error, output: text }, install);
  return { ...result, templateName: godotTemplateName(text), text: `${result.text}${result.ok ? '' : ` Looked for ${where}.`}` };
}

function checkMkcert() {
  const local = join(root, 'local', 'tools', `mkcert${process.platform === 'win32' ? '.exe' : ''}`);
  const command = existsSync(local) ? local : 'mkcert';
  const ok = !probe(command, ['-version']).error;
  return { ok, text: `mkcert, for local HTTPS: ${ok ? command : 'not found; "node tools/local_https.mjs download" fetches it'}` };
}

function checkGh() {
  const ok = !probe('gh').error;
  return { ok, text: `GitHub CLI (gh), for pull requests from the terminal: ${ok ? 'found' : 'not found; https://cli.github.com'}` };
}

function checkExportTemplates(godot) {
  const { templateName } = godot;
  if (!godot.ok || !templateName) return { ok: false, text: 'Godot export templates, for the standalone build: needs Godot first' };
  const folder = exportTemplatesFolder(templateName);
  const ok = missingWindowsTemplates(folder).length === 0;
  const where = ok ? folder : `not in ${folder}; install ${templateName} from Editor > Manage Export Templates`;
  return { ok, text: `Godot export templates, for the standalone build: ${where}` };
}

function print(status, text) {
  process.stdout.write(`  ${status.padEnd(8)} ${text}\n`);
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) { process.stdout.write(USAGE); return 0; }
  if (args.length > 0) { process.stderr.write(`Unknown option ${args[0]}\n\n${USAGE}`); return 2; }

  process.stdout.write('Required\n');
  const godot = checkGodot();
  const required = [checkGit(), checkNode(), checkNpm(), godot];
  for (const { ok, text } of required) print(ok ? 'ok' : 'MISSING', text);

  process.stdout.write('As needed\n');
  for (const { ok, text } of [checkExportTemplates(godot), checkMkcert(), checkGh()]) print(ok ? 'ok' : '-', text);
  print('-', 'Python 3 with Pillow, GIMP 3, Blender, for regenerating art: not checked; see art/bubbles/README.md and art/squircle/README.md');

  if (required.some(({ ok }) => !ok)) {
    process.stdout.write('\nInstall the missing required tools, then run "node tools/setup.mjs" again.\n');
    return 1;
  }

  process.stdout.write('Browser client\n');
  if (!npmInstallNeeded()) {
    print('ok', 'web/node_modules is up to date');
  } else {
    print('...', 'installing web/ dependencies with "npm ci --ignore-scripts"');
    const result = spawnSync('npm ci --ignore-scripts', { cwd: webDirectory, shell: true, stdio: 'inherit' });
    if (result.status !== 0) { print('FAILED', '"npm ci" in web/ did not finish; see its output above'); return 1; }
    print('ok', 'web/node_modules installed');
  }
  process.stdout.write('\nReady. Run "node tools/check.mjs" to run every check.\n');
  return 0;
}

process.exitCode = main();
