import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  PlatformInputState,
  DEFAULT_PLATFORM_SETTINGS,
  classifyPlatformInput,
} from "../public/platform_input.js";

const neutral = { axes: { x: 0, y: 0 }, stance: "neutral" };
const fromVertical = (degrees, sign = 1) => [
  Math.sin((degrees * Math.PI) / 180),
  Math.cos((degrees * Math.PI) / 180) * sign,
];
function fixture(settings) {
  const sent = [];
  const input = new PlatformInputState((intent) => sent.push(intent), settings);
  input.activate();
  return { input, sent };
}

test("two-axis input preserves analog magnitude, signs and ordinary diagonals", () => {
  const { input } = fixture();
  for (const [x, y, stance] of [
    [0, 1, "look_up"],
    [0, -1, "crouch"],
    [1, 0, "move"],
    [-1, 0, "move"],
    [0.5, -0.5, "move"],
    [-0.4, 0.5, "move"],
  ]) {
    input.updateAxes(x, y);
    assert.deepEqual(input.snapshot(), { axes: { x, y }, stance });
  }
  input.updateAxes(1, -1);
  assert.ok(Math.abs(Math.hypot(...Object.values(input.snapshot().axes)) - 1) < 1e-12);
  assert.ok(input.snapshot().axes.x > 0 && input.snapshot().axes.y < 0);
  input.updateAxes(Number.MAX_VALUE, -Number.MAX_VALUE);
  assert.ok(Object.values(input.snapshot().axes).every(Number.isFinite));
});

test("dead zone has separate entry and exit thresholds without altering active magnitude", () => {
  const { input } = fixture();
  input.updateAxes(0, 0.19);
  assert.deepEqual(input.snapshot(), neutral);
  input.updateAxes(0, 0.2);
  assert.equal(input.snapshot().stance, "look_up");
  input.updateAxes(0, 0.18);
  assert.deepEqual(input.snapshot(), { axes: { x: 0, y: 0.18 }, stance: "look_up" });
  input.updateAxes(0, 0.16);
  assert.deepEqual(input.snapshot(), neutral);
  input.updateAxes(0, -0.19);
  assert.equal(input.action, "jump");
});

test("up/down sectors retain through boundary jitter then require deliberate re-entry", () => {
  for (const [sign, stance] of [
    [1, "look_up"],
    [-1, "crouch"],
  ]) {
    const { input } = fixture();
    input.updateAxes(...fromVertical(21, sign));
    assert.equal(input.snapshot().stance, "move");
    input.updateAxes(...fromVertical(19, sign));
    assert.equal(input.snapshot().stance, stance);
    for (const angle of [21, 25, 27, 23]) {
      input.updateAxes(...fromVertical(angle, sign));
      assert.equal(input.snapshot().stance, stance);
    }
    input.updateAxes(...fromVertical(29, sign));
    assert.equal(input.snapshot().stance, "move");
    input.updateAxes(...fromVertical(25, sign));
    assert.equal(input.snapshot().stance, "move");
    input.updateAxes(...fromVertical(19, -sign));
    assert.equal(input.snapshot().stance, sign === 1 ? "crouch" : "look_up");
  }
});

test("release uses the latest local axes and mode, including unsent sector transitions", () => {
  const { input, sent } = fixture();
  input.updateAxes(-0.7, 0);
  input.refresh();
  input.pressAction(42);
  input.pressAction(43);
  input.releaseAction(43);
  assert.equal(sent.length, 1);
  input.updateAxes(0.1, -0.8); // Deliberately not refreshed to transport.
  input.releaseAction(42);
  input.releaseAction(42);
  assert.deepEqual(sent.at(-1), {
    kind: "release",
    action: "fall",
    input: { axes: { x: 0.1, y: -0.8 }, stance: "crouch" },
  });
  assert.equal(sent.filter((value) => value.kind === "release").length, 1);
  assert.equal(input.stickHeld, true);
  input.pressAction(44);
  input.updateAxes(0.7, -0.7);
  input.releaseAction(44);
  assert.equal(sent.at(-1).action, "jump");
  input.pressAction(45);
  input.endStick();
  input.releaseAction(45);
  assert.deepEqual(sent.at(-1), { kind: "release", action: "jump", input: neutral });
});

test("cancellation, invalid input and inactive releases cannot schedule actions", () => {
  const { input, sent } = fixture();
  input.updateAxes(0, -1);
  for (const [x, y] of [
    [NaN, 0],
    [0, Infinity],
    [-Infinity, 1],
  ])
    assert.equal(input.updateAxes(x, y), false);
  input.pressAction(7);
  input.releaseAction(7, true);
  assert.equal(input.action, "fall"); // Canceling the button preserves the separate stick.
  input.pressAction(8);
  input.deactivate();
  input.releaseAction(8);
  input.refresh();
  input.activateAction();
  assert.deepEqual(sent, [{ kind: "move", input: neutral }]);
  input.activate();
  assert.deepEqual(input.snapshot(), neutral);
  assert.equal(input.actionHeld, false);
  input.activateAction();
  assert.deepEqual(sent.at(-1), { kind: "release", action: "jump", input: neutral });
  assert.deepEqual(classifyPlatformInput(NaN, 1, neutral), neutral);
});

test("keyboard ownership cancels cleanly and assistive activation uses the same action contract", () => {
  const { input, sent } = fixture();
  input.updateAxes(0, -0.8);
  input.pressKey(" ");
  input.pressKey("Enter");
  input.releaseKey("Enter");
  input.activateAction();
  assert.equal(sent.length, 0);
  input.releaseKey(" ");
  assert.equal(sent.at(-1).action, "fall");
  input.pressKey("Enter");
  input.cancel();
  const count = sent.length;
  input.releaseKey("Enter");
  assert.equal(sent.length, count);
  input.activateAction();
  assert.equal(sent.at(-1).action, "jump");
});

test("settings are tunable, snapshotted and shared with the generated host artifact", () => {
  const settings = {
    ...DEFAULT_PLATFORM_SETTINGS,
    verticalEnterDegrees: 10,
    verticalExitDegrees: 15,
  };
  const { input } = fixture(settings);
  settings.verticalEnterDegrees = 30;
  input.updateAxes(...fromVertical(16));
  assert.equal(input.snapshot().stance, "move");
  input.updateAxes(...fromVertical(9));
  assert.equal(input.snapshot().stance, "look_up");
  const snapshot = input.snapshot();
  snapshot.axes.x = 1;
  assert.notEqual(input.snapshot().axes.x, 1);
  for (const invalid of [
    { deadZone: undefined },
    { deadZone: NaN },
    { deadZone: 1 },
    { verticalExitDegrees: 45 },
    { verticalEnterDegrees: 30 },
    { refreshIntervalMsec: 350 },
  ]) {
    assert.throws(() => fixture({ ...DEFAULT_PLATFORM_SETTINGS, ...invalid }), RangeError);
  }
  const shared = JSON.parse(
    readFileSync(new URL("../public/platform_input_settings.json", import.meta.url)),
  );
  assert.deepEqual(shared, {
    version: 1,
    axisConvention: "x-right-y-up",
    ...DEFAULT_PLATFORM_SETTINGS,
  });
});
