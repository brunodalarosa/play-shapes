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

const STORAGE = {
  session: "play-shapes.session-id",
  token: "play-shapes.reconnect-token",
  name: "play-shapes.last-name",
  inputSeq: "play-shapes.input-seq",
} as const;

type PublicPlayer = { player_id: string; name: string; seat: number; state: string };
type HostMessage = {
  type?: string;
  protocol?: number;
  connection_id?: number;
  session_id?: string;
  resume_status?: string;
  reconnect_token?: string;
  player?: PublicPlayer;
  code?: string;
  message?: string;
  phase?: string;
  available_directions?: string[];
  success?: boolean;
  lives?: number;
  eliminated?: boolean;
  placement?: number;
  state?: string;
  gameplay?: HostMessage;
};

let socket: WebSocket | undefined;
let retry: ReturnType<typeof setTimeout> | undefined;
let stopped = false;
let joined = false;
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
let held: { direction: Direction; pointerId?: number; button: HTMLButtonElement } | undefined;
type Direction = "left" | "right" | "down" | "up";
const POSES: ReadonlyArray<{ direction: Direction; icon: string; label: string }> = [
  { direction: "left", icon: "←", label: "Pose left" },
  { direction: "right", icon: "→", label: "Pose right" },
  { direction: "down", icon: "▼", label: "Pose down" },
  { direction: "up", icon: "▲", label: "Pose up" },
];

function stored(key: string): string {
  try { return localStorage.getItem(key) ?? ""; } catch { return ""; }
}

function store(key: string, value: string): void {
  try { localStorage.setItem(key, value); } catch { /* Joining still works for this page. */ }
}

function forgetIdentity(): void {
  try {
    localStorage.removeItem(STORAGE.session);
    localStorage.removeItem(STORAGE.token);
    localStorage.removeItem(STORAGE.inputSeq);
  } catch { /* Nothing else can be cleared in restricted storage. */ }
  inputSeq = 0;
}

function showJoin(message: string, focus = false): void {
  joined = false;
  playerCard.hidden = true;
  gameCard.hidden = true;
  joinForm.hidden = false;
  joinButton.disabled = false;
  leaveButton.disabled = false;
  status.textContent = message;
  nameInput.value = stored(STORAGE.name);
  if (focus) queueMicrotask(() => nameInput.focus());
}

function showJoined(player: PublicPlayer, state = "Connected"): void {
  joined = true;
  joinForm.hidden = true;
  playerCard.hidden = false;
  gameCard.hidden = true;
  playerName.textContent = player.name;
  playerState.textContent = state;
  leaveButton.disabled = false;
  status.textContent = state === "Connected" ? "Joined. Keep this page open while you play." : state;
}

function sendPose(type: "pose_down" | "pose_up", direction: Direction): void {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;
  inputSeq += 1;
  store(STORAGE.inputSeq, String(inputSeq));
  socket.send(JSON.stringify({ type, direction, input_seq: inputSeq }));
}

function releaseHeld(send = true): void {
  if (!held) return;
  const current = held;
  held = undefined;
  current.button.classList.remove("is-held");
  current.button.setAttribute("aria-pressed", "false");
  if (current.pointerId !== undefined) {
    try { current.button.releasePointerCapture(current.pointerId); } catch { /* Capture may already be gone. */ }
  }
  if (send) sendPose("pose_up", current.direction);
}

