// Shared pieces for end-to-end tests: a real Godot host and phones that run the
// real phone client in emulated Chromium.
import {
  test as base,
  devices,
  expect,
  type Locator,
  type Page,
  type TestInfo,
} from "@playwright/test";
import { spawn, type ChildProcess } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("../../", import.meta.url));
const HTTP_PORT = 18200;
const HOST_BOOT_MSEC = 60_000;

type Waiter = {
  pattern: RegExp;
  occurrence: number;
  resolve: (line: string) => void;
  reject: (error: Error) => void;
};

/** The Godot host running tests/e2e/host.gd. Its "E2E ..." lines are the events tests wait on. */
export class Host {
  readonly url = `http://127.0.0.1:${HTTP_PORT}/`;
  private output = "";
  private events: string[] = [];
  private waiters: Waiter[] = [];
  private process?: ChildProcess;
  private exit?: string;

  async start(players: number, testInfo: TestInfo): Promise<void> {
    // A host left running by a person would answer instead of this one.
    const busy = await fetch(`${this.url}session.json`, { signal: AbortSignal.timeout(500) }).then(
      () => true,
      () => false,
    );
    expect(busy, `port ${HTTP_PORT} is already in use; close any running Play Shapes host`).toBe(
      false,
    );

    const windowed = process.env.E2E_WINDOWED === "1";
    const args = [
      ...(windowed ? [] : ["--headless"]),
      "--path",
      ROOT,
      "--script",
      "res://tests/e2e/host.gd",
    ];
    this.process = spawn(process.env.GODOT_BIN || "godot", args, {
      windowsHide: true,
      env: {
        ...process.env,
        E2E_PLAYERS: String(players),
        E2E_ROUND: process.env.E2E_ROUND === "full" ? "full" : "quick",
        E2E_HTTP_PORT: String(HTTP_PORT),
        E2E_HOST_CAPTURES: windowed ? testInfo.outputPath("host") : "",
        PLAY_SHAPES_NETWORK_CONFIG: "off",
      },
    });
    this.process.stdout!.on("data", (chunk) => this.read(String(chunk)));
    this.process.stderr!.on("data", (chunk) => this.read(String(chunk)));
    this.process.on("error", (error) =>
      this.read(`ERROR: could not start Godot: ${error.message}\n`),
    );

    // "close" follows the last output, so the reason the host gave is already read.
    this.process.on("close", (code) => this.exited(code));

    await this.event(/^ready /, { timeout: HOST_BOOT_MSEC });
  }

  /** Resolves with the nth "E2E ..." line matching pattern, including lines already printed. */
  event(pattern: RegExp, { occurrence = 1, timeout = 60_000 } = {}): Promise<string> {
    const seen = this.events.filter((line) => pattern.test(line));
    if (seen.length >= occurrence) return Promise.resolve(seen[occurrence - 1]);
    if (this.exit) return Promise.reject(new Error(this.exit));

    return new Promise((resolve, reject) => {
      const settle =
        <Value>(finish: (value: Value) => void) =>
        (value: Value) => {
          clearTimeout(timer);
          finish(value);
        };
      const waiter: Waiter = {
        pattern,
        occurrence,
        resolve: settle(resolve),
        reject: settle(reject),
      };
      this.waiters.push(waiter);

      const timer = setTimeout(() => {
        this.waiters = this.waiters.filter((other) => other !== waiter);
        reject(
          new Error(
            `host never printed "E2E ${pattern.source}" #${occurrence}; it printed:\n${this.events.join("\n")}`,
          ),
        );
      }, timeout);
    });
  }

  /** Godot error lines printed so far. */
  errors(): string[] {
    return this.output.split(/\r?\n/).filter((line) => /^(SCRIPT )?ERROR:/.test(line));
  }

  async stop(testInfo: TestInfo): Promise<void> {
    // Errors are taken before the kill: a forced exit prints engine shutdown noise.
    const errors = this.errors();
    await testInfo.attach("host-output", { body: this.output, contentType: "text/plain" });

    const host = this.process;
    if (host && host.exitCode === null) {
      const exited = new Promise((resolve) => host.once("exit", resolve));
      host.kill();
      await exited;
    }
    expect(errors, `host printed ${errors[0] ?? "errors"}`).toEqual([]);
  }

  /** A host that stops by itself can print no more events, so nothing should keep waiting for one. */
  private exited(code: number | null): void {
    const reason = this.errors()[0] ?? "no error line";
    this.exit = `host exited with code ${code}: ${reason}`;

    for (const waiter of this.waiters) waiter.reject(new Error(this.exit));
    this.waiters = [];
  }

  private read(chunk: string): void {
    this.output += chunk;
    for (const raw of chunk.split(/\r?\n/)) {
      if (!raw.startsWith("E2E ")) continue;

      const line = raw.slice("E2E ".length);
      this.events.push(line);
      for (const waiter of [...this.waiters]) {
        const matches = this.events.filter((event) => waiter.pattern.test(event));
        if (matches.length < waiter.occurrence) continue;

        this.waiters = this.waiters.filter((other) => other !== waiter);
        waiter.resolve(matches[waiter.occurrence - 1]);
      }
    }
  }
}

