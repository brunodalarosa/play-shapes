import { defineConfig, devices } from "@playwright/test";

// Full coverage adds larger Tilt Shift rosters and keeps the 90 s Bubbles round.
const fullRound = process.env.E2E_ROUND === "full";

export default defineConfig({
  testDir: "e2e",
  outputDir: "../test-results/e2e",
  // One host serves fixed ports, so tests cannot run side by side.
  workers: 1,
  fullyParallel: false,
  retries: 0,
  grepInvert: fullRound ? undefined : /@full/,
  forbidOnly: true,
  timeout: fullRound ? 6 * 60_000 : 3 * 60_000,
  expect: { timeout: 30_000 },
  reporter: [["list"]],
  use: {
    ...devices["Pixel 7"],
    actionTimeout: 15_000,
    navigationTimeout: 15_000,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [{ name: "chromium-phone" }],
});
