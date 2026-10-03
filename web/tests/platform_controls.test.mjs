import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createLobbyContext } from "../public/lobby_input.js";
import { createPreviewContext } from "./fixtures/platform_context.mjs";

class Element extends EventTarget {
  hidden = true;
  textContent = "";
  captures = new Set();
  attributes = new Map();
  classes = new Set();
  classList = {
    add: (name) => this.classes.add(name),
    remove: (name) => this.classes.delete(name),
    toggle: (name, value) => (value ? this.classes.add(name) : this.classes.delete(name)),
  };
  style = { setProperty() {} };
  setAttribute(name, value) {
    this.attributes.set(name, value);
  }
  setPointerCapture(id) {
    if (this.captureFails) throw Error("capture denied");
    this.captures.add(id);
  }
  hasPointerCapture(id) {
    return this.captures.has(id);
  }
  releasePointerCapture(id) {
    this.captures.delete(id);
    this.dispatchEvent(pointer("lostpointercapture", id));
  }
}
const pointer = (type, id = 1, extra = {}) =>
  Object.assign(new Event(type, { cancelable: true }), {
    pointerId: id,
    pointerType: "touch",
    button: 0,
    ...extra,
  });
const key = (type, value = " ", repeat = false) =>
  Object.assign(new Event(type, { cancelable: true }), { key: value, repeat });
let fixtureId = 0;

async function withControls(verify) {
  const screen = new Element(),
    stick = new Element(),
    button = new Element(),
    root = new Element();
  const window = Object.assign(new EventTarget(), {
    innerHeight: 844,
    visualViewport: Object.assign(new EventTarget(), { height: 844 }),
  });
  const document = Object.assign(new EventTarget(), {
    documentElement: root,
    hidden: false,
    hasFocus: () => true,
  });
  const timers = new Map(),
    managers = [],
    sent = [];
  let clock = 0,
    timerId = 0;
  const globals = {
    window,
    document,
    performance: { now: () => clock },
    setInterval: (fn, interval) => {
      timers.set(++timerId, { fn, interval });
      return timerId;
    },
    clearInterval: (id) => timers.delete(id),
    __platformJoystickFactory: (options) => {
      const handlers = new Map();
      const manager = {
        options,
        destroyed: false,
        on: (name, handler) => handlers.set(name, handler),
        emit: (name, x = 0, y = 0) => handlers.get(name)?.({ data: { vector: { x, y } } }),
        destroy() {
          this.destroyed = true;
          this.emit("end");
        },
      };
      managers.push(manager);
      return manager;
    },
  };
  const saved = new Map(
    Object.keys(globals).map((name) => [name, Object.getOwnPropertyDescriptor(globalThis, name)]),
  );
  for (const [name, value] of Object.entries(globals))
    Object.defineProperty(globalThis, name, { configurable: true, writable: true, value });
  let controls;
  try {
    // Keep real compiled handlers/state/lifecycle; replace only NippleJS's DOM renderer.
    const stub =
      "data:text/javascript," +
      encodeURIComponent(
        "export default { create: options => globalThis.__platformJoystickFactory(options) }",
      );
    let source = readFileSync(new URL("../public/platform_controls.js", import.meta.url), "utf8");
    source = source.replace(/from "(\.\/[^"]+)"/g, (_, path) => {
      const bundled = new URL("../public/" + path.slice(2), import.meta.url).href;
      return `from "${path === "./vendor/nipplejs.mjs" ? stub : bundled}"`;
    });
    const { PlatformControls } = await import(
      "data:text/javascript;base64," +
        Buffer.from(source + `\n// fixture ${++fixtureId}`).toString("base64")
    );
    controls = new PlatformControls(
      screen,
      stick,
      button,
      createLobbyContext((value) => sent.push(value)),
    );
    controls.activate();
    await verify({
      controls,
      screen,
      stick,
      button,
      window,
      document,
      root,
      managers,
      sent,
      timers,
      at: (value) => {
        clock = value;
      },
      refresh: () => {
        for (const { fn } of timers.values()) fn();
      },
    });
  } finally {
    controls?.destroy();
    for (const [name, descriptor] of saved) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor);
      else delete globalThis[name];
    }
  }
}

