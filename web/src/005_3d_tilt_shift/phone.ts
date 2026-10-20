import type { MotionStream } from "../motion_stream.js";
import { loadManifest, type FaceManifest } from "../shape_paddle/face.js";
import { FlatPaddleView } from "./fallback.js";
import {
  paddleShape,
  validPreparation,
  validSnapshot,
  type Frame,
  type Preparation,
  type Presentation,
  type ViewModule,
} from "./types.js";

/** Team value used before teams exist: the paddle takes the neutral outline. */
const NO_TEAM = 2;
const RETRY_MSEC = 1000;
/**
 * Every phone reaches this screen from one host broadcast. A random wait of up to this long
 * spreads their first downloads, since the host accepts only a few new connections at once.
 */
const STAGGER_MSEC = 1500;

/**
 * The Tilt Shift 3D phone: landscape, motion permission, neutral calibration and READY as in
 * Tilt Shift, with the player's own paddle drawn in 3D, turning with the host's physical angle
 * and showing the host's chosen face.
 */
export class TiltShift3DPhone {
  private canvas: HTMLCanvasElement;
  private flat: HTMLCanvasElement;
  private actions: HTMLElement;
  private permission: HTMLButtonElement;
  private calibration: HTMLButtonElement;
  private ready: HTMLButtonElement;
  private state: HTMLElement;
  private orientation: HTMLElement;
  private presentation: Presentation | undefined;
  private manifest: FaceManifest | undefined;
  private mounting = 0;
  private mounted = false;
  private frame: Frame | undefined;
  private team = NO_TEAM;
  private generation: string | undefined;
  private sequence = -1;
  private preparing = false;
  private readyAvailable = false;
  private selected = true;
  private roundToken: string | undefined;
  private connected = false;
  private usable = false;
  private calibrated = false;
  private landscape = false;
  private isReady = false;
  private capture = "waiting";

  constructor(
    private surface: HTMLElement,
    private stream: MotionStream,
    private sendReady: (
      ready: boolean,
      context?: { generation: string; round_token: string },
    ) => void,
    private load: () => Promise<ViewModule>,
    private isLandscape: () => boolean = () =>
      window.matchMedia("(orientation: landscape)").matches,
  ) {
    this.canvas = surface.querySelector<HTMLCanvasElement>("#tilt3d-paddle")!;
    this.flat = surface.querySelector<HTMLCanvasElement>("#tilt3d-flat")!;
    this.actions = surface.querySelector<HTMLElement>("#tilt3d-actions")!;
    this.permission = surface.querySelector<HTMLButtonElement>("#tilt3d-permission")!;
    this.calibration = surface.querySelector<HTMLButtonElement>("#tilt3d-calibrate")!;
    this.ready = surface.querySelector<HTMLButtonElement>("#tilt3d-ready")!;
    this.state = surface.querySelector<HTMLElement>("#tilt3d-state")!;
    this.orientation = surface.querySelector<HTMLElement>("#tilt3d-orientation")!;
    this.permission.addEventListener("click", () => {
      this.permission.disabled = true;
      void this.stream.requestPermission().finally(() => this.buttons());
    });
    this.calibration.addEventListener("click", () => {
      if (this.stream.requestCalibration(this.actionContext())) this.calibration.disabled = true;
    });
    this.ready.addEventListener("click", () => {
      if (this.ready.disabled) return;
      this.ready.disabled = true;
      this.sendReady(!this.isReady, this.actionContext());
    });
  }

  preparation(value: unknown, ready: boolean): boolean {
    if (!validPreparation(value)) return false;
    this.generation = value.generation;
    this.sequence = -1;
    this.preparing = this.readyAvailable = this.selected = this.connected = true;
    this.roundToken = undefined;
    this.usable = value.usable;
    this.calibrated = value.calibrated;
    this.landscape = value.landscape === true;
    this.capture = value.capture_state;
    this.isReady = ready;
    this.team = NO_TEAM;
    this.show(value, value.angle_radians);
    return true;
  }

  snapshot(value: unknown): boolean {
    if (!validSnapshot(value)) return false;
    if (this.generation !== undefined && value.generation !== this.generation) return false;
    if (value.sequence < this.sequence) return false;
    this.generation = value.generation;
    this.sequence = value.sequence;
    this.preparing = value.calibration_available === true;
    this.readyAvailable = value.ready_available === true;
    this.selected = value.selected !== false;
    this.roundToken = value.round_token;
    this.isReady = value.ready === true;
    if (value.usable !== undefined) this.usable = value.usable;
    if (value.calibrated !== undefined) this.calibrated = value.calibrated;
    this.landscape = value.landscape === true;
    this.connected = true;
    this.team = value.team;
    this.show(value, this.selected ? value.angle_radians : 0);
    this.surface.hidden = value.phase === "finished";
    return true;
  }

