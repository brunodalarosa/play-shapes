import test from "node:test";
import assert from "node:assert/strict";
import { includeGodotTest } from "../check_selection.mjs";

const extended = ["tilt_shift_workshop_preview_test", "tilt_shift_rotation_contact_test"];
const exported = "standalone_build_editor_integration_test";

test("default retains ordinary physics and excludes extended coverage and export", () => {
  assert.equal(includeGodotTest("tilt_shift_physics_test"), true);
  for (const name of [...extended, exported]) assert.equal(includeGodotTest(name), false);
});

test("full adds extended coverage without enabling export", () => {
  for (const name of extended) assert.equal(includeGodotTest(name, { full: true }), true);
  assert.equal(includeGodotTest(exported, { full: true }), false);
});

test("release remains independent of full coverage", () => {
  assert.equal(includeGodotTest(exported, { release: true }), true);
  for (const name of extended) assert.equal(includeGodotTest(name, { release: true }), false);
  for (const name of [...extended, exported])
    assert.equal(includeGodotTest(name, { full: true, release: true }), true);
});
