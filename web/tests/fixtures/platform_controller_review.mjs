import { PlatformControls } from "/platform_controls.js";
import { DEFAULT_PLATFORM_SETTINGS, validatePlatformSettings } from "/platform_input.js";
import { createLobbyContext } from "/lobby_input.js";
import { protectControllerSurface } from "/immersive.js";
import { createPreviewContext } from "/platform_context.mjs";

const screen = document.querySelector("#lobby-controller");
const stick = document.querySelector("#lobby-stick-zone");
const action = document.querySelector("#lobby-jump-button");
const record = document.querySelector("#record");
const form = document.querySelector("#tuning");
let count = 0,
  contextName = "preview",
  settings = { ...DEFAULT_PLATFORM_SETTINGS };
let lastActive = "none",
  lastRelease = "none";
const show = (value) => {
  count++;
  const input = value.intent?.input;
  const axes = input?.axes ?? { x: value.horizontal, y: value.vertical };
  const stance = input?.stance ?? value.stance;
  const action = value.intent?.action ?? value.action;
  const describe = `${axes.x.toFixed(2)}, ${axes.y.toFixed(2)}; ${stance}`;
  if (stance !== "neutral") lastActive = describe;
  if (action) lastRelease = `${action}; ${describe}`;
  record.textContent = `Adapter: ${contextName}\nMessages: ${count}\nLatest: ${describe}\nLast active: ${lastActive}\nLast release: ${lastRelease}`;
};
const context = () =>
  contextName === "preview" ? createPreviewContext(show) : createLobbyContext(show);
let controls = new PlatformControls(screen, stick, action, context(), settings);
protectControllerSurface(screen);
controls.activate();
for (const element of form.elements) if (element.name) element.value = settings[element.name];
document.querySelector("#switch").addEventListener("click", () => {
  // Reset against the old adapter, then record through the other one.
  const next = contextName === "preview" ? "playground" : "preview";
  controls.deactivate();
  contextName = next;
  controls.setContext(context());
  controls.activate();
  record.textContent = `${contextName} adapter; controls reset`;
});
document.querySelector("#reset").addEventListener("click", () => {
  controls.deactivate();
  controls.activate();
  record.textContent = "Controls reactivated";
});
form.addEventListener("submit", (event) => {
  event.preventDefault();
  const candidate = { ...settings };
  for (const element of form.elements)
    if (element.name) candidate[element.name] = Number(element.value);
  try {
    validatePlatformSettings(candidate);
    controls.destroy();
    settings = candidate;
    controls = new PlatformControls(screen, stick, action, context(), settings);
    controls.activate();
    record.textContent = "Tuning applied; controls reset";
  } catch (error) {
    record.textContent = error.message;
  }
});
window.addEventListener("pagehide", () => controls.destroy());