  feedback(): void {
    const state = this.stream.controlState;
    if (!state) return;
    this.capture = state.capture_state;
    this.usable = state.usable;
    this.calibrated = state.calibrated;
    this.landscape = state.landscape === true;
    this.buttons();
  }

  disconnect(): void {
    this.connected = this.usable = false;
    this.buttons();
  }

  hide(): void {
    this.surface.hidden = true;
    this.generation = undefined;
    this.sequence = -1;
    this.preparing = this.connected = this.usable = false;
    this.mounting++;
    this.mounted = false;
    this.presentation?.dispose();
    this.presentation = undefined;
    this.frame = undefined;
  }

  /** The frame the phone draws now, for tests. */
  currentFrame(): Frame | undefined {
    return this.frame;
  }

  private show(
    value: Pick<Preparation, "paddle_size" | "color" | "face" | "look">,
    angle: number,
  ): void {
    this.frame = {
      shape: paddleShape(value.paddle_size, value.color, this.team, value.look),
      angle,
      face: value.face,
      resting: !this.selected,
    };
    const [top, bottom] = value.look.wall_colors;
    this.surface.style.setProperty("--tilt3d-wall", `linear-gradient(#${top}, #${bottom})`);
    this.surface.hidden = false;
    this.surface.setAttribute("data-waiting", String(!this.selected));
    this.surface.setAttribute("data-team", String(this.team));
    this.buttons();
    if (!this.mounted) {
      this.mounted = true;
      this.mount();
    }
    this.presentation?.update(this.frame);
  }

  /**
   * Draws in 3D once three.js and the faces load; without WebGL, or if either fails, the flat
   * drawing takes over on its own canvas, since a canvas keeps the first kind of context it gets.
   */
  private mount(): void {
    const mounting = ++this.mounting;
    this.canvas.hidden = this.flat.hidden = true;
    void (async () => {
      let next: Presentation;
      let flat = false;
      try {
        // One retry rides out a moment when the host turns connections away.
        next = await this.createView(mounting).catch(async () => {
          await new Promise((done) => setTimeout(done, RETRY_MSEC));
          return this.createView(mounting);
        });
      } catch {
        if (mounting !== this.mounting) return;
        next = new FlatPaddleView(this.flat, this.manifest);
        flat = true;
      }
      if (mounting !== this.mounting) {
        next.dispose();
        return;
      }
      this.presentation = next;
      this.canvas.hidden = flat;
      this.flat.hidden = !flat;
      this.surface.setAttribute("data-view", flat ? "flat" : "3d");
      if (this.frame) next.update(this.frame);
    })();
  }

  private async createView(mounting: number): Promise<Presentation> {
    if (!this.manifest) {
      await new Promise((done) => setTimeout(done, Math.random() * STAGGER_MSEC));
      if (mounting !== this.mounting) throw new Error("The phone left this screen");
    }
    this.manifest ??= await loadManifest();
    if (mounting !== this.mounting) throw new Error("The phone left this screen");
    return (await this.load()).createTiltPaddleView(this.canvas, this.manifest);
  }

  private actionContext(): { generation: string; round_token: string } | undefined {
    return this.roundToken && this.generation
      ? { generation: this.generation, round_token: this.roundToken }
      : undefined;
  }

  private buttons(): void {
    const landscape = this.landscape && this.isLandscape();
    this.orientation.hidden = !this.preparing;
    this.orientation.textContent = landscape
      ? "Hold your phone in landscape while you get ready."
      : "Turn your phone to landscape. If it stays upright, turn off rotation lock.";
    this.permission.hidden = this.usable;
    this.permission.disabled = !this.connected || !this.stream.active;
    this.calibration.hidden = !this.preparing;
    this.calibration.disabled = !this.connected || !this.usable;
    this.ready.hidden = !this.readyAvailable;
    this.ready.disabled =
      !this.connected || (!this.isReady && (!this.usable || !this.calibrated || !landscape));
    this.ready.textContent = this.isReady ? "CANCEL" : "READY";
    this.ready.setAttribute("aria-pressed", String(this.isReady));
    this.actions.hidden = (!this.preparing && this.usable) || (!this.selected && !this.preparing);
    const blocked: Record<string, string> = {
      insecure: "Motion needs a secure connection",
      unsupported: "Motion is unavailable",
      denied: "Motion access was denied",
      error: "Motion access could not start",
      unavailable: "Motion is unavailable",
      degenerate_orientation: "Hold the screen toward you",
    };
    this.state.textContent = this.preparing && !this.usable ? (blocked[this.capture] ?? "") : "";
    this.state.hidden = !this.state.textContent;
  }
}
