// How a shape paddle looks, from the host's measurements, and its flat drawing for screens
// without WebGL: the team outline, the cream gap ring, the body in the player's colour and the
// face, as on the shared screen.

import { drawFace, type FaceImages, type FaceLayer } from "./face.js";
import { roundedOutline, tracePath } from "./rounded_bar.js";

/** The host's description of a paddle; lengths are shares of the paddle's thickness. */
export interface PaddleLook {
  corner_ratio: number;
  depth_ratio: number;
  gap_ratio: number;
  outline_ratio: number;
  face_ratio: number;
  gap_color: string;
  outline_colors: string[];
  wall_colors: [string, string];
}

/** One paddle to draw: its size in any unit, its colours and its face. */
export interface PaddleShape {
  length: number;
  thickness: number;
  body: string;
  outline: string;
  look: PaddleLook;
}

export function validLook(value: unknown): value is PaddleLook {
  if (!value || typeof value !== "object") return false;
  const look = value as PaddleLook;
  const colour = (text: unknown) => typeof text === "string" && /^[0-9a-f]{6}$/i.test(text);
  return (
    [
      look.corner_ratio,
      look.depth_ratio,
      look.gap_ratio,
      look.outline_ratio,
      look.face_ratio,
    ].every((ratio) => Number.isFinite(ratio) && ratio >= 0 && ratio <= 3) &&
    colour(look.gap_color) &&
    Array.isArray(look.outline_colors) &&
    look.outline_colors.length === 3 &&
    look.outline_colors.every(colour) &&
    Array.isArray(look.wall_colors) &&
    look.wall_colors.length === 2 &&
    look.wall_colors.every(colour)
  );
}

/** The outlines of the outline ring, the gap ring and the body, outermost first. */
export function paddleOutlines(shape: PaddleShape): [number, number][][] {
  const { length, thickness, look } = shape;
  const radius = thickness * look.corner_ratio;
  const gap = thickness * look.gap_ratio;
  const outline = gap + thickness * look.outline_ratio;
  return [
    roundedOutline(length + outline * 2, thickness + outline * 2, radius + outline),
    roundedOutline(length + gap * 2, thickness + gap * 2, radius + gap),
    roundedOutline(length, thickness, radius),
  ];
}

/**
 * Draws [shape] centred on the context's origin and turned by [angle] radians, clockwise on a
 * Y-down canvas as on the shared screen, with [layers] as its face.
 */
export function drawPaddle(
  context: CanvasRenderingContext2D,
  shape: PaddleShape,
  angle: number,
  images: FaceImages | undefined,
  layers: FaceLayer[],
): void {
  context.save();
  context.rotate(angle);
  const colours = [shape.outline, shape.look.gap_color, shape.body];
  paddleOutlines(shape).forEach((outline, index) => {
    tracePath(context, outline);
    context.fillStyle = `#${colours[index].replace(/^#/, "")}`;
    context.fill();
  });
  if (images) drawFace(context, images, layers, shape.thickness * shape.look.face_ratio);
  context.restore();
}
