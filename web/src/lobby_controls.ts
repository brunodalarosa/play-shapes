import { PlatformControls } from "./platform_controls.js";
import { createLobbyContext, type LobbyAction } from "./lobby_input.js";

/** Playground mounting adapter; all joystick, gesture and lifecycle behavior is shared. */
export class LobbyControls extends PlatformControls {
  constructor(screen: HTMLElement, stickZone: HTMLElement, actionButton: HTMLButtonElement, send: (action: LobbyAction) => void) {
    super(screen, stickZone, actionButton, createLobbyContext(send));
  }
}
