import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { roundedOutline, CORNER_SEGMENTS } from "../../build/shape_paddle/rounded_bar.js";
import { Blinker, canClose, faceLayers } from "../../build/shape_paddle/face.js";
import { paddleOutlines } from "../../build/shape_paddle/paddle.js";
import {
  paddleShape,
  validPreparation,
  validSnapshot,
  WORLD_UNITS,
} from "../../build/005_3d_tilt_shift/types.js";
import { look, preparation, snapshot } from "./fixtures.mjs";

const read = (path) => JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8"));
const outlines = read("../../../tests/fixtures/rounded_bar_outlines.json");
const manifest = read("../../../assets/runtime/shape_faces/face_presets.json");

test("the phone builds the host's rounded outline", () => {
  assert.equal(outlines.segments, CORNER_SEGMENTS);
  for (const entry of outlines.cases) {
    const points = roundedOutline(entry.length, entry.thickness, entry.radius);
    assert.equal(points.length, entry.outline.length);
    points.forEach(([x, y], index) => {
      assert.ok(Math.abs(x - entry.outline[index][0]) < 1e-5, `x at ${index}`);
      assert.ok(Math.abs(y - entry.outline[index][1]) < 1e-5, `y at ${index}`);
    });
  }
});

test("the rings grow from the body by the gap and outline shares of its thickness", () => {
  const shape = paddleShape([0.2, 0.04], "e53935", 0, look);
  assert.ok(Math.abs(shape.length - 0.2 * WORLD_UNITS) < 1e-9);
  const [outline, gap, body] = paddleOutlines(shape).map((points) =>
    Math.max(...points.map(([, y]) => y)),
  );
  const thickness = shape.thickness;
  assert.ok(Math.abs(body - thickness / 2) < 1e-9);
  assert.ok(Math.abs(gap - body - thickness * 0.06) < 1e-9);
  assert.ok(Math.abs(outline - gap - thickness * 0.09) < 1e-9);
  assert.equal(shape.outline, "fd8702");
  assert.equal(paddleShape([0.2, 0.04], "e53935", 2, look).outline, "707070");
});

test("faces compose from the manifest and blink only open eyes", () => {
  const open = faceLayers(manifest, "face_a", false);
  assert.equal(open.length, 3);
  const blink = faceLayers(manifest, "face_a", true);
  assert.equal(blink[0].part, "facial_part_eye_closed_down");
  assert.deepEqual(blink[0].center, open[0].center);
  assert.equal(blink[2].part, open[2].part);
  assert.equal(faceLayers(manifest, "face_j", true)[0].part, "facial_part_eye_x");
  assert.equal(canClose("facial_part_eye_closed_up"), false);
  assert.deepEqual(faceLayers(manifest, "face_z", false), []);
});

test("natural blinks last 0.12 s, 2.4 to 5.6 s apart", () => {
  let seed = 7;
  const blinker = new Blinker(
    undefined,
    undefined,
    () => (seed = (seed * 16807) % 2147483647) / 2147483647,
  );
  const closed = [];
  const open = [];
  let previous = false;
  let since = 0;
  for (let step = 0; step < 24000; step++) {
    const now = step * 0.005;
    const blinking = blinker.closed(now);
    if (blinking !== previous) {
      (previous ? closed : open).push(now - since);
      since = now;
      previous = blinking;
    }
  }
  assert.ok(closed.length > 15);
  for (const run of closed) assert.ok(Math.abs(run - 0.12) <= 0.0051, `blink ${run}`);
  for (const run of open.slice(1)) assert.ok(run >= 2.4 - 0.13 && run <= 5.6 + 0.006, `gap ${run}`);
});

test("snapshots and preparations are validated before use", () => {
  assert.ok(validSnapshot(snapshot()));
  assert.ok(validSnapshot(snapshot({ selected: false, paddle_ids: [] })));
  assert.equal(validSnapshot(snapshot({ type: "tilt_shift_snapshot" })), false);
  assert.equal(validSnapshot(snapshot({ face: "../evil" })), false);
  assert.equal(validSnapshot(snapshot({ color: "red" })), false);
  assert.equal(validSnapshot(snapshot({ look: { ...look, outline_colors: ["fd8702"] } })), false);
  assert.equal(validSnapshot(snapshot({ paddle_size: [0.2, 0] })), false);
  assert.ok(validPreparation(preparation()));
  assert.equal(validPreparation(preparation({ look: undefined })), false);
});