/** One player's phone: its own browser context running the phone client. */
export class Phone {
  readonly errors: string[] = [];
  readonly received = new Map<string, number>();
  readonly rejections: string[] = [];
  private shots = 0;

  constructor(
    readonly page: Page,
    readonly name: string,
    private readonly color: number,
    private readonly testInfo: TestInfo,
  ) {
    page.on("pageerror", (error) => this.errors.push(String(error)));
    page.on("console", (message) => {
      if (message.type() === "error") this.errors.push(message.text());
    });
    page.on("websocket", (socket) =>
      socket.on("framereceived", (frame) => this.receive(String(frame.payload))),
    );
  }

  async join(host: Host): Promise<void> {
    await this.page.goto(host.url);

    // A browser that has not installed the app first offers to install it.
    await expect(this.page.locator("#app-screen")).toBeVisible();
    await this.shot("install-offer");
    await this.page.click("#browser-button");

    await this.page.locator("#color-grid button").nth(this.color).click();
    await this.page.click("#next-button");
    await this.page.fill("#player-name", this.name);
    await this.page.click("#join-button");
    await expect(this.page.locator("#lobby-controller")).toBeVisible();
    await this.shot("lobby");
  }

  /** Holds the stick to one side long enough for the host character to walk. */
  async walk(dx: number, holdMsec = 1_000): Promise<void> {
    const center = await centerOf(this.page.locator("#lobby-stick-zone"));
    await this.page.mouse.move(center.x, center.y);
    await this.page.mouse.down();
    await this.page.mouse.move(center.x + dx, center.y, { steps: 5 });
    await this.page.waitForTimeout(holdMsec);
    await this.page.mouse.up();
  }

  async readyUp(): Promise<void> {
    await expect(this.page.locator("#ready-card")).toBeVisible();
    await this.shot("ready");
    await this.page.click("#ready-button");
  }

  async swipe(dx: number, dy: number): Promise<void> {
    const center = await centerOf(this.page.locator("#bubbles-pad"));
    await this.page.mouse.move(center.x, center.y);
    await this.page.mouse.down();
    await this.page.mouse.move(center.x + dx, center.y + dy, { steps: 6 });
    await this.page.mouse.up();
  }

  count(type: string): number {
    return this.received.get(type) ?? 0;
  }

  async shot(label: string): Promise<void> {
    this.shots += 1;
    const file = `${this.name}-${String(this.shots).padStart(2, "0")}-${label}.png`;
    await this.page.screenshot({ path: this.testInfo.outputPath(file) });
  }

  private receive(payload: string): void {
    let message: { type?: string; code?: string; message?: string };
    try {
      message = JSON.parse(payload);
    } catch {
      return;
    }

    const type = message.type ?? "?";
    this.received.set(type, this.count(type) + 1);
    if (type === "error") this.rejections.push(`${message.code}: ${message.message}`);
  }
}

async function centerOf(locator: Locator): Promise<{ x: number; y: number }> {
  const box = await locator.boundingBox();
  if (!box) throw new Error(`${locator} has no box; is it visible?`);
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
}

type Fixtures = {
  players: number;
  host: Host;
  openPhone: (name: string, color: number) => Promise<Phone>;
};

export const test = base.extend<Fixtures>({
  players: [2, { option: true }],

  host: async ({ players }, use, testInfo) => {
    const host = new Host();

    // Stops the host even when it never became ready, so no Godot process is left behind.
    try {
      await host.start(players, testInfo);
      await use(host);
    } finally {
      await host.stop(testInfo);
    }
  },

  openPhone: async ({ browser }, use, testInfo) => {
    const phones: Phone[] = [];
    await use(async (name, color) => {
      const context = await browser.newContext({ ...devices["Pixel 7"] });
      const phone = new Phone(await context.newPage(), name, color, testInfo);
      phones.push(phone);
      return phone;
    });

    // After a failure a page can be stuck mid-load, and asking it anything would wait out the test
    // timeout.
    const passedSoFar = testInfo.errors.length === 0;
    for (const phone of phones) {
      // The phone's own development error panel, such as a host protocol rejection.
      const panel = phone.page.locator("#connection-error");
      const shown = passedSoFar && (await panel.isVisible()) ? await panel.textContent() : "";
      expect(shown, `${phone.name} showed its error panel`).toBe("");
      await testInfo.attach(`${phone.name}-received`, {
        body: JSON.stringify(Object.fromEntries(phone.received), null, 2),
        contentType: "application/json",
      });
      await phone.page.context().close();
    }
    expect(
      phones.flatMap((phone) => phone.errors.map((error) => `${phone.name}: ${error}`)),
      "phone page errors",
    ).toEqual([]);
  },
});

export { expect };
