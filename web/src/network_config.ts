export function controllerSocketUrl(config: unknown, pageUrl: string): string {
  const page = new URL(pageUrl);
  if (!config || typeof config !== "object") throw new Error("Unsupported session");
  const values = config as Record<string, unknown>;
  const secure = page.protocol === "https:";
  if (page.protocol !== "http:" && !secure) throw new Error("Unsupported page protocol");
  if (
    values.protocol !== 1 ||
    typeof values.session_id !== "string" ||
    values.http_scheme !== (secure ? "https" : "http") ||
    values.websocket_scheme !== (secure ? "wss" : "ws") ||
    !Number.isInteger(values.websocket_port) ||
    Number(values.websocket_port) < 1024 ||
    Number(values.websocket_port) > 65535
  ) {
    throw new Error("Invalid or mixed-content controller configuration");
  }
  const endpoint = new URL(page.origin);
  endpoint.protocol = secure ? "wss:" : "ws:";
  endpoint.port = String(values.websocket_port);
  return endpoint.href;
}
