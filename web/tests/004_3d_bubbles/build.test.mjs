import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("runtime models are copied byte for byte", () => {
  const runtime = "../../../assets/runtime/";
  const character = runtime + "animated_characters/cubio/model/";
  const jellyfish = runtime + "minigames/bubbles_3d/jellyfish/";
  for (const [source, name] of [
    [character + "cubio.glb", "cubio.glb"],
    [jellyfish + "jellyfish.glb", "jellyfish.glb"],
  ]) {
    const original = readFileSync(new URL(source, import.meta.url));
    const copy = readFileSync(new URL(`../../public/models/${name}`, import.meta.url));
    assert.deepEqual(copy, original, name);
  }
});

test("the main bundle excludes three.js and the separate view retains its license", () => {
  const app = readFileSync(new URL("../../public/app.js", import.meta.url), "utf8");
  const view = readFileSync(new URL("../../public/three_view.js", import.meta.url), "utf8");
  assert.doesNotMatch(app, /node_modules\/three|class WebGLRenderer|class GLTFLoader/);
  assert.match(app, /import\(url\)/);
  assert.match(app, /\/three_view\.js/);
  assert.match(view, /SPDX-License-Identifier: MIT/);
});
