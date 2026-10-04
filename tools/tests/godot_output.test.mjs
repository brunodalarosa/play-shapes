import assert from "node:assert/strict";
import { test } from "node:test";
import { godotFailureLines, withoutLevel } from "../godot_output.mjs";

const HELD = [
  "ERROR: 2 resources still in use at exit (run with --verbose for details).",
  "WARNING: 5 ObjectDB instances were leaked at exit (run with `--verbose` for details).",
  "ERROR: 6 RID allocations of type 'N16RendererViewport8ViewportE' were leaked at exit.",
  'WARNING: 74 RIDs of type "CanvasItem" were leaked.',
];

test("fails a script on every error line", () => {
  const output = [
    "Godot Engine v4.7.2.stable.official",
    "ERROR: A check failed",
    "   at: push_error (core/variant/variant_utility.cpp:1024)",
    "SCRIPT ERROR: Invalid access to property or key 'name' on a base object of type 'Nil'.",
    "WARNING: A warning is not a failure",
    "lobby_layout_test: 2 failures",
  ].join("\r\n");

  assert.deepEqual(godotFailureLines(output), [
    "ERROR: A check failed",
    "SCRIPT ERROR: Invalid access to property or key 'name' on a base object of type 'Nil'.",
  ]);
  assert.deepEqual(godotFailureLines("Godot Engine\nplayer_registry_test: 0 failures\n"), []);
});

test("fails a script that still holds something at exit, also when Godot only warns", () => {
  assert.deepEqual(godotFailureLines(HELD.join("\n")), HELD);
});

test("excuses a script that quits the editor what the editor held, and nothing else", () => {
  const output = ["ERROR: FAIL: release executable exists", ...HELD].join("\n");

  assert.deepEqual(godotFailureLines(output, { editor: true }), [
    "ERROR: FAIL: release executable exists",
  ]);
});

test("strips the level from a line", () => {
  assert.equal(withoutLevel("ERROR: A check failed"), "A check failed");
  assert.equal(withoutLevel("SCRIPT ERROR: Parse Error: oops"), "Parse Error: oops");
  assert.equal(
    withoutLevel("WARNING: 5 ObjectDB instances were leaked"),
    "5 ObjectDB instances were leaked",
  );
});
