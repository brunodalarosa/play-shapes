import type { FaceManifest } from "../shape_paddle/face.js";
import { validLook, type PaddleLook, type PaddleShape } from "../shape_paddle/paddle.js";

export type Phase = "preparing" | "countdown" | "start" | "active" | "between_rounds" | "finished";

export interface Snapshot {
  type: "tilt_shift_3d_snapshot";
  generation: string;
  sequence: number;
  phase: Phase;
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
  /** The paddle's physical angle, clockwise on screen. */
  angle_radians: number;
  paddle_ids: string[];
  /** Length and thickness in arena widths. */
  paddle_size: [number, number];
  color: string;
  face: string;
  look: PaddleLook;
}

/** What the Pre-minigame screen sends a Tilt Shift 3D phone, before teams exist. */
export interface Preparation {
  paddle_size: [number, number];
  generation: string;
  calibrated: boolean;
  usable: boolean;
  landscape: boolean;
  capture_state: string;
  angle_radians: number;
  color: string;
  face: string;
  look: PaddleLook;
}

/** One frame of the phone's paddle. */
export interface Frame {
  shape: PaddleShape;
  angle: number;
  face: string;
  /** A spectator's paddle rests smaller under the team's waiting message. */
  resting: boolean;
}

export interface Presentation {
  update(frame: Frame): void;
  dispose(): void;
}

export interface ViewModule {
  createTiltPaddleView(canvas: HTMLCanvasElement, manifest: FaceManifest): Promise<Presentation>;
}

/** World units per arena width, as on the shared screen. */
export const WORLD_UNITS = 19.2;
const PHASES = ["preparing", "countdown", "start", "active", "between_rounds", "finished"];

const colour = (value: unknown) => typeof value === "string" && /^[0-9a-f]{6}$/i.test(value);
const face = (value: unknown) =>
  typeof value === "string" && value.length <= 64 && /^face_[a-z]+(?:_[a-z]+)*$/.test(value);
const size = (value: unknown) =>
  Array.isArray(value) &&
  value.length === 2 &&
  value.every((part) => Number.isFinite(part) && part > 0 && part <= 2);

export function validSnapshot(value: unknown): value is Snapshot {
  if (!value || typeof value !== "object") return false;
  const v = value as Snapshot;
  return (
    v.type === "tilt_shift_3d_snapshot" &&
    typeof v.generation === "string" &&
    v.generation.length > 0 &&
    v.generation.length <= 64 &&
    Number.isSafeInteger(v.sequence) &&
    v.sequence >= 0 &&
    PHASES.includes(v.phase) &&
    Number.isInteger(v.round) &&
    v.round >= 1 &&
    v.round <= 24 &&
    (v.team === 0 || v.team === 1) &&
    Number.isFinite(v.angle_radians) &&
    Array.isArray(v.paddle_ids) &&
    (v.paddle_ids.length >= 1 || v.selected === false) &&
    v.paddle_ids.length <= 5 &&
    new Set(v.paddle_ids).size === v.paddle_ids.length &&
    v.paddle_ids.every((id) => typeof id === "string" && id.length > 0 && id.length <= 96) &&
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
    size(v.paddle_size) &&
    colour(v.color) &&
    face(v.face) &&
    validLook(v.look)
  );
}

export function validPreparation(value: unknown): value is Preparation {
  if (!value || typeof value !== "object") return false;
  const v = value as Preparation;
  return (
    typeof v.generation === "string" &&
    Number.isFinite(v.angle_radians) &&
    typeof v.usable === "boolean" &&
    typeof v.calibrated === "boolean" &&
    size(v.paddle_size) &&
    colour(v.color) &&
    face(v.face) &&
    validLook(v.look)
  );
}

/** The paddle a snapshot or preparation describes, in world units. */
export function paddleShape(
  sizeInWidths: [number, number],
  color: string,
  team: number,
  look: PaddleLook,
): PaddleShape {
  return {
    length: sizeInWidths[0] * WORLD_UNITS,
    thickness: sizeInWidths[1] * WORLD_UNITS,
    body: color,
    outline: look.outline_colors[Math.min(2, Math.max(0, team))],
    look,
  };
}
