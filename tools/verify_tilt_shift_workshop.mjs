// Development-only. Run the real editor with a temporary verification plugin.
import { spawn } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { root, godotBinary } from "./environment.mjs";

const config = join(root, "project.godot");
const original = readFileSync(config, "utf8");
const driver = "res://minigames/003_tilt_shift/tests/editor_driver/plugin.cfg";
const logFolder = join(root, "test-results", "tilt-shift", "workshop");
mkdirSync(logFolder, { recursive: true });
if (original.includes(driver))
  throw new Error("The temporary verification plugin is already enabled");
const enabled = original.replace(
  /enabled=PackedStringArray\(([^\r\n]*)\)/,
  (_match, plugins) => `enabled=PackedStringArray(${plugins}, "${driver}")`,
);
if (enabled === original) throw new Error("Cannot find the editor plugin registration");
let output = "";
let failed = false;
try {
  writeFileSync(config, enabled);
  for (const stage of ["save", "reload"]) {
    const log = join(logFolder, `editor-${stage}.log`);
    const code = await new Promise((resolve, reject) => {
      const child = spawn(godotBinary, ["--editor", "--path", root, "--log-file", log], {
        cwd: root,
        windowsHide: true,
        env: { ...process.env, PLAY_SHAPES_WORKSHOP_STAGE: stage },
      });
      const timeout = setTimeout(() => child.kill(), 60_000);
      child.stdout.on("data", (chunk) => {
        output += chunk;
        process.stdout.write(chunk);
      });
      child.stderr.on("data", (chunk) => {
        output += chunk;
        process.stderr.write(chunk);
      });
      child.on("error", (error) => {
        clearTimeout(timeout);
        reject(error);
      });
      child.on("close", (result) => {
        clearTimeout(timeout);
        resolve(result);
      });
    });
    if (code !== 0 || /^(?:SCRIPT ERROR|ERROR):/m.test(output)) {
      failed = true;
      break;
    }
  }
} finally {
  writeFileSync(config, original);
}
if (failed) process.exitCode = 1;
