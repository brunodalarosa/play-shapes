import test from "node:test";
import assert from "node:assert/strict";
import { MotionLabController } from "../public/motion_lab.js";

test("phone lab requires a gesture, recovers status, skips backpressure and stops on exit", async () => {
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
  let now = 0,
    clears = 0,
    permissionCalls = 0;
  const target = new EventTarget(),
    document = Object.assign(new EventTarget(), { hidden: false });
  const permission = {
    requestPermission: async () => {
      permissionCalls++;
      return "granted";
    },
  };
  const globals = {
    window: Object.assign(target, {
      isSecureContext: true,
      DeviceMotionEvent: permission,
      DeviceOrientationEvent: permission,
    }),
    document,
    screen: { orientation: { angle: 0 } },
    location: { protocol: "https:", hostname: "192.168.2.79" },
    WebSocket: { OPEN: 1 },
    performance: { now: () => now },
    setInterval: () => 1,
    clearInterval: () => clears++,
  };
  for (const name of names)
    Object.defineProperty(globalThis, name, {
      configurable: true,
      writable: true,
      value: globals[name],
    });
  try {
    const panel = { hidden: true },
      button = Object.assign(new EventTarget(), { disabled: false }),
      readings = { textContent: "" },
      messages = [];
    const socket = {
      readyState: 1,
      bufferedAmount: 0,
      url: "wss://192.168.2.79:8081",
      send: (data) => messages.push(JSON.parse(data)),
    };
    const lab = new MotionLabController(panel, button, readings, () => socket);
    lab.begin({ subscription_id: "first", send_hz: 30, stale_msec: 1000 });
    assert.equal(permissionCalls, 0);
    assert.equal(panel.hidden, false);
    button.dispatchEvent(new Event("click"));
    assert.equal(permissionCalls, 2);
    await new Promise((resolve) => setImmediate(resolve));
    now = 100;
    target.dispatchEvent(
      Object.assign(new Event("deviceorientation"), {
        alpha: 0,
        beta: 90,
        gamma: null,
        absolute: false,
      }),
    );
    lab.tick();
    assert.deepEqual(messages.at(-1).sample.orientation, [0, 90, null]);
    now = 300;
    lab.tick();
    assert.ok(
      messages.some(
        (value) => value.type === "motion_status" && value.diagnostics.state === "live",
      ),
    );
    const before = messages.length;
    socket.bufferedAmount = 8192;
    now = 600;
    lab.tick();
    assert.equal(messages.length, before);
    assert.match(readings.textContent, /Sent: 3\.3 Hz/);
    socket.bufferedAmount = 0;
    document.hidden = true;
    document.dispatchEvent(new Event("visibilitychange"));
    lab.tick();
    now = 900;
    lab.tick();
    assert.equal(messages.at(-1).diagnostics.state, "suspended");
    document.hidden = false;
    document.dispatchEvent(new Event("visibilitychange"));
    now = 1200;
    lab.tick();
    assert.equal(messages.at(-1).diagnostics.state, "waiting");
    lab.stop();
    assert.equal(lab.active, false);
    assert.equal(panel.hidden, true);
    assert.ok(clears > 0);
    const stopped = messages.length;
    target.dispatchEvent(Object.assign(new Event("deviceorientation"), { alpha: 80 }));
    lab.tick();
    assert.equal(messages.length, stopped);
    lab.begin({ subscription_id: "second", send_hz: 30, stale_msec: 1000 });
    assert.equal(messages.at(-1).subscription_id, "second");
    assert.equal(messages.at(-1).diagnostics.state, "idle");
    lab.disconnect();
  } finally {
    names.forEach((name, index) =>
      saved[index]
        ? Object.defineProperty(globalThis, name, saved[index])
        : delete globalThis[name],
    );
  }
});
