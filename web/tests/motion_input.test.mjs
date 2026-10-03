import test from "node:test";
import assert from "node:assert/strict";
import { MotionInput } from "../public/motion_input.js";

function fixture(overrides = {}) {
  let now = 0;
  const target = new EventTarget();
  const environment = {
    target,
    secure: true,
    motion: {},
    orientation: {},
    now: () => now,
    screenAngle: () => 90,
    ...overrides,
  };
  return {
    input: new MotionInput(environment),
    event: (type, values) => target.dispatchEvent(Object.assign(new Event(type), values)),
    time: (value) => (now = value),
  };
}
test("both sensor permission APIs run before either promise resolves", async () => {
  const calls = [];
  let grant;
  const pending = new Promise((resolve) => (grant = resolve));
  const f = fixture({
    motion: {
      requestPermission: () => {
        calls.push("motion");
        return pending;
      },
    },
    orientation: {
      requestPermission: () => {
        calls.push("orientation");
        return Promise.resolve("granted");
      },
    },
  });
  const request = f.input.requestPermission();
  assert.deepEqual(calls, ["motion", "orientation"]);
  assert.equal(f.input.status(), "requesting");
  grant("denied");
  await request;
  assert.equal(f.input.motionPermission, "denied");
  assert.equal(f.input.orientationPermission, "granted");
  f.event("deviceorientation", { alpha: 0, beta: 90, gamma: null, absolute: false });
  assert.deepEqual(f.input.sample().orientation, [0, 90, null]);
});
test("null axes, per-stream ages, suspension and teardown stay observable", async () => {
  const f = fixture();
  await f.input.requestPermission();
  assert.equal(f.input.status(), "waiting");
  f.time(100);
  f.event("devicemotion", {
    acceleration: { x: 0, y: NaN, z: 2 },
    accelerationIncludingGravity: null,
    rotationRate: { alpha: 1, beta: null, gamma: Infinity },
    interval: 16,
  });
  f.time(200);
  assert.deepEqual(f.input.sample().acceleration, [0, null, 2]);
  assert.deepEqual(f.input.sample().rotation_rate, [1, null, null]);
  assert.equal(f.input.sample().motion_age_msec, 100);
  assert.equal(f.input.sample().orientation_age_msec, null);
  f.time(1201);
  assert.equal(f.input.status(), "stale");
  f.input.suspend();
  assert.equal(f.input.status(), "suspended");
  f.input.resume();
  assert.equal(f.input.status(), "waiting");
  assert.deepEqual(f.input.sample().acceleration, [null, null, null]);
  f.input.stop();
  f.event("devicemotion", { acceleration: { x: 9, y: 9, z: 9 } });
  assert.deepEqual(f.input.sample().acceleration, [null, null, null]);
});
test("insecure, unsupported, errors and cancelled permission requests are distinct", async () => {
  const insecure = fixture({ secure: false });
  await insecure.input.requestPermission();
  assert.equal(insecure.input.status(), "insecure");
  const unsupported = fixture({ motion: undefined, orientation: undefined });
  await unsupported.input.requestPermission();
  assert.equal(unsupported.input.status(), "unsupported");
  const errors = fixture({
    motion: {
      requestPermission: () => {
        throw new Error();
      },
    },
    orientation: { requestPermission: () => Promise.reject(new Error()) },
  });
  await errors.input.requestPermission();
  assert.equal(errors.input.status(), "error");
  let grant;
  const cancelled = fixture({
    motion: { requestPermission: () => new Promise((resolve) => (grant = resolve)) },
    orientation: undefined,
  });
  const permission = cancelled.input.requestPermission();
  cancelled.input.stop();
  grant("granted");
  await permission;
  assert.equal(cancelled.input.active, false);
});
