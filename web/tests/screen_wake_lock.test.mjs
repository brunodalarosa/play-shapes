import test from "node:test";
import assert from "node:assert/strict";
import { bindScreenWakeLock } from "../build/screen_wake_lock.js";

const settle = () => new Promise((resolve) => setImmediate(resolve));
const deferred = () => {
  let resolve;
  const promise = new Promise((finish) => (resolve = finish));
  return { promise, resolve };
};
class Lock extends EventTarget {
  released = false;
  releases = 0;
  async release() {
    this.releases++;
    this.released = true;
    this.dispatchEvent(new Event("release"));
  }
}
function surfaces() {
  const page = new EventTarget();
  page.visibilityState = "visible";
  const target = new EventTarget();
  return {
    page,
    target,
    visibility(state) {
      page.visibilityState = state;
      page.dispatchEvent(new Event("visibilitychange"));
    },
  };
}

test("one page lock survives game changes, releases when hidden and returns with the page", async () => {
  const surface = surfaces();
  const locks = [];
  const stop = bindScreenWakeLock(surface.page, surface.target, {
    async request(type) {
      assert.equal(type, "screen");
      const lock = new Lock();
      locks.push(lock);
      return lock;
    },
  });
  await settle();
  surface.page.dispatchEvent(new Event("pointerdown"));
  surface.page.dispatchEvent(new Event("keydown"));
  await settle();
  assert.equal(locks.length, 1, "interactions reuse the page's lock");
  surface.visibility("hidden");
  assert.equal(locks[0].releases, 1);
  surface.visibility("visible");
  await settle();
  assert.equal(locks.length, 2);
  surface.target.dispatchEvent(new Event("pagehide"));
  assert.equal(locks[1].releases, 1);
  surface.page.dispatchEvent(new Event("pointerdown"));
  await settle();
  assert.equal(locks.length, 2, "pagehide suspends even before visibility changes");
  surface.target.dispatchEvent(new Event("pageshow"));
  await settle();
  assert.equal(locks.length, 3, "a cached page reacquires protection");
  stop();
  assert.equal(locks[2].releases, 1);
  surface.target.dispatchEvent(new Event("pageshow"));
  surface.visibility("visible");
  await settle();
  assert.equal(locks.length, 3, "cleanup removes every retry listener");
});

test("browser refusal and external release wait for a lifecycle event or gesture to retry", async () => {
  const surface = surfaces();
  let requests = 0;
  let lock;
  const stop = bindScreenWakeLock(surface.page, surface.target, {
    async request() {
      requests++;
      if (requests === 1) throw new Error("Low battery");
      lock = new Lock();
      return lock;
    },
  });
  await settle();
  await settle();
  assert.equal(requests, 1, "refusal does not start a retry loop");
  surface.page.dispatchEvent(new Event("pointerdown"));
  await settle();
  assert.equal(requests, 2);
  await lock.release();
  await settle();
  assert.equal(requests, 2, "OS release does not cause an acquisition loop");
  surface.page.dispatchEvent(new Event("keydown"));
  await settle();
  assert.equal(requests, 3);
  surface.page.dispatchEvent(new Event("pointerdown"));
  await settle();
  assert.equal(requests, 3, "the replacement lock is reused");
  stop();
  assert.equal(lock.releases, 1, "cleanup releases the replacement lock");
});

test("late acquisition is retired and a return during that request is not lost", async () => {
  const surface = surfaces();
  const first = deferred();
  const stale = new Lock();
  const current = new Lock();
  let requests = 0;
  const stop = bindScreenWakeLock(surface.page, surface.target, {
    request() {
      requests++;
      return requests === 1 ? first.promise : Promise.resolve(current);
    },
  });
  surface.visibility("hidden");
  surface.visibility("visible");
  surface.page.dispatchEvent(new Event("pointerdown"));
  assert.equal(requests, 1, "concurrent events share the outstanding request");
  first.resolve(stale);
  await settle();
  assert.equal(stale.releases, 1);
  assert.equal(requests, 2, "return reacquires after retiring the obsolete request");
  stop();
  assert.equal(current.releases, 1);
});

test("unsupported pages and hidden pages need no lock; cleanup handles pending requests", async () => {
  const surface = surfaces();
  const unsupported = bindScreenWakeLock(surface.page, surface.target, null);
  surface.page.dispatchEvent(new Event("pointerdown"));
  unsupported();
  surface.visibility("hidden");
  const pending = deferred();
  const lock = new Lock();
  let requests = 0;
  const stop = bindScreenWakeLock(surface.page, surface.target, {
    request() {
      requests++;
      return pending.promise;
    },
  });
  await settle();
  assert.equal(requests, 0);
  surface.visibility("visible");
  assert.equal(requests, 1);
  stop();
  pending.resolve(lock);
  await settle();
  assert.equal(lock.releases, 1, "cleanup releases an acquisition that completes afterward");
});
