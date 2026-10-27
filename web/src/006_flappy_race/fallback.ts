import { courseWindow, toCanvas, type Window } from "./framing.js";
import type { Frame, Presentation, ViewSetup } from "./types.js";

/** The race drawn flat on a 2D canvas when WebGL is unavailable, framed as the 3D view is. */
export function createFallbackView(canvas: HTMLCanvasElement, setup: ViewSetup): Presentation {
  const { course } = setup;
  const context = canvas.getContext("2d");
  let focus = course.flight.start_x;
  let shown: Window = courseWindow(course.view_height, 1, focus, setup.focusShare);
  let size: [number, number] = [1, 1];

  return {
    draw(frame: Frame): void {
      if (!context) return;

      const rect = canvas.getBoundingClientRect();
      const ratio = Math.min(2, window.devicePixelRatio || 1);
      const width = Math.max(1, Math.round(rect.width * ratio));
      const height = Math.max(1, Math.round(rect.height * ratio));
      if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
      }
      size = [Math.max(1, rect.width), Math.max(1, rect.height)];
      focus = frame.focusX;
      shown = courseWindow(course.view_height, size[0] / size[1], focus, setup.focusShare);
      const at = (x: number, y: number) => toCanvas(shown, size, x, y);
      const metre = size[1] / course.view_height;
      const box = (color: string, x0: number, x1: number, y0: number, y1: number) => {
        const [left, top] = at(x0, y1);
        const [right, bottom] = at(x1, y0);
        context.fillStyle = color;
        context.fillRect(left, top, right - left, bottom - top);
      };

      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      context.clearRect(0, 0, size[0], size[1]);
      const flight = course.flight;
      const right = shown.left + shown.width;
      box("#fff3cb", flight.finish_x - 0.25, flight.finish_x + 0.25, 0, course.view_height);
      for (const obstacle of flight.obstacles) {
        if (obstacle.x_end < shown.left || obstacle.x_start > right) continue;
        box("#d6a86c", obstacle.x_start, obstacle.x_end, 0, obstacle.gap_bottom);
        box("#d6a86c", obstacle.x_start, obstacle.x_end, obstacle.gap_top, course.view_height * 2);
      }
      box("#b98a55", shown.left, right, -course.view_height, 0);
      context.fillStyle = "#f2c230";
      flight.pickups.forEach((pickup, index) => {
        if (frame.taken[index] !== 0 || pickup.x < shown.left - 2 || pickup.x > right + 2) return;
        const [x, y] = at(pickup.x, pickup.y);
        context.beginPath();
        context.arc(x, y, pickup.half_size * metre, 0, Math.PI * 2);
        context.fill();
      });

      if (!frame.cubioVisible) return;
      const [x, y] = at(frame.cubioX, frame.cubioY);
      context.translate(x, y);
      context.rotate(-frame.tilt);
      context.fillStyle = setup.color;
      context.fillRect(-metre, -metre, metre * 2, metre * 2);
      context.fillStyle = "#1f2a33";
      for (const eye of [-0.4, 0.4]) {
        context.beginPath();
        context.arc(eye * metre, -0.2 * metre, 0.16 * metre, 0, Math.PI * 2);
        context.fill();
      }
    },
    project(x: number, y: number): [number, number] {
      return toCanvas(shown, size, x, y);
    },
    dispose(): void {
      context?.setTransform(1, 0, 0, 1, 0, 0);
      context?.clearRect(0, 0, canvas.width, canvas.height);
    },
  };
}
