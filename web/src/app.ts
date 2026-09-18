import { attemptImmersive, chargedColor, directionAtPoint, heldDirectionAfterUpdate, type Direction } from "./controller_geometry.js";

const status = document.querySelector<HTMLElement>("#status")!;
const joinForm = document.querySelector<HTMLFormElement>("#join-form")!;
const nameInput = document.querySelector<HTMLInputElement>("#player-name")!;
const joinButton = document.querySelector<HTMLButtonElement>("#join-button")!;
const playerCard = document.querySelector<HTMLElement>("#player-card")!;
const playerName = document.querySelector<HTMLElement>("#player-name-heading")!;
const playerState = document.querySelector<HTMLElement>("#player-state")!;
const leaveButton = document.querySelector<HTMLButtonElement>("#leave-button")!;
const gameCard = document.querySelector<HTMLElement>("#game-card")!;
const gameHeading = document.querySelector<HTMLElement>("#game-heading")!;
const gameMessage = document.querySelector<HTMLElement>("#game-message")!;
const lives = document.querySelector<HTMLElement>("#lives")!;
const poseGrid = document.querySelector<HTMLElement>("#pose-grid")!;
const rotateState = document.querySelector<HTMLElement>("#rotate-state")!;

const STORAGE = { session: "play-shapes.session-id", token: "play-shapes.reconnect-token", name: "play-shapes.last-name", inputSeq: "play-shapes.input-seq" } as const;
type PublicPlayer = { player_id: string; name: string; seat: number; state: string };
type GameplayPlayer = { lives?: number; eliminated?: boolean; direction?: string; charge?: number; held?: boolean };
type Presentation = { colors?: Partial<Record<Direction, string>>; minimum_brightness?: number; maximum_brightness?: number; charge_fill_seconds?: number; charge_decay_seconds?: number };
type HostMessage = { type?: string; protocol?: number; connection_id?: number; session_id?: string; resume_status?: string; reconnect_token?: string; player?: PublicPlayer | GameplayPlayer; code?: string; message?: string; phase?: string; available_directions?: string[]; success?: boolean; lives?: number; debug_mode?: boolean; eliminated?: boolean; placement?: number; state?: string; gameplay?: HostMessage; presentation?: Presentation; direction?: string; charge?: number; held?: boolean };

const POSES: ReadonlyArray<{ direction: Direction; icon: string; label: string }> = [
  { direction: "left", icon: "←", label: "Pose left" }, { direction: "right", icon: "→", label: "Pose right" },
  { direction: "down", icon: "↓", label: "Pose down" }, { direction: "up", icon: "↑", label: "Pose up" },
];
const DEFAULT_COLORS: Record<Direction, string> = { left: "#48d16f", right: "#f04f55", down: "#f4c542", up: "#3489eb" };

let socket: WebSocket | undefined;
let retry: ReturnType<typeof setTimeout> | undefined;
let stopped = false;
let joined = false;
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
let held: { direction: Direction; pointerId?: number; button: HTMLButtonElement } | undefined;
let directions: Direction[] = [];
let presentation = { colors: DEFAULT_COLORS, minimum_brightness: 0.42, maximum_brightness: 1, charge_fill_seconds: 1, charge_decay_seconds: 0.28 };
let visualCharge: Record<Direction, number> = { left: 0, right: 0, down: 0, up: 0 };
let authoritativeDirection: Direction | undefined;
let authoritativeCharge = 0;
let authoritativeHeld = false;
let lastAnimationTime = performance.now();
let fullscreenAttempted = false;

function stored(key: string): string { try { return localStorage.getItem(key) ?? ""; } catch { return ""; } }
function store(key: string, value: string): void { try { localStorage.setItem(key, value); } catch { /* Page remains usable. */ } }
function forgetIdentity(): void { try { localStorage.removeItem(STORAGE.session); localStorage.removeItem(STORAGE.token); localStorage.removeItem(STORAGE.inputSeq); } catch { /* Restricted storage. */ } inputSeq = 0; }
function setGameplaySurface(active: boolean): void { document.documentElement.classList.toggle("gameplay-active", active); updateOrientation(); }
function updateOrientation(): void { const portrait = matchMedia("(orientation: portrait)").matches; const active = document.documentElement.classList.contains("gameplay-active"); rotateState.hidden = !(active && portrait); poseGrid.hidden = !active || portrait; }

