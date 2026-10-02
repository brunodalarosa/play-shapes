import { writeFileSync } from "node:fs";
import { DEFAULT_PLATFORM_SETTINGS, validatePlatformSettings } from "../public/platform_input.js";

validatePlatformSettings(DEFAULT_PLATFORM_SETTINGS);
writeFileSync(new URL("../public/platform_input_settings.json", import.meta.url), JSON.stringify({
  version: 1,
  axisConvention: "x-right-y-up",
  ...DEFAULT_PLATFORM_SETTINGS,
}, null, 2) + "\n");
