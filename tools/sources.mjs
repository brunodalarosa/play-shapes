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

/**
 * True for a file Prettier formats: the TypeScript and JavaScript of web/ and
 * tools/, the configuration modules at the root, and the two hand-written files
 * in web/public, whose .js files are compiled from web/src.
 */
export function isWebSource(file) {
  if (file === "web/public/index.html" || file === "web/public/style.css") return true;
  if (/^web\/(src|e2e|tests|scripts)\/.+\.(ts|mjs)$/.test(file)) return true;
  if (/^web\/[^/]+\.(ts|mjs)$/.test(file)) return true;
  return /^(tools\/.+|[^/]+)\.mjs$/.test(file);
}

export function gdscriptFiles() {
  return repositoryFiles().filter(isGdscriptSource);
}

export function webSourceFiles() {
  return repositoryFiles().filter(isWebSource);
}
