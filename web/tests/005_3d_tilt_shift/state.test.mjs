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
  const open = faceLayers(manifest, "face_slightly_smiling", false);
  assert.equal(open.length, 3);
  const blink = faceLayers(manifest, "face_slightly_smiling", true);
  assert.equal(blink[0].part, "facial_part_eye_closed_down");
  assert.deepEqual(blink[0].center, open[0].center);
  assert.equal(blink[2].part, open[2].part);
  assert.equal(faceLayers(manifest, "face_dizzy", true)[0].part, "facial_part_eye_x");
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

test("emoji presets compose on the phone and keep shut eyes during blinks", () => {
  const emojiFaces = Object.entries(manifest.faces).filter(([, face]) => face.emoji_reference);
  assert.equal(emojiFaces.length, 64);
  for (const [name, preset] of emojiFaces) {
    assert.ok(validSnapshot(snapshot({ face: name })), name);
    assert.ok(validPreparation(preparation({ face: name })), name);
    assert.equal(faceLayers(manifest, name, false).length, preset.layers.length);
  }
  for (const name of [
    "face_smiling_eyes",
    "face_disappointed",
    "face_confounded",
    "face_dizzy",
    "face_kissing_smiling_eyes",
    "face_kissing_closed_eyes",
    "face_warm_smile",
    "face_persevering",
    "face_relieved",
    "face_pensive",
    "face_spiral_eyes",
    "face_beaming",
    "face_tired",
    "face_weary",
    "face_squinting_tongue",
    "face_savoring_food",
    "face_joy_tears",
    "face_grinning_sweat",
    "face_sunglasses",
    "face_heart_eyes",
    "face_star_struck",
    "face_sleepy",
    "face_sleeping",
    "face_downcast_sweat",
    "face_money_mouth",
    "face_loudly_crying",
    "face_halo",
  ]) {
    assert.deepEqual(faceLayers(manifest, name, true), faceLayers(manifest, name, false));
  }
  const wink = faceLayers(manifest, "face_winking", true);
  assert.equal(wink[0].part, "facial_part_eye_closed_down");
  assert.equal(wink[1].part, "facial_part_eye_closed_up");
  const tired = faceLayers(manifest, "face_exhausted", true);
  assert.equal(tired[0].part, "facial_part_eye_closed_down");
  assert.equal(tired[2].part, "facial_part_eyebrow_a");
  assert.equal(tired[3].part, "facial_part_eyebrow_a");
  assert.equal(faceLayers(manifest, "face_spiral_eyes", true)[0].part, "facial_part_eye_spiral");
  assert.equal(faceLayers(manifest, "face_dizzy", true)[0].part, "facial_part_eye_x");
  const pleading = faceLayers(manifest, "face_pleading", true);
  assert.equal(pleading[0].part, "facial_part_eye_closed_down");
  assert.equal(pleading[4].part, "facial_part_mouth_sad");
  assert.equal(
    faceLayers(manifest, "face_holding_back_tears", false)[0].part,
    "facial_part_eye_teary",
  );
  assert.equal(
    faceLayers(manifest, "face_holding_back_tears", true)[0].part,
    "facial_part_eye_closed_down",
  );
  const woozy = faceLayers(manifest, "face_woozy", false);
  assert.notEqual(woozy[0].part, woozy[1].part);
  assert.notEqual(woozy[0].center[1], woozy[1].center[1]);
  for (const name of [
    "face_tongue",
    "face_winking_tongue",
    "face_squinting_tongue",
    "face_savoring_food",
    "face_zany",
  ]) {
    const open = faceLayers(manifest, name, false);
    const blinked = faceLayers(manifest, name, true);
    assert.equal(open[3].part, "facial_part_tongue");
    assert.deepEqual(blinked[3], open[3]);
  }
  const tongueWink = faceLayers(manifest, "face_winking_tongue", true);
  assert.equal(tongueWink[0].part, "facial_part_eye_closed_down");
  assert.equal(tongueWink[1].part, "facial_part_eye_closed_up");
  const zany = faceLayers(manifest, "face_zany", false);
  assert.notDeepEqual(zany[0].size, zany[1].size);
  assert.equal(faceLayers(manifest, "face_money_mouth", false)[1].mirror, false);
  const decorations = {
    face_joy_tears: ["facial_part_tear_drop", 2],
    face_grinning_sweat: ["facial_part_tear_drop", 1],
    face_sunglasses: ["facial_part_sunglasses", 1],
    face_smiling_tear: ["facial_part_tear_drop", 1],
    face_sad_relieved: ["facial_part_tear_drop", 1],
    face_sleepy: ["facial_part_sleep_bubble", 1],
    face_sleeping: ["facial_part_sleep_z", 1],
    face_drooling: ["facial_part_tear_drop", 1],
    face_downcast_sweat: ["facial_part_tear_drop", 1],
    face_money_mouth: ["facial_part_tongue", 1],
    face_crying: ["facial_part_tear_drop", 1],
    face_loudly_crying: ["facial_part_tear_stream", 2],
    face_halo: ["facial_part_halo", 1],
  };
  for (const [name, [part, count]] of Object.entries(decorations)) {
    const before = faceLayers(manifest, name, false).filter((layer) => layer.part === part);
    const after = faceLayers(manifest, name, true).filter((layer) => layer.part === part);
    assert.equal(before.length, count, name);
    assert.deepEqual(after, before, name);
  }
  for (const name of ["face_smirking", "face_unamused"]) {
    assert.equal(faceLayers(manifest, name, false)[1].mirror, false);
  }
  for (const invalid of [
    "face_bad/name",
    "face_../neutral",
    "face_",
    "face_slightly_smiling".repeat(20),
  ]) {
    assert.equal(validSnapshot(snapshot({ face: invalid })), false, invalid);
  }
});

test("snapshots and preparations are validated before use", () => {
  assert.ok(validSnapshot(snapshot()));
  assert.ok(validSnapshot(snapshot({ selected: false, paddle_ids: [] })));
  assert.equal(validSnapshot(snapshot({ type: "other_snapshot" })), false);
  assert.equal(validSnapshot(snapshot({ face: "../evil" })), false);
  assert.equal(validSnapshot(snapshot({ color: "red" })), false);
  assert.equal(validSnapshot(snapshot({ look: { ...look, outline_colors: ["fd8702"] } })), false);
  assert.equal(validSnapshot(snapshot({ paddle_size: [0.2, 0] })), false);
  assert.ok(validPreparation(preparation()));
  assert.equal(validPreparation(preparation({ look: undefined })), false);
});
