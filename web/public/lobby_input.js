/** Device-independent lobby gesture state. The stick and jump retain separate touches. */
export class LobbyInputState {
    emit;
    active = false;
    stickHeld = false;
    horizontal = 0;
    jumpPointer;
    constructor(emit) {
        this.emit = emit;
    }
    activate() { this.active = true; }
    deactivate() {
        if (this.active && this.stickHeld)
            this.emit({ type: "lobby_move", horizontal: 0 });
        this.active = false;
        this.stickHeld = false;
        this.horizontal = 0;
        this.jumpPointer = undefined;
    }
    move(horizontal) {
        if (!this.active || !Number.isFinite(horizontal))
            return;
        this.stickHeld = true;
        this.horizontal = Math.max(-1, Math.min(1, horizontal));
        this.emit({ type: "lobby_move", horizontal: this.horizontal });
    }
    repeatMove() {
        if (this.active && this.stickHeld)
            this.emit({ type: "lobby_move", horizontal: this.horizontal });
    }
    endStick() {
        if (!this.active || !this.stickHeld)
            return;
        this.stickHeld = false;
        this.horizontal = 0;
        this.emit({ type: "lobby_move", horizontal: 0 });
    }
    pressJump(pointerId) {
        if (this.active && this.jumpPointer === undefined)
            this.jumpPointer = pointerId;
    }
    releaseJump(pointerId, cancelled = false) {
        if (pointerId !== this.jumpPointer)
            return;
        this.jumpPointer = undefined;
        if (this.active && !cancelled)
            this.emit({ type: "lobby_jump_release" });
    }
    keyboardJump() {
        if (this.active)
            this.emit({ type: "lobby_jump_release" });
    }
}
