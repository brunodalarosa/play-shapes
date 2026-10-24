/* global window, document, HTMLCanvasElement */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";
import { PNG } from "pngjs";
import { preparation, snapshot } from "./fixtures.mjs";

async function phone(options, verify) {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({
      viewport: { width: 844, height: 390 },
      deviceScaleFactor: 2,
    });
    const requests = [];
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.route("**/*", async (route) => {
      const path = new URL(route.request().url()).pathname;
      requests.push(path);
      if (path === "/session.json") {
        await route.fulfill({
          json: {
            protocol: 1,
            session_id: "test-session",
            http_scheme: "http",
            websocket_scheme: "ws",
            websocket_port: 8081,
          },
        });
        return;
      }
      // The host serves the face parts and their manifest from the shared runtime folder.
      const source = path.startsWith("/shape_faces/")
        ? `../../../assets/runtime/shape_faces/${path.slice("/shape_faces/".length)}`
        : `../../public${path === "/" ? "/index.html" : path}`;
      const types = {
        js: "text/javascript",
        css: "text/css",
        html: "text/html",
        png: "image/png",
        json: "application/json",
      };
      try {
        const body = await readFile(new URL(source, import.meta.url));
        await route.fulfill({ body, contentType: types[path.split(".").at(-1)] ?? "text/html" });
      } catch {
        await route.fulfill({ status: 404, body: "" });
      }
    });
    await page.addInitScript(({ noWebGL }) => {
      window.sentInput = [];
      window.WebSocket = class {
        static OPEN = 1;
        readyState = 1;
        bufferedAmount = 0;
        constructor() {
          window.receiveHost = (message) => this.onmessage({ data: JSON.stringify(message) });
          setTimeout(() => this.onopen?.(), 0);
        }
        send(value) {
          window.sentInput.push(JSON.parse(value));
        }
        close() {
          this.readyState = 3;
        }
      };
      if (noWebGL) {
        const original = HTMLCanvasElement.prototype.getContext;
        HTMLCanvasElement.prototype.getContext = function (kind, ...args) {
          return kind.startsWith("webgl") ? null : original.call(this, kind, ...args);
        };
      }
    }, options);
    await page.goto("http://phone.test/");
    await page.waitForFunction(() => typeof window.receiveHost === "function");
    await verify(page, requests);
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
  }
}

function resume(page, gameplay) {
  return page.evaluate(
    (message) =>
      window.receiveHost({
        type: "welcome",
        protocol: 1,
        connection_id: 2,
        resume_status: "resumed",
        session_id: "test-session",
        reconnect_token: "test-token",
        player: { player_id: "one", name: "Tester", seat: 1, state: "connected" },
        gameplay: message,
      }),
    gameplay,
  );
}

/**
 * The colour on screen a little along the paddle from [selector]'s centre, on its body, for a
 * paddle turned [angle] radians clockwise.
 */
async function centreColour(page, selector, angle = 0) {
  const box = await page.locator(selector).boundingBox();
  const image = PNG.sync.read(await page.screenshot());
  const scale = image.width / page.viewportSize().width;
  const x = Math.round((box.x + box.width / 2 + 38 * Math.cos(angle)) * scale);
  const y = Math.round((box.y + box.height / 2 + 38 * Math.sin(angle)) * scale);
  const index = (y * image.width + x) * 4;
  return [image.data[index], image.data[index + 1], image.data[index + 2]];
}

test("the Pre-minigame screen shows the player's paddle in 3D with calibration", async () => {
  await phone({ noWebGL: false }, async (page, requests) => {
    assert.equal(requests.includes("/three_view.js"), false);
    await resume(page, {
      type: "pre_minigame_snapshot",
      minigame_id: "tilt_shift_3d",
      ready: false,
      preparation: preparation(),
    });
    await page.waitForFunction(
      () => document.querySelector("#tilt-shift-3d").getAttribute("data-view") === "3d",
    );
    assert.equal(await page.locator("#tilt-shift-3d").isVisible(), true);
    assert.equal(await page.locator("#tilt3d-paddle").isVisible(), true);
    assert.equal(await page.locator("#tilt3d-flat").isVisible(), false);
    assert.equal(requests.filter((path) => path === "/three_view.js").length, 1);
    assert.ok(requests.includes("/shape_faces/face_presets.json"));
    assert.equal(await page.locator("#tilt3d-permission").isVisible(), true);
    assert.equal(await page.locator("#tilt3d-calibrate").isVisible(), true);
    assert.equal(await page.locator("#tilt3d-ready").isDisabled(), true);
    await page.waitForFunction(() =>
      performance
        .getEntriesByType("resource")
        .some((entry) => entry.name.endsWith("/shape_faces/facial_part_mouth_happy.png")),
    );
    await page.waitForTimeout(300);
    const [red, green, blue] = await centreColour(page, "#tilt3d-paddle");
    assert.ok(
      green > red && green > blue,
      `the paddle is the player's green (${red},${green},${blue})`,
    );
    await page.locator("#tilt3d-ready").evaluate((button) => (button.disabled = false));
    await page.locator("#tilt3d-ready").click();
    const ready = await page.evaluate(() => window.sentInput.at(-1));
    assert.deepEqual(ready, { type: "pre_minigame_ready", ready: true });
  });
});

