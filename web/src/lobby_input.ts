export type LobbyAction = { type: "lobby_move"; horizontal: number } | { type: "lobby_jump_release" };

/** Device-independent lobby gesture state. The stick and jump retain separate touches. */
export class LobbyInputState {
  active = false;
  stickHeld = false;
  horizontal = 0;
  jumpPointer: number | undefined;

  constructor(private readonly emit: (action: LobbyAction) => void) {}

  activate(): void { this.active = true; }

  deactivate(): void {
    if (this.active && this.stickHeld) this.emit({ type: "lobby_move", horizontal: 0 });
    this.active = false;
    this.stickHeld = false;
    this.horizontal = 0;
    this.jumpPointer = undefined;
  }

  move(horizontal: number): void {
    if (!this.active || !Number.isFinite(horizontal)) return;
    this.stickHeld = true;
    this.horizontal = Math.max(-1, Math.min(1, horizontal));
    this.emit({ type: "lobby_move", horizontal: this.horizontal });
  }

  repeatMove(): void {
    if (this.active && this.stickHeld) this.emit({ type: "lobby_move", horizontal: this.horizontal });
  }

  endStick(): void {
    if (!this.active || !this.stickHeld) return;
    this.stickHeld = false;
    this.horizontal = 0;
    this.emit({ type: "lobby_move", horizontal: 0 });
  }

  pressJump(pointerId: number): void {
    if (this.active && this.jumpPointer === undefined) this.jumpPointer = pointerId;
  }

  releaseJump(pointerId: number, cancelled = false): void {
    if (pointerId !== this.jumpPointer) return;
    this.jumpPointer = undefined;
    if (this.active && !cancelled) this.emit({ type: "lobby_jump_release" });
  }

  keyboardJump(): void {
    if (this.active) this.emit({ type: "lobby_jump_release" });
  }
}
