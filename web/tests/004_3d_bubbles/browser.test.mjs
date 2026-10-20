/* global window, document, HTMLCanvasElement, getComputedStyle */
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";
import { snapshot } from "./fixtures.mjs";

async function phone(options, verify) {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({
      viewport: { width: 390, height: 844 },
      deviceScaleFactor: 3,
    });
    const requests = [];
    const errors = [];
    page.on("pageerror", (error) => errors.push(error.message));
    await page.route("**/*", async (route) => {
      const path = new URL(route.request().url()).pathname;
      requests.push(path);
      if (path === "/tilt-shift/manifest.json") {
        const assets = Object.fromEntries(
          ["orange", "blue", "neutral"].map((team) => [
            `paddles/paddle_${team}.png`,
            { visible_bounds_px: [10, 9, 663, 151] },
          ]),
        );
        await route.fulfill({ json: { assets } });
        return;
      }
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
      // The host serves the face images from the runtime Squircle folder, as here.
      const face = path.match(/^\/models\/squircle-face-(neutral|blink)\.png$/);
      const source = face
        ? `../../../assets/runtime/animated_characters/squircle/v1/model/face-${face[1]}.png`
        : `../../public${path === "/" ? "/index.html" : path}`;
      const file = new URL(source, import.meta.url);
      const types = {
        js: "text/javascript",
        css: "text/css",
        html: "text/html",
        png: "image/png",
        json: "application/json",
        glb: "model/gltf-binary",
      };
      try {
        const body = await readFile(file);
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
    await page.evaluate(() =>
      window.receiveHost({
        type: "welcome",
        protocol: 1,
        connection_id: 1,
        resume_status: "new",
      }),
    );
    await verify(page, requests);
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
  }
}

test("browser loads 3D lazily, renders models, sends label touches and retires on lobby", async () => {
  await phone({ noWebGL: false }, async (page, requests) => {
    assert.equal(requests.includes("/three_view.js"), false);
    await page.evaluate(
      (gameplay) =>
        window.receiveHost({
          type: "welcome",
          protocol: 1,
          connection_id: 2,
          resume_status: "resumed",
          session_id: "test-session",
          reconnect_token: "test-token",
          player: { player_id: "one", name: "Tester", seat: 1, state: "connected" },
          gameplay,
        }),
      snapshot(),
    );
    await page.waitForFunction(() => {
      const canvas = document.querySelector("#bubbles-3d-visual");
      return !canvas.hidden && canvas.width > 1;
    });
    await page.waitForTimeout(200);
    assert.equal(requests.filter((path) => path === "/three_view.js").length, 1);
    assert.ok(requests.includes("/models/squircle.glb"));
    assert.ok(requests.includes("/models/jellyfish.glb"));
    assert.equal(await page.locator("#bubbles-3d-score").textContent(), "7");
    assert.equal(await page.locator("#bubbles-3d-visual").evaluate((canvas) => canvas.width), 780);
    await page.mouse.move(195, 40);
    await page.mouse.down();
    await page.mouse.move(290, 150);
    await page.mouse.up();
    const sent = await page.evaluate(() => window.sentInput);
    const start = sent.find((message) => message.type === "bubbles_3d_touch");
    const release = sent.find((message) => message.type === "bubbles_3d_release");
    assert.equal(start.stage, "start");
    assert.equal(start.input_seq, release.input_seq);
    assert.ok(release.displacement[1] > 0);
    await page.mouse.down();
    await page.setViewportSize({ width: 412, height: 915 });
    await page.waitForFunction(() => window.sentInput.at(-1).stage === "cancel");
    await page.mouse.up();
    const cancelled = await page.evaluate(() => window.sentInput.at(-1));
    assert.equal(cancelled.stage, "cancel");
    await page.setViewportSize({ width: 390, height: 844 });
    const capture = new URL("../../build/bubbles-3d-phone.png", import.meta.url);
    await page.screenshot({ path: fileURLToPath(capture) });
    await page.evaluate(() => window.receiveHost({ type: "lobby" }));
    assert.equal(await page.locator("#bubbles-3d-card").isVisible(), false);
    await page.evaluate((gameplay) => window.receiveHost(gameplay), snapshot());
    await page.waitForFunction(() => !document.querySelector("#bubbles-3d-visual").hidden);
    assert.equal(requests.filter((path) => path === "/models/squircle.glb").length, 1);
    await page.evaluate(() =>
      window.receiveHost({
        type: "pre_minigame_snapshot",
        ready: false,
      }),
    );
    assert.equal(await page.locator("#bubbles-3d-card").isVisible(), false);
    assert.equal(await page.locator("#ready-card").isVisible(), true);
  });
});

test("reusable Squircle tints every limb, faces the camera, scales and blinks", async () => {
  await phone({ noWebGL: false }, async (page) => {
    const result = await page.evaluate(async () => {
      const { createSquircle } = await import("/three_view.js");
      const character = await createSquircle();
      character.update(0, 1.31, "#e53935", false);
      character.root.updateMatrixWorld(true);
      const colors = [];
      const tinted = [];
      let face;
      character.root.traverse((object) => {
        if (!object.isMesh) return;
        if (object.name === "Face") face = object;
        else {
          colors.push(object.material.color.getHexString());
          tinted.push(object);
        }
      });
      const z = face.matrixWorld.elements[14];
      const scale = character.root.scale.x;
      character.update(6, 1.31, "#e53935", true);
      const white = tinted.map((object) => object.material.color.getHexString());
      const blink = face.material.map.image.src.endsWith("squircle-face-blink.png");
      character.update(0.13, 1.31, "#e53935", false);
      const neutral = face.material.map.image.src.endsWith("squircle-face-neutral.png");
      character.dispose();
      return { colors, z, scale, white, blink, neutral };
    });
    assert.deepEqual(result.colors, Array(5).fill("e53935"));
    assert.ok(result.z > 0);
    assert.equal(result.scale, 0.5);
    assert.deepEqual(result.white, Array(5).fill("ffffff"));
    assert.equal(result.blink, true);
    assert.equal(result.neutral, true);
  });
});

test("browser without WebGL keeps score and a radius-sized colored fallback", async () => {
  await phone({ noWebGL: true }, async (page) => {
    await page.evaluate((gameplay) => window.receiveHost(gameplay), snapshot({ score: 123 }));
    const fallback = page.locator("#bubbles-3d-fallback");
    await fallback.waitFor({ state: "visible" });
    await page.waitForFunction(() => document.querySelector("#bubbles-3d-visual").hidden);
    assert.equal(await page.locator("#bubbles-3d-score").textContent(), "123");
    await page.waitForFunction(() => {
      const circle = document.querySelector("#bubbles-3d-fallback");
      return getComputedStyle(circle).backgroundColor === "rgb(30, 136, 229)";
    });
    const before = await fallback.boundingBox();
    await page.evaluate(
      (gameplay) => window.receiveHost(gameplay),
      snapshot({ score: 200, bubble_radius: 1.5, host_time_msec: 1100 }),
    );
    await page.waitForTimeout(150);
    assert.ok((await fallback.boundingBox()).width > before.width);
    await page.evaluate(() => window.receiveHost({ type: "lobby" }));
  });
});

test("reusable viewport caps resolution and suspends its loop while hidden or disposed", async () => {
  await phone({ noWebGL: false }, async (page) => {
    const result = await page.evaluate(async () => {
      const { Viewport } = await import("/three_view.js");
      const canvas = document.createElement("canvas");
      canvas.style.width = "100px";
      canvas.style.height = "200px";
      document.body.append(canvas);
      let frames = 0;
      const viewport = new Viewport(canvas, () => frames++);
      const wait = () => new Promise((resolve) => setTimeout(resolve, 80));
      await wait();
      const visible = frames;
      Object.defineProperty(document, "hidden", { configurable: true, value: true });
      document.dispatchEvent(new Event("visibilitychange"));
      await wait();
      const hidden = frames;
      delete document.hidden;
      document.dispatchEvent(new Event("visibilitychange"));
      await wait();
      const resumed = frames;
      viewport.dispose();
      await wait();
      const disposed = frames;
      const size = [canvas.width, canvas.height];
      canvas.remove();
      return { visible, hidden, resumed, disposed, size };
    });
    assert.ok(result.visible > 0);
    assert.equal(result.hidden, result.visible);
    assert.ok(result.resumed > result.hidden);
    assert.equal(result.disposed, result.resumed);
    assert.deepEqual(result.size, [200, 400]);
  });
});
