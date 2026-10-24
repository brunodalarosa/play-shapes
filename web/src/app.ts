import { BubblePhone } from "./004_3d_bubbles/phone.js";
import { isSnapshot as isBubble3DSnapshot } from "./004_3d_bubbles/state.js";
import type { Message as Bubble3DMessage, ViewModule } from "./004_3d_bubbles/types.js";
import { TiltShift3DPhone } from "./005_3d_tilt_shift/phone.js";
import type { Preparation, ViewModule as TiltViewModule } from "./005_3d_tilt_shift/types.js";
import {
  attemptImmersive,
  protectControllerSurface,
  bindControllerLifecycle,
} from "./immersive.js";
import { PwaOnboarding, isStandalone } from "./pwa.js";
import { bindScreenWakeLock } from "./screen_wake_lock.js";
import { MotionLabController } from "./motion_lab.js";
import { MotionStream, type MotionControlState } from "./motion_stream.js";
import { controllerSocketUrl } from "./network_config.js";
import { JoinCharacterPreview, type CharacterPreviewModule } from "./character_preview.js";
import { LobbyControls } from "./lobby_controls.js";
import type { LobbyAction } from "./lobby_input.js";
import {
  advanceJoinFlow,
  CHARACTER_COLORS,
  chooseJoinColor,
  colorOption,
  createJoinMessage,
  defaultJoinFlow,
  returnToCharacterSelection,
  type JoinFlowState,
} from "./character_selection.js";

const status = document.querySelector<HTMLElement>("#status")!;
bindScreenWakeLock();
const connectionError = document.querySelector<HTMLElement>("#connection-error")!;
const connectionErrors: { text: string; at: string; repeats: number }[] = [];

// Development diagnostics stay outside gameplay's hidden status/onboarding layout.
// Report endpoints and error text only; never dump protocol messages or stored tokens.
function reportConnectionFailure(stage: string, endpoint: string, error: unknown): void {
  const detail = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
  const text = `Step: ${stage}\nEndpoint: ${endpoint}\n${detail}`;
  const last = connectionErrors.at(-1);
  if (last?.text === text) last.repeats++;
  else {
    connectionErrors.push({ text, at: new Date().toISOString(), repeats: 1 });
    if (connectionErrors.length > 6) connectionErrors.shift();
  }
  connectionError.textContent =
    "CONTROLLER ERROR LOG (development)\n" +
    `Browser: ${navigator.userAgent}\n` +
    "Connection failures retry every 2 seconds.\n\n" +
    connectionErrors
      .map((entry) => {
        const repeats = entry.repeats > 1 ? ` (repeated ${entry.repeats} times)` : "";
        return `[${entry.at}]${repeats}\n${entry.text}`;
      })
      .join("\n\n");
  connectionError.hidden = false;
}
window.addEventListener("error", (event) => {
  const cause =
    event.error instanceof Error ? `${event.error.name}: ${event.error.message}` : event.message;
  reportConnectionFailure(
    "Browser JavaScript error",
    new URL(location.href).origin,
    `${cause}\nSource: ${event.filename}:${event.lineno}:${event.colno}`,
  );
});
window.addEventListener("unhandledrejection", (event) => {
  reportConnectionFailure(
    "Unhandled browser promise rejection",
    new URL(location.href).origin,
    event.reason,
  );
});
const selectionScreen = document.querySelector<HTMLElement>("#selection-screen")!;
const selectionPreview = document.querySelector<HTMLCanvasElement>("#selection-preview")!;
const namePreview = document.querySelector<HTMLCanvasElement>("#name-preview")!;
const selectedCharacterLabel = document.querySelector<HTMLElement>("#selected-character-label")!;
const colorGrid = document.querySelector<HTMLElement>("#color-grid")!;
const nextButton = document.querySelector<HTMLButtonElement>("#next-button")!;
const backButton = document.querySelector<HTMLButtonElement>("#back-button")!;
const nameScreen = document.querySelector<HTMLElement>("#name-screen")!;
const joinForm = document.querySelector<HTMLFormElement>("#join-form")!;
const nameInput = document.querySelector<HTMLInputElement>("#player-name")!;
const joinButton = document.querySelector<HTMLButtonElement>("#join-button")!;
const playerCard = document.querySelector<HTMLElement>("#player-card")!;
const readyCard = document.querySelector<HTMLElement>("#ready-card")!;
const readyState = document.querySelector<HTMLElement>("#ready-state")!;
const readyButton = document.querySelector<HTMLButtonElement>("#ready-button")!;
const playerName = document.querySelector<HTMLElement>("#player-name-heading")!;
const playerState = document.querySelector<HTMLElement>("#player-state")!;
const leaveButton = document.querySelector<HTMLButtonElement>("#leave-button")!;
const lobbyController = document.querySelector<HTMLElement>("#lobby-controller")!;
const lobbyStickZone = document.querySelector<HTMLElement>("#lobby-stick-zone")!;
const lobbyJumpButton = document.querySelector<HTMLButtonElement>("#lobby-jump-button")!;
const lobbyLeaveButton = document.querySelector<HTMLButtonElement>("#lobby-leave-button")!;

