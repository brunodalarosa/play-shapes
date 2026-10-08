import type { MotionStream } from "../motion_stream.js";

export type TiltSnapshot = {
  type: "tilt_shift_snapshot";
  generation: string;
  sequence: number;
  phase: "preparing" | "countdown" | "start" | "active" | "between_rounds" | "finished";
  round_token?: string;
  selected?: boolean;
  ready?: boolean;
  ready_available?: boolean;
  calibration_available?: boolean;
  calibrated?: boolean;
  usable?: boolean;
  landscape?: boolean;
  round: number;
  team: 0 | 1;
  angle_radians: number;
  paddle_ids: string[];
  paddle_size: [number, number];
};
export type Preparation = {
  paddle_size: [number, number];
  generation: string;
  calibrated: boolean;
  usable: boolean;
  landscape: boolean;
  capture_state: string;
  angle_radians: number;
};
export function validTiltSnapshot(value: unknown): value is TiltSnapshot {
  if (!value || typeof value !== "object") return false;
  const v = value as TiltSnapshot;
  return (
    v.type === "tilt_shift_snapshot" &&
    typeof v.generation === "string" &&
    v.generation.length > 0 &&
    v.generation.length <= 64 &&
    Number.isSafeInteger(v.sequence) &&
    v.sequence >= 0 &&
    ["preparing", "countdown", "start", "active", "between_rounds", "finished"].includes(v.phase) &&
    Number.isInteger(v.round) &&
    v.round >= 1 &&
    v.round <= 24 &&
    (v.team === 0 || v.team === 1) &&
    Number.isFinite(v.angle_radians) &&
    Array.isArray(v.paddle_ids) &&
    (v.paddle_ids.length >= 1 || v.selected === false) &&
    v.paddle_ids.length <= 5 &&
    new Set(v.paddle_ids).size === v.paddle_ids.length &&
    (v.selected === undefined || typeof v.selected === "boolean") &&
    (v.round_token === undefined ||
      (typeof v.round_token === "string" &&
        v.round_token.length > 0 &&
        v.round_token.length <= 64)) &&
    [
      v.ready,
      v.ready_available,
      v.calibration_available,
      v.calibrated,
      v.usable,
      v.landscape,
    ].every((flag) => flag === undefined || typeof flag === "boolean") &&
    v.paddle_ids.every((id) => typeof id === "string" && id.length > 0 && id.length <= 96) &&
    Array.isArray(v.paddle_size) &&
    v.paddle_size.length === 2 &&
    v.paddle_size.every((size) => Number.isFinite(size) && size > 0 && size <= 2)
  );
}

export class TiltShiftPhone {
  private canvas: HTMLCanvasElement;
  private context: CanvasRenderingContext2D;
  private actions: HTMLElement;
  private permission: HTMLButtonElement;
  private calibration: HTMLButtonElement;
  private ready: HTMLButtonElement;
  private state: HTMLElement;
  private orientation: HTMLElement;
  private images: HTMLImageElement[] = [];
  private bounds: number[][] = [];
  private angle = 0;
  private ratio = 6;
  private team = 2;
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
  private observer: ResizeObserver;

  constructor(
    private surface: HTMLElement,
    private stream: MotionStream,
    private sendReady: (
      ready: boolean,
      context?: { generation: string; round_token: string },
    ) => void,
    private isLandscape: () => boolean = () =>
      window.matchMedia("(orientation: landscape)").matches,
  ) {
    this.canvas = surface.querySelector<HTMLCanvasElement>("canvas")!;
    this.context = this.canvas.getContext("2d")!;
    this.actions = surface.querySelector<HTMLElement>("#tilt-actions")!;
    this.permission = surface.querySelector<HTMLButtonElement>("#tilt-permission")!;
    this.calibration = surface.querySelector<HTMLButtonElement>("#tilt-calibrate")!;
    this.ready = surface.querySelector<HTMLButtonElement>("#tilt-ready")!;
    this.state = surface.querySelector<HTMLElement>("#tilt-state")!;
    this.orientation = surface.querySelector<HTMLElement>("#tilt-orientation")!;
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
    this.observer = new ResizeObserver(() => {
      this.buttons();
      this.draw();
    });
    this.observer.observe(this.canvas);
    void this.loadArt();
  }

