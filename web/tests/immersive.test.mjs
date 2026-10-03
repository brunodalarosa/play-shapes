import { test } from "node:test";
import assert from "node:assert/strict";
import {
  attemptImmersive,
  protectControllerSurface,
  bindControllerLifecycle,
} from "../public/immersive.js";

test("fullscreen and orientation denials resolve as playable fallbacks", async () => {
  let orientationAttempted = false;
  await attemptImmersive(
    () => Promise.reject(new Error("Fullscreen denied")),
    () => {
      orientationAttempted = true;
      return Promise.reject(new Error("Orientation denied"));
    },
  );
  assert.equal(orientationAttempted, true);
});

test("missing fullscreen/orientation APIs and synchronous failures remain playable", async () => {
  await attemptImmersive(undefined, undefined);
  await attemptImmersive(
    () => {
      throw Error("unsupported");
    },
    () => {
      throw Error("denied");
    },
  );
});

test("controller guards preserve ordinary taps and stay scoped away from onboarding", () => {
  const surface = Object.assign(new EventTarget(), { hidden: false });
  protectControllerSurface(surface);
  const touch = (touches) =>
    Object.assign(new Event("touchstart", { cancelable: true }), { touches });
  const single = touch([{}]);
  surface.dispatchEvent(single);
  assert.equal(single.defaultPrevented, false);
  const pinch = touch([{}, {}]);
  surface.dispatchEvent(pinch);
  assert.equal(pinch.defaultPrevented, true);
  for (const name of [
    "touchmove",
    "gesturestart",
    "gesturechange",
    "gestureend",
    "contextmenu",
    "selectstart",
  ]) {
    const event = new Event(name, { cancelable: true });
    surface.dispatchEvent(event);
    assert.equal(event.defaultPrevented, true);
  }
  surface.hidden = true;
  const hidden = new Event("touchmove", { cancelable: true });
  surface.dispatchEvent(hidden);
  assert.equal(hidden.defaultPrevented, false);
});

test("viewport, rotation, background and fullscreen changes cancel pending gestures", () => {
  let cancels = 0;
  const sizes = [];
  const page = Object.assign(new EventTarget(), {
    hidden: false,
    documentElement: { style: { setProperty: (...value) => sizes.push(value) } },
  });
  const viewport = Object.assign(new EventTarget(), { height: 654 });
  const target = Object.assign(new EventTarget(), { visualViewport: viewport, innerHeight: 700 });
  bindControllerLifecycle(() => cancels++, target, page);
  assert.deepEqual(sizes.at(-1), ["--controller-height", "654px"]);
  for (const name of ["blur", "pagehide", "resize", "orientationchange"])
    target.dispatchEvent(new Event(name));
  viewport.height = 390;
  viewport.dispatchEvent(new Event("resize"));
  page.dispatchEvent(new Event("fullscreenchange"));
  page.hidden = true;
  page.dispatchEvent(new Event("visibilitychange"));
  assert.equal(cancels, 8);
  assert.deepEqual(sizes.at(-1), ["--controller-height", "390px"]);
});
