import nipplejs from "./vendor/nipplejs.mjs";
import { LobbyInputState, type LobbyAction } from "./lobby_input.js";

export class LobbyControls {
  private readonly input: LobbyInputState;
  private manager: ReturnType<typeof nipplejs.create> | undefined;
  private readonly repeat: ReturnType<typeof setInterval>;
  private lastMoveAt = 0;

  constructor(
    private readonly screen: HTMLElement,
    private readonly stickZone: HTMLElement,
    private readonly jumpButton: HTMLButtonElement,
    send: (action: LobbyAction) => void,
  ) {
    this.input = new LobbyInputState(send);
    this.repeat = setInterval(() => this.input.repeatMove(), 100);
    jumpButton.addEventListener("pointerdown", event => {
      if (!this.input.active) return;
      this.input.pressJump(event.pointerId);
      jumpButton.setPointerCapture(event.pointerId);
      jumpButton.classList.add("is-held");
    });
    jumpButton.addEventListener("pointerup", event => {
      this.input.releaseJump(event.pointerId);
      jumpButton.classList.remove("is-held");
    });
    for (const name of ["pointercancel", "lostpointercapture"] as const) {
      jumpButton.addEventListener(name, event => {
        this.input.releaseJump(event.pointerId, true);
        jumpButton.classList.remove("is-held");
      });
    }
    jumpButton.addEventListener("click", event => {
      if (event.detail === 0) this.input.keyboardJump();
    });
    addEventListener("blur", () => this.cancelTouches());
    addEventListener("focus", () => { if (this.input.active) this.createJoystick(); });
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) this.cancelTouches();
      else if (this.input.active) this.createJoystick();
    });
  }

  activate(): void {
    if (this.input.active) return;
    this.screen.hidden = false;
    document.documentElement.classList.add("lobby-active");
    this.input.activate();
    this.createJoystick();
  }

  private createJoystick(): void {
    if (this.manager) return;
    this.manager = nipplejs.create({
      zone: this.stickZone,
      mode: "static",
      position: { left: "50%", top: "50%" },
      lockX: true,
      size: 116,
      color: { back: "#168573", front: "#ffd879" },
      restJoystick: true,
      restOpacity: 0.9,
      fadeTime: 0,
    });
    this.manager.on("move", event => {
      const horizontal = event.data.vector.x;
      const now = performance.now();
      // Keep packet rate bounded; the timer also refreshes held intent.
      if (now - this.lastMoveAt >= 45 || !this.input.stickHeld) {
        this.input.move(horizontal);
        this.lastMoveAt = now;
      } else if (Number.isFinite(horizontal)) {
        this.input.horizontal = Math.max(-1, Math.min(1, horizontal));
      }
    });
    this.manager.on("end", () => this.input.endStick());
  }

  deactivate(): void {
    this.input.deactivate();
    this.manager?.destroy();
    this.manager = undefined;
    this.jumpButton.classList.remove("is-held");
    this.screen.hidden = true;
    document.documentElement.classList.remove("lobby-active");
  }

  cancelTouches(): void {
    this.input.endStick();
    if (this.input.jumpPointer !== undefined) this.input.releaseJump(this.input.jumpPointer, true);
    this.jumpButton.classList.remove("is-held");
    this.manager?.destroy();
    this.manager = undefined;
  }
}
