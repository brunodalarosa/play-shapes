import type { PlatformIntent, PlatformStance } from "./platform_input.js";
import type { PlatformControlContext } from "./platform_controls.js";

type LobbyAxes = Readonly<{ horizontal: number; vertical: number; stance: PlatformStance }>;
export type LobbyAction = LobbyAxes & (
  | Readonly<{ type: "lobby_move" }>
  | Readonly<{ type: "lobby_jump_release"; action: "jump" }>
  | Readonly<{ type: "lobby_fall_release"; action: "fall" }>
);

/** Keep the current host's horizontal movement/jump routes while handing off full intent.
 * The fall route is deliberately distinct: an unsupported fall must never become a jump.
 */
export function lobbyAction(intent: PlatformIntent): LobbyAction {
  const axes: LobbyAxes = { horizontal: intent.input.axes.x, vertical: intent.input.axes.y, stance: intent.input.stance };
  if (intent.kind === "move") return { type: "lobby_move", ...axes };
  return intent.action === "fall"
    ? { type: "lobby_fall_release", action: "fall", ...axes }
    : { type: "lobby_jump_release", action: "jump", ...axes };
}

export function createLobbyContext(send: (action: LobbyAction) => void): PlatformControlContext {
  return { activeClass: "lobby-active", send: intent => send(lobbyAction(intent)) };
}