function renderControls(available: string[]): void {
	const existing = Array.from(poseGrid.querySelectorAll<HTMLButtonElement>(".pose-button"), button => button.dataset.direction);
	const desired = POSES.filter(item => available.includes(item.direction)).map(item => item.direction);
	if (existing.length === desired.length && existing.every((value, index) => value === desired[index])) return;
  releaseHeld();
  poseGrid.replaceChildren();
  for (const pose of POSES.filter(item => available.includes(item.direction))) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "pose-button";
    button.dataset.direction = pose.direction;
    button.setAttribute("aria-label", pose.label);
    button.setAttribute("aria-pressed", "false");
    button.innerHTML = `<span class="icon" aria-hidden="true">${pose.icon}</span><span>${pose.label}</span>`;
    button.addEventListener("pointerdown", event => {
      event.preventDefault();
      if (held?.direction === pose.direction) return;
      releaseHeld();
      held = { direction: pose.direction, pointerId: event.pointerId, button };
      button.setPointerCapture(event.pointerId);
      button.classList.add("is-held");
      button.setAttribute("aria-pressed", "true");
      sendPose("pose_down", pose.direction);
    });
    button.addEventListener("pointerup", event => { event.preventDefault(); if (held?.pointerId === event.pointerId) releaseHeld(); });
    button.addEventListener("pointercancel", event => { if (held?.pointerId === event.pointerId) releaseHeld(); });
    button.addEventListener("lostpointercapture", () => { if (held?.button === button) releaseHeld(); });
    button.addEventListener("contextmenu", event => event.preventDefault());
    button.addEventListener("keydown", event => {
      if ((event.key !== " " && event.key !== "Enter") || event.repeat || held) return;
      event.preventDefault();
      held = { direction: pose.direction, button };
      button.classList.add("is-held");
      button.setAttribute("aria-pressed", "true");
      sendPose("pose_down", pose.direction);
    });
    button.addEventListener("keyup", event => {
      if ((event.key === " " || event.key === "Enter") && held?.button === button) {
        event.preventDefault();
        releaseHeld();
      }
    });
    button.addEventListener("blur", () => { if (held?.button === button) releaseHeld(); });
    poseGrid.append(button);
  }
}

function showGame(message: HostMessage): void {
  playerCard.hidden = true;
  gameCard.hidden = false;
  const phase = message.phase ?? "waiting";
  gameHeading.textContent = phase === "countdown" ? "Get ready!" : phase === "genuine_stop_grace" ? "Hold a pose!" : "Watch the big screen";
  gameMessage.textContent = message.message ?? (phase === "genuine_stop_grace" ? "Music stopped! Hold your pose." : "Keep watching the shared screen.");
  const player = message.player as unknown as { lives?: number; eliminated?: boolean } | undefined;
  const lifeCount = message.lives ?? player?.lives;
  lives.textContent = Number.isInteger(lifeCount) ? `Lives: ${"♥".repeat(Math.max(0, lifeCount!))}${"♡".repeat(Math.max(0, 2 - lifeCount!))}` : "";
  const eliminated = message.eliminated === true || player?.eliminated === true;
  if (eliminated) {
    releaseHeld();
    gameHeading.textContent = "You've been eliminated :(";
    gameMessage.textContent = "Keep watching the big screen for the results.";
    poseGrid.replaceChildren();
  } else if (message.type === "flash_pose_result") {
    gameHeading.textContent = message.success ? "Pose locked!" : "Keep dancing!";
    // Results update feedback and lives without taking away player agency.
    // Existing controls and an uninterrupted hold remain active for free posing.
  } else if (["countdown", "dance", "genuine_stop_grace", "resolve", "flash_wait"].includes(phase) ||
             message.type === "flash_pose_challenge") {
    renderControls(message.available_directions ?? []);
  } else if (message.type === "flash_pose_results") {
    releaseHeld();
    gameHeading.textContent = message.placement ? `You placed #${message.placement}` : "Round complete";
    gameMessage.textContent = "Check the big screen for the final results.";
    poseGrid.replaceChildren();
  } else {
    releaseHeld();
    poseGrid.replaceChildren();
  }
}

function rememberIdentity(message: HostMessage): boolean {
  if (!message.player || typeof message.player.name !== "string" ||
      typeof message.session_id !== "string" || typeof message.reconnect_token !== "string") return false;
  store(STORAGE.name, message.player.name);
  store(STORAGE.session, message.session_id);
  store(STORAGE.token, message.reconnect_token);
  showJoined(message.player);
  return true;
}

function reconnect(): void {
  if (stopped || retry !== undefined) return;
  if (joined) {
    playerState.textContent = "Reconnecting";
    leaveButton.disabled = true;
  } else {
    joinForm.hidden = true;
  }
  status.textContent = "Host disconnected. Reconnecting…";
  retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}