const motionPanel = document.querySelector<HTMLElement>("#motion-lab")!;
const motionButton = document.querySelector<HTMLButtonElement>("#motion-permission")!;
const motionReadings = document.querySelector<HTMLElement>("#motion-readings")!;
const STORAGE = {
  session: "play-shapes.session-id",
  token: "play-shapes.reconnect-token",
  name: "play-shapes.last-name",
  inputSeq: "play-shapes.input-seq",
} as const;
type PublicPlayer = {
  player_id: string;
  name: string;
  seat: number;
  state: string;
  character_shape?: string;
  character_color?: string;
};
type HostMessage = {
  minigame_id?: string;
  preparation?: Preparation;
  subscription_id?: string;
  control_state?: MotionControlState;
  send_hz?: number;
  stale_msec?: number;
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
  debug_mode?: boolean;
  state?: string;
  gameplay?: HostMessage;
  ready?: boolean;
};

let socket: WebSocket | undefined;
let retry: ReturnType<typeof setTimeout> | undefined;
let stopped = false;
let joined = false;
let isReady = false;
let joinFlow: JoinFlowState = defaultJoinFlow();
let inputSeq = Number.parseInt(stored(STORAGE.inputSeq), 10) || 0;
type Game = "bubbles_3d" | "tilt_shift_3d";
let activeGame: Game | null = null;
const lobbyControls = new LobbyControls(
  lobbyController,
  lobbyStickZone,
  lobbyJumpButton,
  (action: LobbyAction) => {
    if (!joined || !socket || socket.readyState !== WebSocket.OPEN || activeGame !== null) return;
    inputSeq += 1;
    store(STORAGE.inputSeq, String(inputSeq));
    socket.send(JSON.stringify({ ...action, input_seq: inputSeq }));
  },
);