function showJoin(message: string, focus = false): void {
  joined = false; setGameplaySurface(false); playerCard.hidden = true; gameCard.hidden = true; joinForm.hidden = false; joinButton.disabled = false; leaveButton.disabled = false;
  status.textContent = message; nameInput.value = stored(STORAGE.name); if (focus) queueMicrotask(() => nameInput.focus());
}
function showJoined(player: PublicPlayer, state = "Connected"): void {
  joined = true; setGameplaySurface(false); joinForm.hidden = true; playerCard.hidden = false; gameCard.hidden = true; playerName.textContent = player.name; playerState.textContent = state; leaveButton.disabled = false;
  status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state;
}
function sendPose(type: "pose_down" | "pose_up", direction: Direction): void { if (!socket || socket.readyState !== WebSocket.OPEN) return; inputSeq += 1; store(STORAGE.inputSeq, String(inputSeq)); socket.send(JSON.stringify({ type, direction, input_seq: inputSeq })); }
function releaseHeld(send = true): void {
  if (!held) return; const current = held; held = undefined; current.button.classList.remove("is-held"); current.button.setAttribute("aria-pressed", "false");
  if (current.pointerId !== undefined && poseGrid.hasPointerCapture(current.pointerId)) poseGrid.releasePointerCapture(current.pointerId);
  if (send) sendPose("pose_up", current.direction);
}
function beginHold(direction: Direction, button: HTMLButtonElement, pointerId?: number): void {
  if (held?.direction === direction) return; releaseHeld(); held = { direction, button, ...(pointerId === undefined ? {} : { pointerId }) };
  if (pointerId !== undefined) poseGrid.setPointerCapture(pointerId); button.classList.add("is-held"); button.setAttribute("aria-pressed", "true");
  visualCharge[direction] = 0; authoritativeDirection = direction; authoritativeCharge = 0; authoritativeHeld = true; sendPose("pose_down", direction); void requestImmersiveMode();
}
function readPresentation(value?: Presentation): void {
  if (!value) return;
  presentation = { colors: { ...DEFAULT_COLORS, ...(value.colors ?? {}) }, minimum_brightness: Number(value.minimum_brightness ?? presentation.minimum_brightness), maximum_brightness: Number(value.maximum_brightness ?? presentation.maximum_brightness), charge_fill_seconds: Math.max(0.1, Number(value.charge_fill_seconds ?? presentation.charge_fill_seconds)), charge_decay_seconds: Math.max(0.05, Number(value.charge_decay_seconds ?? presentation.charge_decay_seconds)) };
}

function renderControls(available: string[]): void {
  const desired = POSES.filter(item => available.includes(item.direction)).map(item => item.direction);
  if (held && heldDirectionAfterUpdate(held.direction, desired) === undefined) releaseHeld(); directions = desired;
  const existing = Array.from(poseGrid.querySelectorAll<HTMLButtonElement>(".pose-button"), button => button.dataset.direction);
  if (existing.length === desired.length && existing.every((value, index) => value === desired[index])) return;
  poseGrid.replaceChildren(); poseGrid.dataset.count = String(desired.length);
  for (const pose of POSES.filter(item => desired.includes(item.direction))) {
    const button = document.createElement("button"); button.type = "button"; button.className = "pose-button"; button.dataset.direction = pose.direction;
    button.setAttribute("aria-label", pose.label); button.setAttribute("aria-pressed", held?.direction === pose.direction ? "true" : "false"); button.innerHTML = `<span class="icon" aria-hidden="true">${pose.icon}</span>`;
    if (held?.direction === pose.direction) { held.button = button; button.classList.add("is-held"); }
    button.addEventListener("keydown", event => { if ((event.key !== " " && event.key !== "Enter") || event.repeat || held) return; event.preventDefault(); beginHold(pose.direction, button); });
    button.addEventListener("keyup", event => { if ((event.key === " " || event.key === "Enter") && held?.button === button) { event.preventDefault(); releaseHeld(); } });
    button.addEventListener("blur", () => { if (held?.button === button && held.pointerId === undefined) releaseHeld(); }); poseGrid.append(button);
  }
}

poseGrid.addEventListener("pointerdown", event => {
  event.preventDefault(); if (event.button !== 0 && event.pointerType === "mouse") return;
  const rect = poseGrid.getBoundingClientRect(); const direction = directionAtPoint(directions.length, event.clientX - rect.left, event.clientY - rect.top, rect.width, rect.height);
  const button = poseGrid.querySelector<HTMLButtonElement>(`[data-direction="${direction}"]`); if (button) beginHold(direction, button, event.pointerId);
});
poseGrid.addEventListener("pointerup", event => { event.preventDefault(); if (held?.pointerId === event.pointerId) releaseHeld(); });
poseGrid.addEventListener("pointercancel", event => { if (held?.pointerId === event.pointerId) releaseHeld(); });
poseGrid.addEventListener("lostpointercapture", event => { if (held?.pointerId === event.pointerId) releaseHeld(); });
poseGrid.addEventListener("contextmenu", event => event.preventDefault()); poseGrid.addEventListener("selectstart", event => event.preventDefault());

