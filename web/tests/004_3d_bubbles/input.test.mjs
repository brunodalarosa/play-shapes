import { test } from "node:test";
import assert from "node:assert/strict";
import { canTouch, displacement, quantize, TouchInput } from "../../build/004_3d_bubbles/input.js";
import { snapshot } from "./fixtures.mjs";

function controller(initialSequence = 80) {
  const messages = [];
  let sequence = initialSequence;
  let connected = true;
  let state = snapshot();
  const input = new TouchInput(
    () => canTouch(state, connected),
    () => ++sequence,
    (message) => messages.push(message),
  );
  return {
    input,
    messages,
    setState: (value) => {
      state = value;
    },
    disconnect: () => {
      connected = false;
    },
  };
}

test("net displacement uses area dimensions, screen axes and a clamped share", () => {
  assert.deepEqual(displacement([30, 80], [230, -20], [400, 200]), [0.5, -0.5]);
  assert.deepEqual(displacement([30, 80], [-2000, 2000], [400, 200]), [-1, 1]);
  assert.deepEqual(displacement([0, 0], [1, -1], [0, 0]), [1, -1]);
  assert.deepEqual(quantize([0.13, -0.39]), [1, -4]);
  assert.deepEqual(quantize([1, -1]), [4, -4]);
  assert.deepEqual(quantize([0.01, -0.01]), [0, 0]);
});

test("start and release send synchronously with a single growing sequence and exact fields", () => {
  const { input, messages } = controller();
  assert.equal(input.start([100, 200], [400, 800], 0), true);
  assert.deepEqual(messages, [{ type: "bubbles_3d_touch", input_seq: 81, stage: "start" }]);
  assert.equal(input.start([0, 0], [400, 800], 1), false);
  input.release([300, 0]);
  assert.deepEqual(messages[1], {
    type: "bubbles_3d_release",
    input_seq: 81,
    displacement: [0.5, -0.25],
  });
  input.start([0, 0], [400, 800], 10);
  input.release([0, 0]);
  assert.equal(messages[2].input_seq, 82);
  assert.deepEqual(messages[3].displacement, [0, 0]);
});

test("drag sends only changed quantized values after 70 ms and flushes a pending change", () => {
  const { input, messages } = controller();
  input.start([0, 0], [400, 800], 0);
  input.move([80, 80], 69);
  assert.equal(messages.length, 1);
  input.tick(70);
  assert.deepEqual(messages[1], {
    type: "bubbles_3d_touch",
    input_seq: 81,
    stage: "drag",
    drag: [2, 1],
  });
  input.move([81, 81], 140);
  assert.equal(messages.length, 2);
  input.move([-160, 320], 141);
  assert.deepEqual(messages[2].drag, [-4, 4]);
});

test("a held touch resends its current direction every 600 ms, including zero", () => {
  const { input, messages } = controller();
  input.start([0, 0], [400, 800], 0);
  input.tick(599);
  assert.equal(messages.length, 1);
  input.tick(600);
  input.tick(1199);
  assert.equal(messages.length, 2);
  input.tick(1200);
  assert.deepEqual(
    messages.slice(1).map((message) => message.drag),
    [
      [0, 0],
      [0, 0],
    ],
  );
  input.move([160, 160], 1270);
  input.tick(1870);
  assert.deepEqual(messages.at(-1).drag, [4, 2]);
});

test("the 48 drag cap includes refreshes and still allows release and a new touch", () => {
  const { input, messages } = controller();
  input.start([0, 0], [400, 800], 0);
  for (let index = 1; index <= 60; index++) input.tick(index * 600);
  assert.equal(messages.filter((message) => message.stage === "drag").length, 48);
  input.release([100, 200]);
  assert.equal(messages.at(-1).type, "bubbles_3d_release");
  input.start([0, 0], [400, 800], 40000);
  input.move([100, 200], 40070);
  assert.equal(messages.at(-1).stage, "drag");
  assert.equal(messages.at(-1).input_seq, 82);
});

test("cancel ends the touch once and never turns into a release", () => {
  const { input, messages } = controller();
  input.start([0, 0], [400, 800], 0);
  input.cancel();
  input.cancel();
  input.release([300, 700]);
  input.tick(600);
  assert.deepEqual(messages[1], { type: "bubbles_3d_touch", input_seq: 81, stage: "cancel" });
  assert.equal(messages.length, 2);
});

test("input is gated by host phase, host connection, leave and transport availability", () => {
  for (const phase of ["instructions", "countdown", "results", "lobby_return"]) {
    const { input, messages, setState } = controller();
    setState(snapshot({ phase }));
    assert.equal(input.start([0, 0], [400, 800], 0), false);
    assert.equal(messages.length, 0);
  }
  for (const state of [snapshot({ connected: false }), snapshot({ left: true }), undefined])
    assert.equal(canTouch(state, true), false);
  const { input, messages, disconnect } = controller();
  input.start([0, 0], [400, 800], 0);
  disconnect();
  input.move([200, 400], 100);
  input.release([200, 400]);
  input.cancel();
  assert.equal(messages.length, 1);
});