test("actual controls unlock both axes and release once with the latest unsent FALL/JUMP mode", async () => {
  await withControls(({ managers, button, sent, at }) => {
    const joystick = managers.at(-1);
    assert.notEqual(joystick.options.lockX, true);
    assert.notEqual(joystick.options.lockY, true);
    joystick.emit("move", 0.7, 0);
    button.dispatchEvent(pointer("pointerdown", 42));
    button.dispatchEvent(pointer("pointerdown", 43));
    at(10);
    joystick.emit("move", 0, -0.8); // Inside the 45 ms movement throttle.
    assert.equal(sent.length, 1);
    assert.equal(button.textContent, "FALL");
    assert.equal(button.attributes.get("aria-label"), "Fall");
    button.dispatchEvent(pointer("pointerup", 43));
    assert.equal(button.classes.has("is-held"), true);
    button.dispatchEvent(pointer("pointerup", 42));
    button.dispatchEvent(pointer("pointerup", 42));
    assert.deepEqual(sent.at(-1), {
      type: "lobby_fall_release",
      action: "fall",
      horizontal: 0,
      vertical: -0.8,
      stance: "crouch",
    });
    assert.equal(sent.length, 2);
    assert.equal(button.captures.size, 0);
    button.dispatchEvent(pointer("pointerdown", 44));
    at(11);
    joystick.emit("move", 0.6, -0.6);
    assert.equal(button.textContent, "JUMP");
    assert.equal(button.attributes.get("aria-label"), "Jump");
    button.dispatchEvent(pointer("pointerup", 44));
    assert.equal(sent.at(-1).type, "lobby_jump_release");
    assert.equal(sent.at(-1).vertical, -0.6);
  });
});

test("separate stick/button cancellation and capture failures do not create release actions", async () => {
  await withControls(({ managers, stick, button, sent }) => {
    managers.at(-1).emit("move", 0, -1);
    button.dispatchEvent(pointer("pointerdown", 7));
    button.dispatchEvent(pointer("pointercancel", 8));
    assert.equal(button.classes.has("is-held"), true);
    button.dispatchEvent(pointer("lostpointercapture", 7));
    assert.equal(button.textContent, "FALL");
    assert.equal(sent.filter((value) => value.action).length, 0);
    button.dispatchEvent(pointer("pointerdown", 9));
    stick.dispatchEvent(pointer("pointercancel", 1));
    assert.equal(button.textContent, "JUMP");
    assert.deepEqual(sent.at(-1), {
      type: "lobby_move",
      horizontal: 0,
      vertical: 0,
      stance: "neutral",
    });
    button.dispatchEvent(pointer("pointerup", 9));
    assert.equal(sent.at(-1).action, "jump");
    button.captureFails = true;
    button.dispatchEvent(pointer("pointerdown", 10));
    button.dispatchEvent(pointer("pointerup", 10));
    button.dispatchEvent(pointer("pointerdown", 11, { pointerType: "mouse", button: 2 }));
    button.dispatchEvent(pointer("pointerup", 11));
    assert.equal(sent.filter((value) => value.action).length, 1);
  });
});

test("every lifecycle reset neutralizes both axes, action ownership and label before reactivation", async () => {
  await withControls(({ controls, managers, button, sent, window, document }) => {
    for (const [surface, eventName] of [
      [window, "blur"],
      [window, "pagehide"],
      [window, "resize"],
      [window, "orientationchange"],
      [window.visualViewport, "resize"],
      [document, "fullscreenchange"],
      [document, "visibilitychange"],
    ]) {
      managers.at(-1).emit("move", 0.1, -0.9);
      button.dispatchEvent(pointer("pointerdown", 4));
      document.hidden = eventName === "visibilitychange";
      surface.dispatchEvent(new Event(eventName));
      assert.equal(button.textContent, "JUMP", eventName);
      assert.equal(button.attributes.get("aria-label"), "Jump");
      assert.equal(button.captures.size, 0);
      assert.equal(button.classes.has("is-held"), false);
      assert.deepEqual(sent.at(-1), {
        type: "lobby_move",
        horizontal: 0,
        vertical: 0,
        stance: "neutral",
      });
      const count = sent.length;
      button.dispatchEvent(pointer("pointerup", 4));
      assert.equal(sent.length, count);
      document.hidden = false;
      window.dispatchEvent(new Event("focus"));
    }
    managers.at(-1).emit("move", 0, -1);
    button.dispatchEvent(pointer("pointerdown", 5));
    controls.deactivate();
    const count = sent.length;
    controls.activate();
    button.dispatchEvent(pointer("pointerup", 5));
    assert.equal(sent.length, count);
    assert.equal(button.textContent, "JUMP");
    button.dispatchEvent(pointer("pointerdown", 6));
    button.dispatchEvent(pointer("pointerup", 6));
    assert.equal(sent.at(-1).action, "jump");
  });
});