const gameplayMotion = new MotionStream(() => socket);
window.addEventListener("pageshow", (event) => {
  // A cached page retired capture on pagehide; resume through a fresh host subscription.
  if (event.persisted && activeGame === "tilt_shift_3d") socket?.close();
});
const tilt3DSurface = document.querySelector<HTMLElement>("#tilt-shift-3d")!;
const tilt3DPhone = new TiltShift3DPhone(
  tilt3DSurface,
  gameplayMotion,
  (ready, context) => {
    if (socket?.readyState === WebSocket.OPEN)
      socket.send(
        JSON.stringify(
          context
            ? { type: "tilt_shift_3d_ready", ready, ...context }
            : { type: "pre_minigame_ready", ready },
        ),
      );
  },
  () => loadThreeView(),
);
gameplayMotion.onControlState = () => {
  tilt3DPhone.feedback();
};
const motionLab = new MotionLabController(motionPanel, motionButton, motionReadings, () => socket);
const pwa = new PwaOnboarding(
  document.querySelector<HTMLElement>("#app-screen")!,
  document.querySelector<HTMLButtonElement>("#install-button")!,
  document.querySelector<HTMLElement>("#install-guidance")!,
  document.querySelector<HTMLButtonElement>("#browser-button")!,
  () => {
    selectionScreen.hidden = false;
    nextButton.focus();
    void requestImmersiveMode();
  },
);
const bubble3DCard = document.querySelector<HTMLElement>("#bubbles-3d-card")!;
let threeView: Promise<ViewModule & TiltViewModule & CharacterPreviewModule> | undefined;
/** The 3D view module, imported once on first use so other screens never download it. */
function loadThreeView(): Promise<ViewModule & TiltViewModule & CharacterPreviewModule> {
  const url = "/three_view.js";
  threeView ??= (
    import(url) as Promise<ViewModule & TiltViewModule & CharacterPreviewModule>
  ).catch((error: unknown) => {
    threeView = undefined;
    throw error;
  });
  return threeView;
}
const joinPreview = new JoinCharacterPreview([selectionPreview, namePreview], loadThreeView);
const bubble3DPhone = new BubblePhone(
  bubble3DCard,
  document.querySelector<HTMLCanvasElement>("#bubbles-3d-visual")!,
  document.querySelector<HTMLElement>("#bubbles-3d-score")!,
  document.querySelector<HTMLElement>("#bubbles-3d-fallback")!,
  () => socket?.readyState === WebSocket.OPEN,
  () => {
    inputSeq += 1;
    store(STORAGE.inputSeq, String(inputSeq));
    return inputSeq;
  },
  (message) => {
    if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(message));
  },
  () => loadThreeView(),
);
protectControllerSurface(bubble3DCard);

function showBubble3D(message: Bubble3DMessage): void {
  if (!isBubble3DSnapshot(message)) {
    bubble3DPhone.receive(message);
    return;
  }
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  const visible = message.phase !== "lobby_return";
  setGameplaySurface(visible, "bubbles_3d");
  selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = true;
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  status.hidden = true;
  bubble3DPhone.receive(message);
}

for (const surface of [lobbyController, readyCard, tilt3DSurface])
  protectControllerSurface(surface);
bindControllerLifecycle(() => {});

function stored(key: string): string {
  try {
    return localStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}
function store(key: string, value: string): void {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* Page remains usable. */
  }
}
function forgetIdentity(): void {
  try {
    localStorage.removeItem(STORAGE.session);
    localStorage.removeItem(STORAGE.token);
    localStorage.removeItem(STORAGE.inputSeq);
  } catch {
    /* Restricted storage. */
  }
  inputSeq = 0;
}

function selectedCharacterName(): string {
  const color = colorOption(joinFlow.color)?.name ?? "Blue";
  return `${color} Cubio`;
}

function refreshSelectionUi(): void {
  const label = selectedCharacterName();
  selectedCharacterLabel.textContent = label;
  selectionPreview.setAttribute("aria-label", `${label} Shape Character`);
  namePreview.setAttribute("aria-label", `${label} character preview`);
  for (const button of Array.from(colorGrid.querySelectorAll<HTMLButtonElement>(".color-button"))) {
    button.setAttribute("aria-pressed", String(button.dataset.color === joinFlow.color));
  }
  joinPreview.refresh(joinFlow.color);
}

for (const option of CHARACTER_COLORS) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "color-button";
  button.dataset.color = option.hex;
  button.style.backgroundColor = option.hex;
  button.setAttribute("aria-label", `Choose ${option.name}`);
  button.setAttribute("aria-pressed", "false");
  button.addEventListener("click", () => {
    joinFlow = chooseJoinColor(joinFlow, option.hex);
    refreshSelectionUi();
  });
  colorGrid.append(button);
}
refreshSelectionUi();

