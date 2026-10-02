/** Keep the current host's horizontal movement/jump routes while handing off full intent.
 * The fall route is deliberately distinct: an unsupported fall must never become a jump.
 */
export function lobbyAction(intent) {
    const axes = { horizontal: intent.input.axes.x, vertical: intent.input.axes.y, stance: intent.input.stance };
    if (intent.kind === "move")
        return { type: "lobby_move", ...axes };
    return intent.action === "fall"
        ? { type: "lobby_fall_release", action: "fall", ...axes }
        : { type: "lobby_jump_release", action: "jump", ...axes };
}
export function createLobbyContext(send) {
    return { activeClass: "lobby-active", send: intent => send(lobbyAction(intent)) };
}
