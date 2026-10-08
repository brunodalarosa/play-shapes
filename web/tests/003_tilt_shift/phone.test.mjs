import test from "node:test";
import assert from "node:assert/strict";
import { TiltShiftPhone, validTiltSnapshot } from "../../build/003_tilt_shift/tilt_shift_phone.js";

const snapshot = (ids = ["orange_left"]) => ({
  type: "tilt_shift_snapshot",
  generation: "shift",
  sequence: 1,
  phase: "active",
  round: 1,
  team: 0,
  angle_radians: 2.5,
  paddle_ids: ids,
  paddle_size: [0.1, 0.01],
});

test("personalized guide validates bounded host data and rejects non-finite or forged geometry", () => {
  assert.equal(validTiltSnapshot(snapshot()), true);
  for (const mutation of [
    { angle_radians: NaN },
    { sequence: -1 },
    { team: 2 },
    { round: 0 },
    { paddle_size: [0.1, 0] },
    { paddle_ids: ["a", "a"] },
    { phase: "lobby" },
    { generation: "" },
    { selected: "yes" },
    { ready_available: 1 },
    { round_token: "" },
    { paddle_ids: [], selected: true },
    { paddle_ids: Array.from({ length: 6 }, (_, i) => String(i)) },
  ])
    assert.equal(validTiltSnapshot({ ...snapshot(), ...mutation }), false);
});

test("five host assignments still draw one canonical guide and obsolete snapshots cannot rotate it", async () => {
  const saved = ["ResizeObserver", "Image", "fetch", "devicePixelRatio"].map((key) => [
    key,
    Object.getOwnPropertyDescriptor(globalThis, key),
  ]);
  let slices = 0,
    rotation = 0;
  const context = {
    setTransform() {},
    clearRect() {},
    translate() {},
    rotate(value) {
      rotation = value;
    },
    drawImage() {
      slices++;
    },
  };
  const elements = new Map();
  const element = () => ({
    hidden: false,
    disabled: false,
    addEventListener() {},
    setAttribute() {},
    clientWidth: 844,
    clientHeight: 390,
    getContext: () => context,
  });
  const surface = {
    ...element(),
    querySelector: (key) => {
      if (!elements.has(key)) elements.set(key, element());
      return elements.get(key);
    },
  };
  const stream = {
    active: true,
    requestPermission: async () => {},
    requestCalibration: () => true,
  };
  try {
    globalThis.ResizeObserver = class {
      observe() {}
    };
    globalThis.Image = class {
      complete = true;
      naturalWidth = 673;
      addEventListener() {}
    };
    globalThis.devicePixelRatio = 1;
    globalThis.fetch = async () => ({
      ok: true,
      json: async () => ({
        assets: Object.fromEntries(
          ["orange", "blue", "neutral"].map((team) => [
            `paddles/paddle_${team}.png`,
            {
              visible_bounds_px: [10, 9, 663, 151],
            },
          ]),
        ),
      }),
    });
    const phone = new TiltShiftPhone(surface, stream, () => {});
    await new Promise((resolve) => setImmediate(resolve));
    phone.preparation(
      {
        generation: "shift",
        calibrated: true,
        usable: true,
        capture_state: "live",
        angle_radians: 0,
        paddle_size: [0.1, 0.01],
      },
      false,
    );
    slices = 0;
    assert.equal(phone.snapshot(snapshot(["a", "b", "c", "d", "e"])), true);
    assert.equal(slices, 3, "exactly one beam uses three canonical cap/center slices");
    assert.equal(rotation, 2.5, "the host angle is drawn without local sensor inference");
    assert.equal(elements.get("#tilt-actions").hidden, true, "ordinary play has no controls");
    assert.equal(
      phone.snapshot({ ...snapshot(), generation: "obsolete", angle_radians: 9 }),
      false,
    );
    assert.equal(phone.snapshot({ ...snapshot(), sequence: 0, angle_radians: 9 }), false);
    assert.equal(rotation, 2.5);
    slices = 0;
    assert.equal(phone.snapshot({ ...snapshot([]), sequence: 2, selected: false }), true);
    assert.equal(elements.get("canvas").hidden, true, "waiting hides the movement guide");
    assert.equal(slices, 0, "a spectator draws no paddle");
    assert.equal(
      phone.snapshot({
        ...snapshot(),
        sequence: 3,
        phase: "preparing",
        round_token: "2:1",
        selected: true,
        ready_available: true,
        calibration_available: true,
        calibrated: true,
        usable: true,
        ready: true,
      }),
      true,
    );
    assert.equal(elements.get("#tilt-ready").textContent, "CANCEL");
    assert.equal(
      elements.get("#tilt-calibrate").disabled,
      false,
      "recalibration remains available after READY",
    );
    phone.preparation(
      {
        generation: "next",
        calibrated: false,
        usable: false,
        capture_state: "denied",
        angle_radians: 0,
        paddle_size: [0.1, 0.01],
      },
      false,
    );
    assert.equal(elements.get("#tilt-ready").disabled, true);
    assert.equal(elements.get("#tilt-state").textContent, "Motion access was denied");
    phone.disconnect();
    assert.equal(elements.get("#tilt-permission").disabled, true);
    phone.hide();
    assert.equal(surface.hidden, true);
  } finally {
    for (const [key, descriptor] of saved) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor);
      else delete globalThis[key];
    }
  }
});
