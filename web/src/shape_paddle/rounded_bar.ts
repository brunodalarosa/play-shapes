// The rounded bar's outline, built as the host's RoundedBar builds it: length along X, thickness
// along Y, centred, with a corner radius that never stretches with the length.

export const CORNER_SEGMENTS = 5;

/** The outline counter-clockwise, X right and Y up, from the right end's upper corner. */
export function roundedOutline(
  length: number,
  thickness: number,
  radius: number,
  segments = CORNER_SEGMENTS,
): [number, number][] {
  const halfX = Math.max(length, 0.0001) / 2;
  const halfY = Math.max(thickness, 0.0001) / 2;
  const corner = Math.min(Math.max(radius, 0), halfX, halfY);
  const innerX = halfX - corner;
  const innerY = halfY - corner;
  const centres: [number, number][] = [
    [innerX, innerY],
    [-innerX, innerY],
    [-innerX, -innerY],
    [innerX, -innerY],
  ];
  const count = Math.max(1, Math.floor(segments));
  const points: [number, number][] = [];
  centres.forEach(([x, y], index) => {
    for (let step = 0; step <= count; step++) {
      const angle = (index * Math.PI) / 2 + ((Math.PI / 2) * step) / count;
      points.push([x + Math.cos(angle) * corner, y + Math.sin(angle) * corner]);
    }
  });
  return points;
}

/** Traces [outline] as a path on a Y-down canvas, centred on the context's origin. */
export function tracePath(context: CanvasRenderingContext2D, outline: [number, number][]): void {
  context.beginPath();
  outline.forEach(([x, y], index) => {
    if (index === 0) context.moveTo(x, -y);
    else context.lineTo(x, -y);
  });
  context.closePath();
}