async function requestImmersiveMode(): Promise<void> {
  if (fullscreenAttempted) return; fullscreenAttempted = true;
  const root = document.documentElement as HTMLElement & { webkitRequestFullscreen?: () => Promise<void> | void };
  const orientation = screen.orientation as ScreenOrientation & { lock?: (value: string) => Promise<void> };
  const fullscreen = root.requestFullscreen ? () => root.requestFullscreen({ navigationUI: "hide" }) : root.webkitRequestFullscreen?.bind(root);
  await attemptImmersive(fullscreen, orientation.lock ? () => orientation.lock!("landscape") : undefined);
}
function updateCharge(message: HostMessage | GameplayPlayer): void {
  authoritativeDirection = POSES.some(item => item.direction === message.direction) ? message.direction as Direction : undefined;
  authoritativeCharge = Math.min(1, Math.max(0, Number(message.charge ?? 0))); authoritativeHeld = message.held === true;
}
function animate(now: number): void {
  const delta = Math.min(0.1, Math.max(0, (now - lastAnimationTime) / 1000)); lastAnimationTime = now;
  for (const direction of directions) {
    const locallyHeld = held?.direction === direction; const hostDirection = authoritativeDirection === direction; let target = hostDirection ? authoritativeCharge : 0;
    if (locallyHeld && authoritativeHeld) target = Math.max(target, visualCharge[direction] + delta / presentation.charge_fill_seconds);
    const rate = (locallyHeld || (hostDirection && authoritativeHeld)) ? 1 / presentation.charge_fill_seconds : 1 / presentation.charge_decay_seconds;
    const step = rate * delta; visualCharge[direction] += Math.max(-step, Math.min(step, target - visualCharge[direction]));
    const button = poseGrid.querySelector<HTMLElement>(`[data-direction="${direction}"]`);
    if (button) button.style.backgroundColor = chargedColor(presentation.colors[direction] ?? DEFAULT_COLORS[direction], presentation.minimum_brightness, presentation.maximum_brightness, visualCharge[direction]);
  }
  requestAnimationFrame(animate);
}
requestAnimationFrame(animate);

function showGame(message: HostMessage): void {
  playerCard.hidden = true; gameCard.hidden = false; const phase = message.phase ?? "waiting";
  gameHeading.textContent = phase === "countdown" ? "Get ready!" : phase === "genuine_stop_grace" ? "Hold a pose!" : "Watch the big screen";
  gameMessage.textContent = message.message ?? (phase === "genuine_stop_grace" ? "Music stopped! Hold your pose." : "Keep watching the shared screen.");
  const player = message.player as GameplayPlayer | undefined; const lifeCount = message.lives ?? player?.lives;
  if (message.debug_mode === true) lives.textContent = "Lives: DEBUG"; else if (Number.isInteger(lifeCount)) lives.textContent = `Lives: ${"♥".repeat(Math.max(0, lifeCount!))}${"♡".repeat(Math.max(0, 2 - lifeCount!))}`;
  const eliminated = message.eliminated === true || player?.eliminated === true; readPresentation(message.presentation); if (player) updateCharge(player);
  if (eliminated) { releaseHeld(); setGameplaySurface(false); gameHeading.textContent = "You've been eliminated :("; gameMessage.textContent = "Keep watching the big screen for the results."; poseGrid.replaceChildren(); }
  else if (message.type === "flash_pose_result") gameHeading.textContent = message.success ? "Pose locked!" : "Keep dancing!";
  else if (["countdown", "dance", "genuine_stop_grace", "resolve", "flash_wait"].includes(phase) || message.type === "flash_pose_challenge") { renderControls(message.available_directions ?? directions); setGameplaySurface(true); }
  else if (message.type === "flash_pose_results") { releaseHeld(); setGameplaySurface(false); gameHeading.textContent = message.placement ? `You placed #${message.placement}` : "Round complete"; gameMessage.textContent = "Check the big screen for the final results."; poseGrid.replaceChildren(); }
  else { releaseHeld(); setGameplaySurface(false); poseGrid.replaceChildren(); }
}

