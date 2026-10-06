import assert from "node:assert/strict";
import test from "node:test";
import {
  gdscriptFiles,
  isGdscriptSource,
  isGodotTest,
  isUncoveredScript,
  isWebSource,
  mayExceedLineLength,
  webSourceFiles,
} from "../sources.mjs";

test("treats project GDScript as source and vendored addons as not", () => {
  assert.equal(isGdscriptSource("host/session_host.gd"), true);
  assert.equal(isGdscriptSource("tests/e2e/host.gd"), true);
  assert.equal(isGdscriptSource("addons/godot_mcp/plugin.gd"), false);
  assert.equal(isGdscriptSource("addons/tilt_shift_workshop/workshop_model.gd"), true);
  assert.equal(isGdscriptSource("addons/standalone_build/standalone_build_plugin.gd"), false);
  assert.equal(isGdscriptSource("host/session_host.gd.uid"), false);
});

test("finds Godot tests in tests/ and in a minigame's tests/ folder", () => {
  const game = "minigames/002_bubbles_and_jellyfishes";

  assert.equal(isGodotTest("tests/player_registry_test.gd"), true);
  assert.equal(isGodotTest("tests/e2e/host.gd"), true);
  assert.equal(isGodotTest(`${game}/tests/bubbles_protocol_test.gd`), true);
  assert.equal(isGodotTest(`${game}/bubbles_protocol.gd`), false);
  assert.equal(isGodotTest("host/session_host.gd"), false);
  assert.equal(isGodotTest("tests/fixtures/debug_scenario.tscn"), false);
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
    "web/src/vendor/nipplejs.d.mts",
    "web/src/vendor/other.ts",
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

test("reports a script that no rule covers and is not left alone on purpose", () => {
  assert.equal(isUncoveredScript("server/index.ts"), true);
  assert.equal(isUncoveredScript("web/extra/helper.mjs"), true);
  assert.equal(isUncoveredScript("scripts/build.js"), true);

  assert.equal(isUncoveredScript("web/src/app.ts"), false);
  assert.equal(isUncoveredScript("tools/lint.mjs"), false);
  assert.equal(isUncoveredScript("web/public/app.js"), false);
  assert.equal(isUncoveredScript("web/src/vendor/nipplejs.d.mts"), false);
  assert.equal(isUncoveredScript("addons/kenyoni/tool.js"), false);
  assert.equal(isUncoveredScript("art/squircle/review.js"), false);
  assert.equal(isUncoveredScript("host/session_host.gd"), false);
  assert.equal(isUncoveredScript("README.md"), false);
});

test("lets only HTML lines and test titles exceed the line length", () => {
  const file = "web/tests/host.test.mjs";
  assert.equal(mayExceedLineLength(file, 'test("a title", async () => {'), true);
  assert.equal(mayExceedLineLength(file, 'test("a title", async (t) => {'), true);
  assert.equal(mayExceedLineLength(file, "  test('a title', () => {"), true);
  assert.equal(mayExceedLineLength("web/public/index.html", '<div aria-label="long">'), true);

  assert.equal(mayExceedLineLength(file, 'const text = "a long string";'), false);
  assert.equal(mayExceedLineLength(file, 'test("a title", async () => { run(); });'), false);
  assert.equal(mayExceedLineLength(file, 'assert.equal(test("a"), 1); // () => {'), false);
  assert.equal(mayExceedLineLength("web/public/style.css", "a { color: red; }"), false);
});

test("finds this repository's own sources", () => {
  assert.ok(gdscriptFiles().includes("host/session_host.gd"));
  assert.ok(webSourceFiles().includes("tools/sources.mjs"));
  assert.ok(webSourceFiles().every((file) => !file.includes("\\")));
});
