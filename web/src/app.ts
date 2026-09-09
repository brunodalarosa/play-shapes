const status = document.querySelector<HTMLElement>("#status")!;
let socket: WebSocket | undefined;
let retry: ReturnType<typeof setTimeout> | undefined;
let stopped = false;

function reconnect(): void {
  if (stopped || retry !== undefined) return;
  status.textContent = "Host disconnected. Reconnecting…";
  retry = setTimeout(() => { retry = undefined; void connect(); }, 2000);
}

async function connect(): Promise<void> {
  status.textContent = "Connecting to the host…";
  try {
    const response = await fetch("/session.json", { cache: "no-store", signal: AbortSignal.timeout(5000) });
    if (!response.ok) throw new Error("Session unavailable");
    const config: unknown = await response.json();
    if (!config || typeof config !== "object" || !("protocol" in config) || config.protocol !== 1 ||
        !("websocket_port" in config) || !Number.isInteger(config.websocket_port) ||
        Number(config.websocket_port) < 1024 || Number(config.websocket_port) > 65535) {
      throw new Error("Unsupported session");
    }
    if (stopped) return;
    const peer = new WebSocket(`ws://${location.hostname}:${config.websocket_port}`);
    socket = peer;
    const deadline = setTimeout(() => peer.close(), 7000);
    peer.onopen = () => peer.send(JSON.stringify({ type: "hello", protocol: 1 }));
    peer.onmessage = (event: MessageEvent<string>) => {
      try {
        const message = JSON.parse(event.data);
        if (message.type !== "welcome" || message.protocol !== 1 || !Number.isInteger(message.connection_id)) return;
        clearTimeout(deadline);
        status.textContent = "Connected to Play Shapes. You're ready!";
      } catch { peer.close(); }
    };
    peer.onclose = () => { clearTimeout(deadline); reconnect(); };
    peer.onerror = () => peer.close();
  } catch { reconnect(); }
}

window.addEventListener("pagehide", () => {
  stopped = true;
  clearTimeout(retry);
  retry = undefined;
  socket?.close();
});
window.addEventListener("pageshow", (event) => {
  if (event.persisted) { stopped = false; void connect(); }
});
void connect();
export {};