function setGameplaySurface(active: boolean, game?: Game): void {
  const next = active ? (game ?? null) : null;
  if (next !== "tilt_shift_3d") tilt3DPhone.hide();
  if (next !== "bubbles_3d") bubble3DPhone.hide();
  if (activeGame !== next) {
    if (next === null) {
      try {
        screen.orientation?.unlock?.();
      } catch {
        /* Unsupported orientation API. */
      }
    } else if (document.fullscreenElement) {
      try {
        const orientation = screen.orientation as ScreenOrientation & {
          lock?: (value: string) => Promise<void>;
        };
        const direction = next === "tilt_shift_3d" ? "landscape" : "portrait";
        void Promise.resolve(orientation?.lock?.(direction)).catch(() => {});
      } catch {
        /* Lock denied. */
      }
    }
    activeGame = next;
  }
  document.documentElement.classList.toggle("gameplay-active", next !== null);
  document.documentElement.classList.toggle("bubbles-3d-active", next === "bubbles_3d");
  document.documentElement.classList.toggle("tilt-3d-active", next === "tilt_shift_3d");
}

function showJoin(message: string, focus = false): void {
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  joinFlow = returnToCharacterSelection(joinFlow);
  joined = false;
  setGameplaySurface(false);
  playerCard.hidden = true;
  selectionScreen.hidden = pwa.visible || pwa.show();
  nameScreen.hidden = true;
  joinForm.hidden = true;
  joinButton.disabled = false;
  leaveButton.disabled = false;
  status.textContent = message;
  status.hidden = !message;
  nameInput.value = stored(STORAGE.name);
  refreshSelectionUi();
  if (focus && !pwa.visible) queueMicrotask(() => nextButton.focus());
}
function showJoined(player: PublicPlayer, state = "Connected"): void {
  pwa.hide();
  gameplayMotion.stop();
  motionLab.stop();
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  joined = true;
  setGameplaySurface(false);
  selectionScreen.hidden = true;
  nameScreen.hidden = true;
  joinForm.hidden = true;
  playerCard.hidden = true;
  playerName.textContent = player.name;
  playerState.textContent = state;
  leaveButton.disabled = false;
  lobbyLeaveButton.disabled = false;
  lobbyControls.activate();
  const serverColor = colorOption(player.character_color)?.hex;
  if (serverColor) joinFlow = chooseJoinColor(joinFlow, serverColor);
  status.textContent =
    state === "Connected" ? "Joined. Keep this page open while you play." : state;
  status.hidden = true;
}

function showReady(message: HostMessage): void {
  if (message.minigame_id === "tilt_shift_3d" && message.preparation) {
    showTiltSurface();
    tilt3DPhone.preparation(message.preparation, message.ready === true);
    return;
  }
  gameplayMotion.stop();
  motionLab.stop();
  lobbyControls.deactivate();
  setGameplaySurface(false);
  selectionScreen.hidden = true;
  nameScreen.hidden = true;
  joinForm.hidden = true;
  playerCard.hidden = true;
  readyCard.hidden = false;
  document.documentElement.classList.add("ready-active");
  isReady = message.ready === true;
  readyState.textContent = isReady ? "Ready!" : "Not ready";
  readyButton.textContent = isReady ? "CANCEL" : "READY";
  readyButton.setAttribute("aria-pressed", String(isReady));
  readyButton.setAttribute("aria-label", isReady ? "Cancel ready status" : "Ready up");
  readyButton.disabled = false;
  status.hidden = true;
}

function showTiltSurface(): void {
  motionLab.stop();
  lobbyControls.deactivate();
  setGameplaySurface(true, "tilt_shift_3d");
  selectionScreen.hidden = nameScreen.hidden = joinForm.hidden = playerCard.hidden = true;
  readyCard.hidden = true;
  document.documentElement.classList.remove("ready-active");
  status.hidden = true;
}

function showTilt3D(message: unknown): void {
  if (tilt3DPhone.snapshot(message)) showTiltSurface();
}
readyButton.addEventListener("click", () => {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;
  readyButton.disabled = true;
  socket.send(JSON.stringify({ type: "pre_minigame_ready", ready: !isReady }));
});

