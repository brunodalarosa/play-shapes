import assert from "node:assert/strict";
import test from "node:test";
import { gdscriptFiles, isGdscriptSource, isWebSource, webSourceFiles } from "../sources.mjs";

test("treats project GDScript as source and vendored addons as not", () => {
  assert.equal(isGdscriptSource("host/session_host.gd"), true);
  assert.equal(isGdscriptSource("tests/e2e/host.gd"), true);
  assert.equal(isGdscriptSource("addons/godot_mcp/plugin.gd"), false);
  assert.equal(isGdscriptSource("host/session_host.gd.uid"), false);
});

test("treats the hand-written web and tools files as source", () => {
  for (const file of [
    "web/src/app.ts",
    "web/e2e/fixtures.ts",
    "web/tests/fixtures/platform_context.mjs",
    "web/scripts/copy_vendor.mjs",
    "web/playwright.config.ts",
    "web/eslint.rules.mjs",
    "tools/check.mjs",
    "tools/tests/sources.test.mjs",
    "eslint.config.mjs",
    "web/public/index.html",
    "web/public/style.css",
  ]) {
    assert.equal(isWebSource(file), true, file);
  }
});

test("leaves compiled, vendored and other files alone", () => {
  for (const file of [
    "web/public/app.js",
    "web/public/vendor/nipplejs.mjs",
    "web/public/platform_input_settings.json",
    "web/node_modules/prettier/index.mjs",
    "web/package.json",
    "addons/kenyoni/qr_code/tool.mjs",
    "art/squircle/review.js",
    "README.md",
    "host/session_host.gd",
  ]) {
    assert.equal(isWebSource(file), false, file);
  }
});

test("finds this repository's own sources", () => {
  assert.ok(gdscriptFiles().includes("host/session_host.gd"));
  assert.ok(webSourceFiles().includes("tools/sources.mjs"));
  assert.ok(webSourceFiles().every((file) => !file.includes("\\")));
});
