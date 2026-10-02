import { PlatformControls } from "./platform_controls.js";
import { createLobbyContext } from "./lobby_input.js";
/** Playground mounting adapter; all joystick, gesture and lifecycle behavior is shared. */
export class LobbyControls extends PlatformControls {
    constructor(screen, stickZone, actionButton, send) {
        super(screen, stickZone, actionButton, createLobbyContext(send));
    }
}