  private async loadArt(): Promise<void> {
    const response = await fetch("/tilt-shift/manifest.json");
    if (!response.ok) throw new Error("Tilt Shift artwork metadata could not load");
    const manifest = await response.json();
    for (const name of ["orange", "blue", "neutral"]) {
      const image = new Image();
      image.src = `/tilt-shift/paddle_${name}.png`;
      this.images.push(image);
      this.bounds.push(manifest.assets[`paddles/paddle_${name}.png`].visible_bounds_px);
      image.addEventListener("load", () => this.draw());
    }
  }

  preparation(value: Preparation, ready: boolean): boolean {
    if (typeof value?.generation !== "string" || !Number.isFinite(value.angle_radians))
      return false;
    if (typeof value.usable !== "boolean" || typeof value.calibrated !== "boolean") return false;
    this.generation = value.generation;
    this.sequence = -1;
    this.preparing = this.readyAvailable = this.selected = this.connected = true;
    this.roundToken = undefined;
    this.usable = value.usable;
    this.calibrated = value.calibrated;
    this.landscape = value.landscape === true;
    this.capture = value.capture_state;
    this.angle = value.angle_radians;
    if (
      Array.isArray(value.paddle_size) &&
      value.paddle_size.length === 2 &&
      value.paddle_size.every((size) => Number.isFinite(size) && size > 0)
    )
      this.ratio = value.paddle_size[0] / value.paddle_size[1];
    this.isReady = ready;
    this.team = 2;
    this.surface.hidden = false;
    this.canvas.hidden = false;
    this.surface.setAttribute("data-waiting", "false");
    this.surface.setAttribute("data-team", String(this.team));
    this.actions.hidden = false;
    this.buttons();
    this.draw();
    return true;
  }

  snapshot(value: unknown): boolean {
    if (!validTiltSnapshot(value)) return false;
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
    this.angle = value.angle_radians;
    this.ratio = value.paddle_size[0] / value.paddle_size[1];
    this.surface.hidden = value.phase === "finished";
    this.canvas.hidden = !this.selected;
    this.surface.setAttribute("data-waiting", String(!this.selected));
    this.surface.setAttribute("data-team", String(this.team));
    this.buttons();
    this.draw();
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

  private draw(): void {
    if (this.surface.hidden || !this.selected) return;
    const width = this.canvas.clientWidth,
      height = this.canvas.clientHeight;
    const dpr = Math.min(devicePixelRatio || 1, 2);
    this.canvas.width = Math.round(width * dpr);
    this.canvas.height = Math.round(height * dpr);
    const ctx = this.context;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);
    const image = this.images[this.team],
      bounds = this.bounds[this.team];
    if (!image?.complete || !image.naturalWidth || !bounds) return;
    const length = Math.min(width, height) * 0.82,
      thickness = length / this.ratio;
    const [sx, sy, right, bottom] = bounds;
    const sw = right - sx,
      sh = bottom - sy;
    // Match the shared beam's visible-bound crop and uniformly scaled end caps.
    const capPx = Math.min(96, sw * 0.25),
      cap = Math.min((capPx * thickness) / sh, length * 0.25);
    ctx.translate(width / 2, height / 2);
    ctx.rotate(this.angle);
    ctx.drawImage(image, sx, sy, capPx, sh, -length / 2, -thickness / 2, cap, thickness);
    ctx.drawImage(
      image,
      sx + capPx,
      sy,
      sw - 2 * capPx,
      sh,
      -length / 2 + cap,
      -thickness / 2,
      length - 2 * cap,
      thickness,
    );
    ctx.drawImage(
      image,
      right - capPx,
      sy,
      capPx,
      sh,
      length / 2 - cap,
      -thickness / 2,
      cap,
      thickness,
    );
  }
}
