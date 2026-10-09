import test from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { MotionStream } from "../build/motion_stream.js";

test("generic capture scopes feedback, skips queued input and retires listeners and permission races", async () => {
  const names = [
    "window",
    "document",
    "screen",
    "location",
    "WebSocket",
    "performance",
    "setInterval",
    "clearInterval",
  ];
  const saved = names.map((name) => Object.getOwnPropertyDescriptor(globalThis, name));
  class TrackedTarget extends EventTarget {
    listeners = new Set();
    addEventListener(name, callback) {
      this.listeners.add(callback);
      super.addEventListener(name, callback);
    }
    removeEventListener(name, callback) {
      this.listeners.delete(callback);
      super.removeEventListener(name, callback);
    }
  }
  let now = 0,
    calls = 0,
    resolvePermission;
  const target = new TrackedTarget();
  const document = Object.assign(new TrackedTarget(), { hidden: false });
  const permission = {
    requestPermission: () => {
      calls++;
      return resolvePermission
        ? new Promise((resolve) => resolvePermission.push(resolve))
        : Promise.resolve("granted");
    },
  };
  const globals = {
    window: Object.assign(target, {
      isSecureContext: true,
      DeviceMotionEvent: permission,
      DeviceOrientationEvent: permission,
    }),
    document,
    screen: { orientation: { angle: 90 } },
    location: { protocol: "https:", hostname: "127.0.0.1" },
    WebSocket: { OPEN: 1 },
    performance: { now: () => now },
    setInterval: () => 1,
    clearInterval: () => {},
  };
  for (const name of names)
    Object.defineProperty(globalThis, name, {
      configurable: true,
      writable: true,
      value: globals[name],
    });
  try {
    const messages = [];
    const socket = {
      readyState: 1,
      bufferedAmount: 0,
      url: "wss://127.0.0.1:8081",
      send: (data) => messages.push(JSON.parse(data)),
    };
    const stream = new MotionStream(() => socket);
    const subscription = (id) => ({ subscription_id: id, send_hz: 999, stale_msec: 1000 });
    const orientation = (beta) =>
      target.dispatchEvent(
        Object.assign(new Event("deviceorientation"), { alpha: 0, beta, gamma: 80 }),
      );
    stream.begin(subscription("first"));
    assert.equal(calls, 0);
    const request = stream.requestPermission();
    assert.equal(calls, 2, "both APIs are called inside the gesture");
    await request;
    now = 100;
    orientation(30);
    stream.tick();
    assert.deepEqual(messages.at(-1).sample.orientation, [0, 30, 80]);
    const samples = () => messages.filter((value) => value.type === "motion_sample");
    stream.tick();
    assert.equal(samples().length, 1, "repeated ticks cannot exceed the sample bound");
    assert.ok(stream.requestCalibration());
    assert.deepEqual(messages.at(-1), { type: "motion_calibrate", subscription_id: "first" });
    const state = { calibrated: true, usable: true, capture_state: "live" };
    assert.equal(stream.feedback("old", state), false);
    assert.equal(stream.feedback("first", state), true);
    socket.bufferedAmount = 1;
    const before = messages.length;
    now = 400;
    orientation(70);
    stream.tick();
    assert.equal(messages.length, before, "any queued gameplay bytes drop the sample");
    socket.bufferedAmount = 0;
    now = 500;
    orientation(-20);
    stream.tick();
    assert.deepEqual(
      samples().at(-1).sample.orientation,
      [0, -20, 80],
      "only the latest pose resumes",
    );
    assert.equal(samples().at(-1).sequence, 2);
    document.hidden = true;
    document.dispatchEvent(new Event("visibilitychange"));
    assert.equal(messages.at(-1).diagnostics.state, "suspended");
    document.hidden = false;
    document.dispatchEvent(new Event("visibilitychange"));
    assert.equal(messages.at(-1).diagnostics.state, "waiting");
    stream.begin(subscription("second"));
    assert.equal(stream.controlState, undefined);
    assert.equal(stream.stop("first"), false);
    assert.ok(stream.active);
    resolvePermission = [];
    const pending = stream.requestPermission();
    stream.stop();
    for (const resolve of resolvePermission) resolve("granted");
    await pending;
    assert.equal(target.listeners.size, 0);
    resolvePermission = undefined;
    const traffic = [];
    const streams = Array.from({ length: 10 }, (_, phone) => {
      const connection = { ...socket, send: (json) => traffic.push({ phone, json }) };
      return new MotionStream(() => connection);
    });
    const token = "0123456789abcdef00000000";
    streams.forEach((value, phone) => value.begin(subscription(token.slice(0, 23) + phone)));
    await Promise.all(streams.map((value) => value.requestPermission()));
    for (let frame = 0; frame < 1320; frame++) {
      now += 17;
      orientation(Math.sin(frame / 10) * 60);
      for (const value of streams) value.tick();
      if (frame === 119) traffic.length = 0;
    }
    const byType = (type) => traffic.filter((value) => JSON.parse(value.json).type === type);
    const summary = (items) => {
      const sizes = items.map((value) => Buffer.byteLength(value.json)).sort((a, b) => a - b);
      return {
        count: items.length,
        min: sizes[0],
        p95: sizes[Math.ceil(sizes.length * 0.95) - 1],
        max: sizes.at(-1),
        total: sizes.reduce((sum, size) => sum + size, 0),
      };
    };
    const sampleTraffic = summary(byType("motion_sample"));
    const statuses = summary(byType("motion_status"));
    const rate = sampleTraffic.count / 10 / 20.4;
    assert.ok(rate <= 30 && rate >= 29);
    const largeSample = JSON.parse(byType("motion_sample")[0].json);
    largeSample.sequence = 999999999999;
    for (const field of ["rotation_rate", "acceleration", "acceleration_gravity"])
      largeSample.sample[field] = [
        999999.9999999999, -1.234567890123456e-100, 1.234567890123456e-10,
      ];
    largeSample.sample.orientation = [359.99999999999994, -179.99999999999997, 89.99999999999999];
    const calibration = { type: "motion_calibrate", subscription_id: token };
    const feedback = {
      type: "motion_control_state",
      subscription_id: token,
      control_state: {
        calibrated: true,
        usable: true,
        capture_state: "live",
        accepted: true,
        reason: "calibrated",
      },
    };
    const report = {
      phones: 10,
      virtualDurationSeconds: 20.4,
      sensorEventHz: 1000 / 17,
      sampleHzPerPhone: rate,
      statusHzPerPhone: statuses.count / 10 / 20.4,
      samples: sampleTraffic,
      statuses,
      perPhoneJsonBytesPerSecond: (sampleTraffic.total + statuses.total) / 10 / 20.4,
      aggregateJsonBytesPerSecond: (sampleTraffic.total + statuses.total) / 20.4,
      largeValidNumericFixtureBytes: Buffer.byteLength(JSON.stringify(largeSample)),
      calibrationRequestBytes: Buffer.byteLength(JSON.stringify(calibration)),
      calibrationReplyBytes: Buffer.byteLength(JSON.stringify(feedback)),
      excluded: "WebSocket/TLS framing, network delay, physical sensors, host feedback",
    };
    const directory = fileURLToPath(
      new URL("../../test-results/tilt-shift/motion/", import.meta.url),
    );
    mkdirSync(directory, { recursive: true });
    writeFileSync(`${directory}/traffic.json`, JSON.stringify(report, null, 2));
    console.log("Synthetic motion traffic", report);
    for (const value of streams) value.stop();
    assert.equal(target.listeners.size, 0);
    assert.equal(document.listeners.size, 0);
    assert.equal(stream.active, false);
    stream.begin(subscription("third"));
    assert.equal(messages.at(-1).diagnostics.state, "idle");
    target.dispatchEvent(new Event("pagehide"));
    assert.equal(stream.active, false);
    assert.equal(target.listeners.size, 0);
  } finally {
    names.forEach((name, index) =>
      saved[index]
        ? Object.defineProperty(globalThis, name, saved[index])
        : delete globalThis[name],
    );
  }
});
