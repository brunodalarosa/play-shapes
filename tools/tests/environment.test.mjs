import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import {
  compareVersions,
  exportTemplatesFolder,
  godotTemplateName,
  missingWindowsTemplates,
  npmInstallNeeded,
  parseVersion,
} from "../environment.mjs";

test("reads the version from each tool's output", () => {
  assert.deepEqual(parseVersion("4.7.2.stable.official.ed1daf0bf"), [4, 7, 2]);
  assert.deepEqual(parseVersion("git version 2.47.1.windows.1"), [2, 47, 1]);
  assert.deepEqual(parseVersion("v24.19.0"), [24, 19, 0]);
  assert.deepEqual(parseVersion("4.8.dev3.official"), [4, 8]);
  assert.equal(parseVersion("command not found"), null);
});

test("compares versions with missing parts as zero", () => {
  assert.equal(compareVersions([4, 7, 2], [4, 7, 2]), 0);
  assert.equal(compareVersions([4, 8], [4, 7, 2]), 1);
  assert.equal(compareVersions([4, 7], [4, 7, 2]), -1);
  assert.equal(compareVersions([5, 0, 0], [4, 7, 2]), 1);
  assert.equal(compareVersions([21, 9, 0], [22, 0, 0]), -1);
});

test("names the export templates folder after the version and status", () => {
  assert.equal(godotTemplateName("4.7.2.stable.official.ed1daf0bf\n"), "4.7.2.stable");
  assert.equal(godotTemplateName("4.7.stable.official.abc"), "4.7.stable");
  assert.equal(godotTemplateName("4.8.dev3.official.abc"), "4.8.dev3");
  assert.equal(godotTemplateName("garbage"), null);
});

test("finds the export templates folder on each platform", () => {
  const name = "4.7.2.stable";
  assert.equal(
    exportTemplatesFolder(
      name,
      "win32",
      { APPDATA: "C:\\Users\\a\\AppData\\Roaming" },
      "C:\\Users\\a",
    ),
    "C:\\Users\\a\\AppData\\Roaming\\Godot\\export_templates\\4.7.2.stable",
  );
  assert.equal(
    exportTemplatesFolder(name, "darwin", {}, "/Users/a"),
    "/Users/a/Library/Application Support/Godot/export_templates/4.7.2.stable",
  );
  assert.equal(
    exportTemplatesFolder(name, "linux", {}, "/home/a"),
    "/home/a/.local/share/godot/export_templates/4.7.2.stable",
  );
  assert.equal(
    exportTemplatesFolder(name, "linux", { XDG_DATA_HOME: "/data" }, "/home/a"),
    "/data/godot/export_templates/4.7.2.stable",
  );
});

test("lists the Windows template files a folder lacks", (t) => {
  const folder = mkdtempSync(join(tmpdir(), "templates-"));
  t.after(() => rmSync(folder, { recursive: true, force: true }));
  assert.deepEqual(missingWindowsTemplates(folder), [
    "windows_release_x86_64.exe",
    "windows_debug_x86_64.exe",
  ]);
  writeFileSync(join(folder, "windows_release_x86_64.exe"), "");
  assert.deepEqual(missingWindowsTemplates(folder), ["windows_debug_x86_64.exe"]);
});

test("installs npm dependencies when they are absent or older than the lockfile", (t) => {
  const directory = mkdtempSync(join(tmpdir(), "web-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const at = (file, seconds) => utimesSync(join(directory, file), seconds, seconds);
  writeFileSync(join(directory, "package.json"), "{}");
  writeFileSync(join(directory, "package-lock.json"), "{}");
  at("package.json", 1000);
  at("package-lock.json", 1000);
  assert.equal(npmInstallNeeded(directory), true);

  mkdirSync(join(directory, "node_modules"));
  writeFileSync(join(directory, "node_modules", ".package-lock.json"), "{}");
  at("node_modules/.package-lock.json", 2000);
  assert.equal(npmInstallNeeded(directory), false);

  at("package-lock.json", 3000);
  assert.equal(npmInstallNeeded(directory), true);
});