nextButton.addEventListener("click", () => {
  if (pwa.visible) return;
  joinFlow = advanceJoinFlow(joinFlow);
  selectionScreen.hidden = true;
  nameScreen.hidden = false;
  joinForm.hidden = false;
  if (!nameInput.value) nameInput.value = stored(STORAGE.name);
  status.hidden = true;
  status.textContent = "";
  refreshSelectionUi();
  queueMicrotask(() => nameInput.focus());
});
backButton.addEventListener("click", () => {
  joinFlow = returnToCharacterSelection(joinFlow);
  nameScreen.hidden = true;
  joinForm.hidden = true;
  selectionScreen.hidden = false;
  status.hidden = true;
  status.textContent = "";
  refreshSelectionUi();
  queueMicrotask(() => nextButton.focus());
});
async function requestImmersiveMode(): Promise<void> {
  if (isStandalone(window, navigator) || document.fullscreenElement) return;
  const root = document.documentElement as HTMLElement & {
    webkitRequestFullscreen?: () => Promise<void> | void;
  };
  const orientation = screen.orientation as ScreenOrientation & {
    lock?: (value: string) => Promise<void>;
  };
  const fullscreen = root.requestFullscreen
    ? () => root.requestFullscreen({ navigationUI: "hide" })
    : root.webkitRequestFullscreen?.bind(root);
  await attemptImmersive(
    fullscreen,
    orientation?.lock ? () => orientation.lock!("portrait") : undefined,
  );
}