test("play turns the paddle with the host, shows the host's face and READY uses 005's message", async () => {
  await phone({ noWebGL: false }, async (page, requests) => {
    await resume(
      page,
      snapshot({ phase: "preparing", ready_available: true, calibration_available: true }),
    );
    await page.waitForFunction(
      () => document.querySelector("#tilt-shift-3d").getAttribute("data-view") === "3d",
    );
    assert.equal(await page.locator("#tilt-shift-3d").getAttribute("data-team"), "1");
    assert.equal(await page.locator("#tilt3d-ready").isDisabled(), false);
    await page.locator("#tilt3d-ready").click();
    assert.deepEqual(await page.evaluate(() => window.sentInput.at(-1)), {
      type: "tilt_shift_3d_ready",
      ready: true,
      generation: "generation",
      round_token: "token",
    });
    await page.evaluate((message) => window.receiveHost(message), snapshot({ sequence: 4 }));
    await page.waitForTimeout(300);
    const [red, green, blue] = await centreColour(page, "#tilt3d-paddle", 0.4);
    assert.ok(
      red > green + 60 && red > blue + 60,
      `the paddle is the player's red (${red},${green},${blue})`,
    );
    await page.evaluate(
      (message) => window.receiveHost(message),
      snapshot({ sequence: 5, face: "face_dizzy" }),
    );
    await page.waitForFunction(() =>
      performance
        .getEntriesByType("resource")
        .some((entry) => entry.name.endsWith("/shape_faces/facial_part_eye_x.png")),
    );
    assert.ok(requests.includes("/shape_faces/facial_part_eye_x.png"), "the dizzy eyes load");
    await page.evaluate(
      (message) => window.receiveHost(message),
      snapshot({ sequence: 6, face: "face_rolling_eyes" }),
    );
    await page.waitForFunction(() =>
      performance
        .getEntriesByType("resource")
        .some((entry) => entry.name.endsWith("/shape_faces/facial_part_eye_looking_up.png")),
    );
    assert.ok(requests.includes("/shape_faces/facial_part_eye_looking_up.png"));
    const capture = new URL("../../build/tilt-shift-3d-phone.png", import.meta.url);
    await page.screenshot({ path: fileURLToPath(capture) });
    await page.evaluate(
      (message) => window.receiveHost(message),
      snapshot({ sequence: 7, selected: false, paddle_ids: [] }),
    );
    assert.equal(await page.locator("#tilt-shift-3d").getAttribute("data-waiting"), "true");
    assert.equal(await page.locator("#tilt3d-paddle").isVisible(), true, "Spectators see it");
    await page.evaluate(
      (message) => window.receiveHost(message),
      snapshot({ sequence: 8, phase: "finished" }),
    );
    assert.equal(await page.locator("#tilt-shift-3d").isVisible(), false);
    await page.evaluate(() => window.receiveHost({ type: "lobby" }));
    assert.equal(await page.locator("#tilt-shift-3d").isVisible(), false);
  });
});

test("without WebGL a flat drawing of the paddle and face replaces the 3D view", async () => {
  await phone({ noWebGL: true }, async (page) => {
    await resume(page, snapshot());
    await page.waitForFunction(
      () => document.querySelector("#tilt-shift-3d").getAttribute("data-view") === "flat",
    );
    assert.equal(await page.locator("#tilt3d-flat").isVisible(), true);
    assert.equal(await page.locator("#tilt3d-paddle").isVisible(), false);
    await page.waitForTimeout(200);
    const [red, green, blue] = await centreColour(page, "#tilt3d-flat", 0.4);
    assert.ok(
      red > green + 60 && red > blue + 60,
      `the flat paddle is red (${red},${green},${blue})`,
    );
    const capture = new URL("../../build/tilt-shift-3d-phone-flat.png", import.meta.url);
    await page.screenshot({ path: fileURLToPath(capture) });
  });
});
