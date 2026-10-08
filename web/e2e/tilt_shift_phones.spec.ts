import { test, expect } from "./fixtures";
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

async function viewport(page: import("@playwright/test").Page, width: number, height: number) {
  await page.evaluate(async () => {
    if (document.fullscreenElement) await document.exitFullscreen();
  });
  await page.setViewportSize({ width, height });
}

// Synthetic orientation proves browser wiring only; real device permission remains an owner check.
async function sensors(page: import("@playwright/test").Page): Promise<void> {
  await page.addInitScript(() => {
    // Keep emulated mobile dimensions instead of switching to the desktop fullscreen window.
    Element.prototype.requestFullscreen = () => Promise.reject(new Error("Emulated phone"));
    const api = { requestPermission: () => Promise.resolve("granted") };
    Object.defineProperty(window, "DeviceMotionEvent", { configurable: true, value: api });
    Object.defineProperty(window, "DeviceOrientationEvent", { configurable: true, value: api });
    setInterval(() => {
      const turn = Math.sin(performance.now() / 700) * 0.4;
      const lean = (80 * Math.PI) / 180;
      const alpha = Math.atan2(-Math.cos(lean) * Math.sin(turn), Math.cos(turn));
      const beta = Math.asin(-Math.sin(lean) * Math.sin(turn));
      const gamma = Math.atan2(Math.sin(lean) * Math.cos(turn), Math.cos(lean));
      const orientation = new Event("deviceorientation");
      Object.assign(orientation, {
        alpha: ((alpha * 180) / Math.PI + 360) % 360,
        beta: (beta * 180) / Math.PI,
        gamma: (gamma * 180) / Math.PI,
        absolute: false,
      });
      window.dispatchEvent(orientation);
      const motion = new Event("devicemotion");
      Object.assign(motion, {
        rotationRate: { alpha: 0, beta: 0, gamma: 0 },
        acceleration: { x: 0, y: 0, z: 0 },
        accelerationIncludingGravity: { x: 0, y: 0, z: 9.8 },
        interval: 16.667,
      });
      window.dispatchEvent(motion);
    }, 40);
  });
}

async function prepare(phones: { page: import("@playwright/test").Page }[]) {
  for (const phone of phones) {
    const page = phone.page;
    await expect(page.locator("#tilt-shift")).toBeVisible();
    if (await page.locator("#tilt-permission").isVisible()) await page.click("#tilt-permission");
    if (await page.locator("#tilt-calibrate").isVisible()) {
      await expect(page.locator("#tilt-calibrate")).toBeEnabled();
      await page.click("#tilt-calibrate");
    }
    if (await page.locator("#tilt-ready").isVisible()) {
      await expect(page.locator("#tilt-ready")).toBeEnabled();
      await page.click("#tilt-ready");
    }
  }
}

for (const count of [2, 4, 6, 8, 10]) {
  test.describe(count + " Tilt Shift phones", () => {
    test.use({ game: "tilt_shift", players: count });
    test("prepare, show one guide, traverse mapped rounds and return", async ({
      host,
      openPhone,
    }) => {
      const phones = [];
      const traffic: { bytes: number; updates: number; maximum: number; angles: Set<number> }[] =
        [];
      for (let i = 0; i < count; i++) {
        const phone = await openPhone("Player " + (i + 1), i);
        const wire = { bytes: 0, updates: 0, maximum: 0, angles: new Set<number>() };
        traffic.push(wire);
        phone.page.on("websocket", (socket) =>
          socket.on("framereceived", (frame) => {
            const value = JSON.parse(String(frame.payload));
            if (value.type !== "tilt_shift_snapshot") return;
            const bytes = Buffer.byteLength(String(frame.payload));
            wire.bytes += bytes;
            wire.updates++;
            wire.maximum = Math.max(wire.maximum, bytes);
            if (value.selected) wire.angles.add(value.angle_radians);
          }),
        );
        await sensors(phone.page);
        await phone.join(host);
        phones.push(phone);
      }
      await host.event(/^start /);
      for (const phone of phones) await viewport(phone.page, 844, 390);
      if (count <= 4) {
        for (const phone of phones) {
          await expect(phone.page.locator("#tilt-shift")).toBeVisible();
          await expect(phone.page.locator("#tilt-ready")).toBeHidden();
        }
      }
      await prepare(phones);
      await host.event(/^tilt phase=active round=1$/);
      let active = 0,
        waiting = 0;
      for (const phone of phones) {
        await expect(phone.page.locator("#tilt-actions")).toBeHidden();
        if (await phone.page.locator("#tilt-paddle").isVisible()) active++;
        else waiting++;
      }
      expect(active).toBe(Math.min(count, 4));
      expect(waiting).toBe(Math.max(0, count - 4));
      await phones[0].shot("selected-or-waiting");
      if (count === 2) {
        await phones[0].page.reload();
        await expect(phones[0].page.locator("#tilt-permission")).toBeVisible();
        await expect(phones[0].page.locator("#tilt-calibrate")).toBeHidden();
        await phones[0].page.click("#tilt-permission");
        await expect(phones[0].page.locator("#tilt-actions")).toBeHidden();
        await viewport(phones[0].page, 390, 844);
        await expect(phones[0].page.locator("#tilt-paddle")).toBeVisible();
        await phones[0].shot("reconnected-portrait");
      }
      await host.event(/^tilt round=2$/);
      await prepare(phones);
      await host.event(/^tilt phase=active round=2$/);
      active = 0;
      for (const phone of phones)
        if (await phone.page.locator("#tilt-paddle").isVisible()) active++;
      expect(active).toBe(Math.min(count, 6));
      await host.event(/^tilt results$/);
      await host.event(/^return$/);
      await host.event(/^scene lobby$/, { occurrence: 2 });
      for (const phone of phones) {
        await expect(phone.page.locator("#lobby-controller")).toBeVisible();
        await expect(phone.page.locator("#tilt-shift")).toBeHidden();
      }
      for (const wire of traffic) {
        expect(wire.angles.size).toBeGreaterThan(3);
        expect(wire.maximum).toBeLessThan(900);
        expect(wire.updates).toBeLessThan(15 * 50 + 50);
      }
      const folder = fileURLToPath(new URL("../../test-results/tilt-shift/", import.meta.url));
      mkdirSync(folder, { recursive: true });
      writeFileSync(
        folder + "/flow-traffic-" + count + ".json",
        JSON.stringify(
          {
            scope:
              "Synthetic Chromium, two 8-second rounds plus preparation; " +
              "downstream JSON, no framing",
            players: count,
            phones: traffic.map(({ angles, ...wire }) => ({ ...wire, angles: angles.size })),
          },
          null,
          2,
        ),
      );
      if (count === 2) {
        await host.event(/^bubbles prepare$/);
        for (const phone of phones) {
          await expect(phone.page.locator("#ready-card")).toBeVisible();
          await phone.readyUp();
        }
        await host.event(/^bubbles started$/);
        for (const phone of phones) await expect(phone.page.locator("#bubbles-pad")).toBeVisible();
        await host.event(/^bubbles return$/);
        await host.event(/^scene lobby$/, { occurrence: 3 });
      }
    });
  });
}