function rememberIdentity(message: HostMessage): boolean {
  const player = message.player as PublicPlayer | undefined;
  if (!player || typeof player.name !== "string" || typeof message.session_id !== "string" || typeof message.reconnect_token !== "string") return false;
  store(STORAGE.name, player.name); store(STORAGE.session, message.session_id); store(STORAGE.token, message.reconnect_token); showJoined(player); return true;
}
function reconnect(): void {
  if (stopped || retry !== undefined) return; setGameplaySurface(false);
  if (joined) { playerState.textContent = "Reconnecting"; leaveButton.disabled = true; } else joinForm.hidden = true;
  status.textContent = "Host disconnected. Reconnecting…"; retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}
async function connect(): Promise<void> {
  status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
  try {
    const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) }); if (!response.ok) throw new Error("Session unavailable"); const config: unknown = await response.json();
    if (!config || typeof config !== "object" || !("protocol" in config) || config.protocol !== 1 || !("websocket_port" in config) || !Number.isInteger(config.websocket_port) || Number(config.websocket_port) < 1024 || Number(config.websocket_port) > 65535 || !("session_id" in config) || typeof config.session_id !== "string") throw new Error("Unsupported session");
    if (stopped) return; const peer = new WebSocket(`ws://${location.hostname}:${config.websocket_port}`); socket = peer; const deadline = setTimeout(() => peer.close(), 7000);
    peer.onopen = () => peer.send(JSON.stringify({ type: "hello", protocol: 1, ...(stored(STORAGE.token) ? { reconnect_token: stored(STORAGE.token), session_id: stored(STORAGE.session) } : {}) }));
    peer.onmessage = (event: MessageEvent<string>) => {
      let message: HostMessage; try { message = JSON.parse(event.data) as HostMessage; } catch { peer.close(); return; }
      if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
        clearTimeout(deadline); if (message.resume_status === "resumed" && rememberIdentity(message)) { releaseHeld(false); if (message.gameplay) showGame(message.gameplay); return; }
        if (message.resume_status === "session_restarted") { forgetIdentity(); showJoin("The host started a new session. Join again with your name.", true); }
        else if (message.resume_status === "expired") { forgetIdentity(); showJoin("Your previous player expired. Join again with your name.", true); } else showJoin("Connected. Enter your name to join.", true);
      } else if (message.type === "join_accepted") { if (!rememberIdentity(message)) peer.close(); }
      else if (message.type === "join_rejected" || message.type === "error") { joinButton.disabled = false; status.textContent = message.message ?? "The host could not complete that action."; if (!joined) nameInput.focus(); }
      else if (message.type === "left") { forgetIdentity(); showJoin("You left the lobby. Enter a name to join again.", true); }
      else if (message.type === "flash_pose_charge") updateCharge(message);
      else if (["flash_pose_snapshot", "flash_pose_challenge", "flash_pose_result", "flash_pose_results"].includes(message.type ?? "")) showGame(message);
      else if (message.type === "lobby") { releaseHeld(false); setGameplaySurface(false); if (message.player) rememberIdentity(message); else if (joined) { gameCard.hidden = true; playerCard.hidden = false; playerState.textContent = "Waiting for the next game"; status.textContent = message.message ?? "Waiting for the next game"; } }
    };
    peer.onclose = event => { clearTimeout(deadline); releaseHeld(false); if (socket === peer) socket = undefined; if (event.code === 4000) { stopped = true; leaveButton.disabled = true; status.textContent = "This player continued in another tab."; playerState.textContent = "Open in another tab"; return; } reconnect(); };
    peer.onerror = () => peer.close();
  } catch { reconnect(); }
}

joinForm.addEventListener("submit", event => { event.preventDefault(); const name = nameInput.value.trim(); store(STORAGE.name, name); if (!socket || socket.readyState !== WebSocket.OPEN) { status.textContent = "Still connecting. Try again in a moment."; return; } joinButton.disabled = true; status.textContent = "Joining…"; socket.send(JSON.stringify({ type: "join", name })); });
leaveButton.addEventListener("click", () => { if (!socket || socket.readyState !== WebSocket.OPEN) return; leaveButton.disabled = true; status.textContent = "Leaving…"; socket.send(JSON.stringify({ type: "leave" })); });
addEventListener("orientationchange", updateOrientation); addEventListener("resize", updateOrientation);
window.addEventListener("pagehide", () => { stopped = true; releaseHeld(false); clearTimeout(retry); retry = undefined; socket?.close(); });
window.addEventListener("pageshow", event => { if (event.persisted) { stopped = false; void connect(); } });
void connect();
