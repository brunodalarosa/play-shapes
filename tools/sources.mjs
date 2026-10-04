// Development-only. Says which files are this project's own source, so the
// format and lint commands agree on what they cover.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { root } from "./environment.mjs";

export const LINE_LENGTH = 100;

/** Lists the tracked and new files, leaving out ignored ones. Paths use forward slashes. */
export function repositoryFiles() {
  const listed = spawnSync("git", ["ls-files", "--cached", "--others", "--exclude-standard"], {
    cwd: root,
    encoding: "utf8",
  });
  if (listed.status !== 0) throw new Error(`could not list files with git: ${listed.stderr}`);

  return listed.stdout.split("\n").filter((file) => file && existsSync(join(root, file)));
}

/** True for a GDScript file of the project; addons/ is vendored. */
export function isGdscriptSource(file) {
  return file.endsWith(".gd") && !file.startsWith("addons/");
}

/** True for a GDScript test file: one in tests/ or in the tests/ folder of a minigame. */
export function isGodotTest(file) {
  return isGdscriptSource(file) && /^(tests|minigames\/[^/]+\/tests)\//.test(file);
}

/**
 * True for a file Prettier formats: the TypeScript and JavaScript of web/ and
 * tools/, the configuration modules at the root, and the two hand-written files
 * in web/public, whose .js files are compiled from web/src.
 */
export function isWebSource(file) {
  if (file === "web/public/index.html" || file === "web/public/style.css") return true;
  if (file.startsWith("web/src/vendor/")) return false;
  if (/^web\/(src|e2e|tests|scripts)\/.+\.(ts|mjs)$/.test(file)) return true;
  if (/^web\/[^/]+\.(ts|mjs)$/.test(file)) return true;
  return /^(tools\/.+|[^/]+)\.mjs$/.test(file);
}

/**
 * True for the two kinds of line that cannot be shortened without a worse result: any
 * line of an HTML file, where an attribute value cannot continue on another line without
 * changing its text, and the line that opens a test with its title, where splitting the
 * title makes Prettier indent the whole test body a level deeper.
 */
export function mayExceedLineLength(file, line) {
  if (file.endsWith(".html")) return true;
  return /^\s*test\((["'`]).*\1, (async )?\(\w*\) => \{$/.test(line);
}

/**
 * True for a TypeScript or JavaScript file that is neither a source above nor one of the
 * places left alone on purpose: the compiled and vendored files in web/public, the
 * vendored declarations in web/src/vendor, vendored addons, and the art review pages.
 * Such a file would otherwise go unformatted and unlinted without anyone noticing.
 */
export function isUncoveredScript(file) {
  if (!/\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/.test(file)) return false;
  if (/^(web\/public|web\/src\/vendor|addons|art)\//.test(file)) return false;
  return !isWebSource(file);
}

export function gdscriptFiles() {
  return repositoryFiles().filter(isGdscriptSource);
}

export function webSourceFiles() {
  return repositoryFiles().filter(isWebSource);
}