function rememberIdentity(message: HostMessage): boolean {
  const player = message.player as PublicPlayer | undefined;
  if (
    !player ||
    typeof player.name !== "string" ||
    typeof message.session_id !== "string" ||
    typeof message.reconnect_token !== "string"
  )
    return false;
  store(STORAGE.name, player.name);
  store(STORAGE.session, message.session_id);
  store(STORAGE.token, message.reconnect_token);
  showJoined(player);
  return true;
}
function reconnect(): void {
  gameplayMotion.stop();
  motionLab.disconnect();
  if (stopped || retry !== undefined) return;
  lobbyControls.deactivate();
  setGameplaySurface(false);
  if (!readyCard.hidden) {
    readyButton.disabled = true;
    readyState.textContent = "Reconnecting…";
  }
  if (joined) {
    playerState.textContent = "Reconnecting";
    leaveButton.disabled = true;
  }
  status.textContent = "Host disconnected. Reconnecting…";
  status.hidden = false;
  retry = setTimeout(() => {
    retry = undefined;
    void connect();
  }, 2000);
}
async function connect(): Promise<void> {
  status.textContent = joined ? "Reconnecting to the host…" : "Connecting to the host…";
  status.hidden = false;
  let stage = "Fetch session configuration";
  let endpoint = new URL("/session.json", location.href).href;
  try {
    const response = await fetch("/session.json", {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error(`HTTP ${response.status} ${response.statusText}`);
    stage = "Parse session configuration JSON";
    const config: unknown = await response.json();
    stage = "Validate session transport configuration";
    const socketUrl = controllerSocketUrl(config, location.href);
    stage = "Open WebSocket";
    endpoint = socketUrl;
    if (stopped) return;
    const peer = new WebSocket(socketUrl);
    socket = peer;
    let socketFailure = "";
    const deadline = setTimeout(() => {
      socketFailure = "No host welcome received within 7000 ms.";
      reportConnectionFailure(stage, endpoint, socketFailure);
      peer.close();
    }, 7000);
    peer.onopen = () => {
      stage = "Wait for host welcome";
      peer.send(
        JSON.stringify({
          type: "hello",
          protocol: 1,
          ...(stored(STORAGE.token)
            ? { reconnect_token: stored(STORAGE.token), session_id: stored(STORAGE.session) }
            : {}),
        }),
      );
    };
    peer.onmessage = (event: MessageEvent<string>) => {
      let message: HostMessage;
      try {
        message = JSON.parse(event.data) as HostMessage;
      } catch (error) {
        // Parser messages can quote the payload, including a welcome's resume token.
        const cause = error instanceof Error ? error.name : "parse error";
        socketFailure = `Invalid JSON received from host (${cause}).`;
        reportConnectionFailure("Parse host message JSON", endpoint, socketFailure);
        peer.close();
        return;
      }
      if (
        message.type === "lobby" ||
        (message.type?.endsWith("_snapshot") && !isBubble3DSnapshot(message))
      ) {
        if (activeGame === "bubbles_3d") setGameplaySurface(false);
      }
      if (
        message.type === "welcome" &&
        message.protocol === 1 &&
        Number.isInteger(message.connection_id)
      ) {
        stage = "Connected WebSocket";
        connectionError.hidden = true;
        connectionError.textContent = "";
        clearTimeout(deadline);
        if (message.resume_status === "resumed" && rememberIdentity(message)) {
          if (isBubble3DSnapshot(message.gameplay)) showBubble3D(message.gameplay);
          else if (message.gameplay?.type === "tilt_shift_3d_snapshot")
            showTilt3D(message.gameplay);
          else if (message.gameplay?.type === "pre_minigame_snapshot") showReady(message.gameplay);
          else if (
            message.gameplay?.type === "lobby" &&
            message.player &&
            "player_id" in message.player &&
            "name" in message.player
          )
            showJoined(
              message.player as PublicPlayer,
              message.gameplay.message ?? "Waiting for the next game",
            );
          return;
        }
        if (message.resume_status === "session_restarted") {
          forgetIdentity();
          showJoin(
            "The host started a new session. Choose your character and name to join again.",
            true,
          );
        } else if (message.resume_status === "expired") {
          forgetIdentity();
          showJoin(
            "Your previous player expired. Choose your character and name to join again.",
            true,
          );
        } else
          showJoin(
            isStandalone(window, navigator) && !stored(STORAGE.token)
              ? "Choose your character to join. " +
                  "If already playing in a browser, leave that controller first."
              : "Connected. Choose your character to join.",
            true,
          );
      } else if (message.type === "join_accepted") {
        if (!rememberIdentity(message)) peer.close();
      } else if (message.type === "join_rejected" || message.type === "error") {
        joinButton.disabled = false;
        readyButton.disabled = false;
        status.textContent = message.message ?? "The host could not complete that action.";
        status.hidden = false;
        if (message.type === "error")
          reportConnectionFailure(
            "Host protocol error",
            endpoint,
            `${message.code ?? "unknown"}: ${status.textContent}`,
          );
        if (!readyCard.hidden) readyState.textContent = status.textContent;
        if (!joined) nameInput.focus();
      } else if (message.type === "left") {
        forgetIdentity();
        showJoin("You left the lobby. Choose your character and name to join again.", true);
      } else if (
        isBubble3DSnapshot(message) ||
        message.type === "bubbles_3d_visual" ||
        message.type === "bubbles_3d_release_result"
      )
        showBubble3D(message as unknown as Bubble3DMessage);
      else if (message.type === "pre_minigame_snapshot") showReady(message);
      else if (message.type === "tilt_shift_3d_snapshot") showTilt3D(message);
      else if (
        message.type === "motion_lab" &&
        joined &&
        typeof message.subscription_id === "string" &&
        typeof message.send_hz === "number"
      ) {
        lobbyControls.deactivate();
        setGameplaySurface(false);
        document.documentElement.classList.remove("ready-active");
        selectionScreen.hidden =
          nameScreen.hidden =
          joinForm.hidden =
          playerCard.hidden =
          readyCard.hidden =
            true;
        status.hidden = true;
        gameplayMotion.stop();
        motionLab.begin({
          subscription_id: message.subscription_id,
          send_hz: message.send_hz,
          stale_msec: message.stale_msec ?? 1000,
        });
      } else if (
        message.type === "motion_subscribe" &&
        joined &&
        typeof message.subscription_id === "string" &&
        typeof message.send_hz === "number"
      ) {
        motionLab.stop();
        lobbyControls.deactivate();
        gameplayMotion.begin({
          subscription_id: message.subscription_id,
          send_hz: message.send_hz,
          stale_msec: message.stale_msec ?? 1000,
        });
        tilt3DPhone.feedback();
      } else if (message.type === "motion_control_state") {
        if (typeof message.subscription_id === "string")
          if (message.control_state)
            gameplayMotion.feedback(message.subscription_id, message.control_state);
      } else if (message.type === "motion_stop") {
        if (typeof message.subscription_id === "string")
          gameplayMotion.stop(message.subscription_id);
        motionLab.stop(message.subscription_id);
        if (
          joined &&
          activeGame === null &&
          readyCard.hidden &&
          !gameplayMotion.active &&
          !motionLab.active
        )
          lobbyControls.activate();
      } else if (message.type === "lobby") {
        gameplayMotion.stop();
        motionLab.stop();
        setGameplaySurface(false);
        readyCard.hidden = true;
        document.documentElement.classList.remove("ready-active");
        if (message.player) rememberIdentity(message);
        else if (joined) {
          playerCard.hidden = true;
          lobbyControls.activate();
          status.hidden = true;
        }
      }
    };
    peer.onclose = (event) => {
      clearTimeout(deadline);
      lobbyControls.deactivate();
      gameplayMotion.stop();
      motionLab.disconnect();
      if (activeGame === "tilt_shift_3d") tilt3DPhone.disconnect();
      else setGameplaySurface(false);
      if (socket === peer) socket = undefined;
      if (event.code === 4000) {
        stopped = true;
        leaveButton.disabled = true;
        readyCard.hidden = true;
        document.documentElement.classList.remove("ready-active");
        status.textContent = "This player continued in another window. Reload to switch back.";
        status.hidden = false;
        playerState.textContent = "Open in another window";
        return;
      }
      if (!stopped)
        reportConnectionFailure(
          stage,
          endpoint,
          `${socketFailure ? socketFailure + "\n" : ""}WebSocket closed: code=${event.code}, ` +
            `reason=${event.reason || "(not provided)"}, wasClean=${event.wasClean}.`,
        );
      reconnect();
    };
    peer.onerror = (event) => {
      socketFailure =
        `WebSocket ${event.type || "error"} event. ` +
        "Browser did not expose the underlying network/TLS reason.";
      reportConnectionFailure(stage, endpoint, socketFailure);
      peer.close();
    };
  } catch (error) {
    if (!stopped) reportConnectionFailure(stage, endpoint, error);
    reconnect();
  }
}

joinForm.addEventListener("submit", (event) => {
  event.preventDefault();
  if (pwa.visible) return;
  const name = nameInput.value.trim();
  store(STORAGE.name, name);
  if (!socket || socket.readyState !== WebSocket.OPEN) {
    status.textContent = "Still connecting. Try again in a moment.";
    status.hidden = false;
    return;
  }
  joinButton.disabled = true;
  status.textContent = "Joining…";
  status.hidden = false;
  socket.send(JSON.stringify(createJoinMessage(name, joinFlow)));
});
function leaveLobby(): void {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;
  lobbyControls.deactivate();
  leaveButton.disabled = true;
  lobbyLeaveButton.disabled = true;
  status.textContent = "Leaving…";
  socket.send(JSON.stringify({ type: "leave" }));
}
leaveButton.addEventListener("click", leaveLobby);
lobbyLeaveButton.addEventListener("click", leaveLobby);
window.addEventListener("pagehide", () => {
  stopped = true;
  lobbyControls.deactivate();
  clearTimeout(retry);
  retry = undefined;
  socket?.close();
});
window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    stopped = false;
    void connect();
  }
});
void connect();
