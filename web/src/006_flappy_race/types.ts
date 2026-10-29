import type { Course } from "./messages.js";
import type { CubioGesture } from "../three_view/cubio.js";

/** What one drawn frame of the phone's race shows, in course metres. */
export interface Frame {
  /** Seconds since the previous frame. */
  delta: number;
  /** Where the camera follows: the drawn Cubio, or the respawn spot while waiting. */
  focusX: number;
  cubioX: number;
  cubioY: number;
  /** Nose-up tilt, radians. */
  tilt: number;
  cubioVisible: boolean;
  face: string;
  /** Gesture started this frame; a hit replaces a flap, and respawn protects its pop. */
  gesture?: CubioGesture;
  hitSeconds: number;
  tumbling: boolean;
  idle: boolean;
  /** One entry per pickup, 1 once this player has taken it. */
  taken: Uint8Array;
}

/** The setup a view is made for. */
export interface ViewSetup {
  course: Course;
  color: string;
  /** Share of the width from the left edge to the followed spot. */
  focusShare: number;
}

/** The 3D view or its 2D fallback. */
export interface Presentation {
  draw(frame: Frame): void;
  /** Where the course point `x`, `y` is on the canvas, in CSS pixels. */
  project(x: number, y: number): [number, number];
  dispose(): void;
}

export interface FlappyViewModule {
  createFlappyRaceView(canvas: HTMLCanvasElement, setup: ViewSetup): Promise<Presentation>;
}