async function connect(): Promise<void> {
  status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
  try {
    const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw new Error("Session unavailable");
    const config: unknown = await response.json();
    if (!config || typeof config !== "object" || !("protocol" in config) || config.protocol !== 1 ||
        !("websocket_port" in config) || !Number.isInteger(config.websocket_port) ||
        Number(config.websocket_port) < 1024 || Number(config.websocket_port) > 65535 ||
        !("session_id" in config) || typeof config.session_id !== "string") {
      throw new Error("Unsupported session");
    }
    if (stopped) return;
    const peer = new WebSocket(`ws://${location.hostname}:${config.websocket_port}`);
    socket = peer;
    const deadline = setTimeout(() => peer.close(), 7000);
    peer.onopen = () => {
      const reconnectToken = stored(STORAGE.token);
      const priorSession = stored(STORAGE.session);
      peer.send(JSON.stringify({
        type: "hello",
        protocol: 1,
        ...(reconnectToken ? { reconnect_token: reconnectToken, session_id: priorSession } : {}),
      }));
    };
    peer.onmessage = (event: MessageEvent<string>) => {
      let message: HostMessage;
      try { message = JSON.parse(event.data) as HostMessage; } catch { peer.close(); return; }
      if (message.type === "welcome" && message.protocol === 1 && Number.isInteger(message.connection_id)) {
        clearTimeout(deadline);
        if (message.resume_status === "resumed" && rememberIdentity(message)) {
          releaseHeld(false);
          if (message.gameplay) showGame(message.gameplay);
          return;
        }
        if (message.resume_status === "session_restarted") {
          forgetIdentity();
          showJoin("The host started a new session. Join again with your name.", true);
        } else if (message.resume_status === "expired") {
          forgetIdentity();
          showJoin("Your previous player expired. Join again with your name.", true);
        } else {
          showJoin("Connected. Enter your name to join.", true);
        }
      } else if (message.type === "join_accepted") {
        if (!rememberIdentity(message)) peer.close();
      } else if (message.type === "join_rejected" || message.type === "error") {
        joinButton.disabled = false;
        status.textContent = message.message ?? "The host could not complete that action.";
        if (!joined) nameInput.focus();
      } else if (message.type === "left") {
        forgetIdentity();
        showJoin("You left the lobby. Enter a name to join again.", true);
      } else if (message.type === "flash_pose_snapshot" || message.type === "flash_pose_challenge" ||
                 message.type === "flash_pose_result" || message.type === "flash_pose_results") {
        showGame(message);
      } else if (message.type === "lobby") {
        releaseHeld(false);
        if (message.player) rememberIdentity(message);
        else if (joined) {
          gameCard.hidden = true;
          playerCard.hidden = false;
          playerState.textContent = "Waiting for the next game";
          status.textContent = message.message ?? "Waiting for the next game";
        }
      }
    };
    peer.onclose = event => {
      clearTimeout(deadline);
      releaseHeld(false);
      if (socket === peer) socket = undefined;
      if (event.code === 4000) {
        stopped = true;
        leaveButton.disabled = true;
        status.textContent = "This player continued in another tab.";
        playerState.textContent = "Open in another tab";
        return;
      }
      reconnect();
    };
    peer.onerror = () => peer.close();
  } catch { reconnect(); }
}

joinForm.addEventListener("submit", event => {
  event.preventDefault();
  const name = nameInput.value.trim();
  store(STORAGE.name, name);
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    status.textContent = "Still connecting. Try again in a moment.";
    return;
  }
  joinButton.disabled = true;
  status.textContent = "Joining…";
  socket.send(JSON.stringify({ type: "join", name }));
});

leaveButton.addEventListener("click", () => {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;
  leaveButton.disabled = true;
  status.textContent = "Leaving…";
  socket.send(JSON.stringify({ type: "leave" }));
});

window.addEventListener("pagehide", () => {
  stopped = true;
  releaseHeld(false);
  clearTimeout(retry);
  retry = undefined;
  socket?.close();
});
window.addEventListener("pageshow", event => {
  if (event.persisted) { stopped = false; void connect(); }
});
void connect();
export {};
