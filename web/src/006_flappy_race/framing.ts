/**
 * The part of the course the phone shows: the whole view height, from the ground to the top of
 * the view, fills the canvas height, and the followed spot sits `share` of the width from the
 * left. Metres along the course and above the ground.
 */
export interface Window {
  left: number;
  width: number;
  height: number;
}

export function courseWindow(
  viewHeight: number,
  aspect: number,
  focusX: number,
  share: number,
): Window {
  const width = viewHeight * aspect;
  return { left: focusX - share * width, width, height: viewHeight };
}

/** Where course point `x`, `y` falls on a canvas `size` CSS pixels across, in that window. */
export function toCanvas(
  window: Window,
  size: [number, number],
  x: number,
  y: number,
): [number, number] {
  return [((x - window.left) / window.width) * size[0], (1 - y / window.height) * size[1]];
}
