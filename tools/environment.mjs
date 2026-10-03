// Development-only. Finds the tools a contributor needs and reads their versions,
// shared by tools/setup.mjs and tools/check.mjs.
import { spawnSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join, posix, win32 } from "node:path";
import { fileURLToPath } from "node:url";

export const root = fileURLToPath(new URL("../", import.meta.url));
export const webDirectory = join(root, "web");
export const godotBinary = process.env.GODOT_BIN || "godot";

export const MINIMUM_GODOT = [4, 7, 2];
export const MINIMUM_NODE = [22, 0, 0];

// The standalone builder exports Windows release only, but Godot refuses to
// export unless the debug template is installed as well.
export const WINDOWS_TEMPLATE_FILES = ["windows_release_x86_64.exe", "windows_debug_x86_64.exe"];

/** Returns the first dotted number in text as an array, such as [2, 47, 1] for "git version 2.47.1.windows.1". */
export function parseVersion(text) {
  const match = /\d+(?:\.\d+)+/.exec(text ?? "");
  return match ? match[0].split(".").map(Number) : null;
}

/** Compares two version arrays; missing parts count as zero. */
export function compareVersions(a, b) {
  for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
    const difference = (a[index] ?? 0) - (b[index] ?? 0);
    if (difference !== 0) return Math.sign(difference);
  }
  return 0;
}

export function formatVersion(version) {
  return version.join(".");
}

/**
 * Returns the export templates folder name for `godot --version` output: the
 * numbers and the status, such as "4.7.2.stable" for "4.7.2.stable.official.ed1daf0bf".
 */
export function godotTemplateName(versionText) {
  const parts = (versionText ?? "").trim().split(".");
  const status = parts.findIndex((part) => /^[a-z]/.test(part));
  return status > 0 ? parts.slice(0, status + 1).join(".") : null;
}

/** Returns where Godot's editor keeps the export templates for one version on a platform. */
export function exportTemplatesFolder(
  templateName,
  platform = process.platform,
  env = process.env,
  home = homedir(),
) {
  if (platform === "win32")
    return win32.join(
      env.APPDATA ?? win32.join(home, "AppData", "Roaming"),
      "Godot",
      "export_templates",
      templateName,
    );
  if (platform === "darwin")
    return posix.join(
      home,
      "Library",
      "Application Support",
      "Godot",
      "export_templates",
      templateName,
    );
  return posix.join(
    env.XDG_DATA_HOME || posix.join(home, ".local", "share"),
    "godot",
    "export_templates",
    templateName,
  );
}

/** Returns the Windows template files missing from a templates folder. */
export function missingWindowsTemplates(folder) {
  return WINDOWS_TEMPLATE_FILES.filter((file) => !existsSync(join(folder, file)));
}

/** Runs a tool to read its version. `error` is set when the tool could not be started. */
export function probe(command, args = ["--version"], { shell = false } = {}) {
  // Node rejects separate arguments with a shell, so a shell gets one command line.
  const [file, list] = shell ? [[command, ...args].join(" "), []] : [command, args];
  const result = spawnSync(file, list, {
    encoding: "utf8",
    shell,
    windowsHide: true,
    timeout: 30_000,
  });
  if (result.error) return { error: result.error.code ?? result.error.message, output: "" };
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
  if (result.status !== 0) return { error: `exit code ${result.status}`, output };
  return { error: "", output };
}

/** Reads the Godot version, or returns the reason it could not. */
export function godotVersion() {
  const result = probe(godotBinary);
  if (result.error) return { error: result.error, text: "", version: null };
  const text = result.output.split(/\r?\n/).filter(Boolean).at(-1) ?? "";
  return {
    error: parseVersion(text) ? "" : `unexpected version output "${text}"`,
    text,
    version: parseVersion(text),
  };
}

/** True when web/node_modules is absent or older than the manifest or lockfile it was installed from. */
export function npmInstallNeeded(directory = webDirectory) {
  const marker = join(directory, "node_modules", ".package-lock.json");
  if (!existsSync(marker)) return true;
  const installed = statSync(marker).mtimeMs;
  return ["package.json", "package-lock.json"].some(
    (file) => statSync(join(directory, file)).mtimeMs > installed,
  );
}