test("Space/Enter release and assistive click retain contextual activation without repeats or canceled keys", async () => {
  await withControls(({ managers, button, window, sent }) => {
    managers.at(-1).emit("move", 0, -1);
    button.dispatchEvent(key("keydown"));
    button.dispatchEvent(key("keydown", " ", true));
    assert.equal(sent.filter((value) => value.action).length, 0);
    button.dispatchEvent(key("keyup"));
    button.dispatchEvent(key("keyup"));
    assert.equal(sent.at(-1).action, "fall");
    button.dispatchEvent(key("keydown", "Enter"));
    window.dispatchEvent(new Event("blur"));
    const count = sent.length;
    button.dispatchEvent(key("keyup", "Enter"));
    assert.equal(sent.length, count);
    window.dispatchEvent(new Event("focus"));
    button.dispatchEvent(Object.assign(new Event("click"), { detail: 0 }));
    assert.equal(sent.at(-1).action, "jump");
    button.dispatchEvent(key("keydown", "Enter"));
    button.dispatchEvent(new Event("blur"));
    const afterBlur = sent.length;
    button.dispatchEvent(key("keyup", "Enter"));
    assert.equal(sent.length, afterBlur);
  });
});

test("move sends stay bounded while local axes and held refresh track every event", async () => {
  await withControls(({ managers, sent, at, refresh, timers }) => {
    const joystick = managers.at(-1);
    assert.equal([...timers.values()][0].interval, 100);
    for (let time = 0; time < 200; time++) {
      at(time);
      joystick.emit("move", 0.4, time % 2 ? -0.6 : 0.6);
    }
    assert.equal(sent.length, 5); // 0, 45, 90, 135, 180 ms.
    refresh();
    assert.equal(sent.at(-1).vertical, -0.6);
    joystick.emit("end");
    refresh();
    assert.equal(sent.length, 7);
    assert.equal(sent.at(-1).horizontal, 0);
    assert.equal(sent.at(-1).vertical, 0);
  });
});

test("another platform adapter mounts the same component and context changes discard old touches/listeners", async () => {
  await withControls(({ controls, managers, button, sent, timers, window }) => {
    const firstJoystick = managers.at(-1);
    firstJoystick.emit("move", 0, -1);
    button.dispatchEvent(pointer("pointerdown", 5));
    const preview = [];
    controls.setContext(createPreviewContext((value) => preview.push(value)));
    assert.equal(firstJoystick.destroyed, true);
    assert.equal(sent.at(-1).stance, "neutral");
    assert.equal(button.textContent, "JUMP");
    button.dispatchEvent(pointer("pointerup", 5));
    firstJoystick.emit("move", 0, -1); // A displaced callback cannot affect the new context.
    assert.equal(preview.length, 0);
    managers.at(-1).emit("move", 0, -0.8);
    button.dispatchEvent(pointer("pointerdown", 6));
    button.dispatchEvent(pointer("pointerup", 6));
    assert.deepEqual(preview.at(-1), {
      context: "preview",
      intent: {
        kind: "release",
        action: "fall",
        input: { axes: { x: 0, y: -0.8 }, stance: "crouch" },
      },
    });
    const oldCount = sent.length;
    controls.destroy();
    assert.equal(timers.size, 0);
    assert.equal(preview.at(-1).intent.input.stance, "neutral");
    const count = preview.length;
    window.dispatchEvent(new Event("focus"));
    button.dispatchEvent(Object.assign(new Event("click"), { detail: 0 }));
    assert.equal(preview.length, count);
    assert.equal(sent.length, oldCount);
  });
});
