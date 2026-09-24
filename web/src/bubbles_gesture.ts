export type Point = [number, number];
export const MAX_TRACE_POINTS = 128;

export class GestureTrace {
  private points: Point[] = [];
  constructor(private readonly bounds: { left: number; top: number; width: number; height: number }) {}

  add(clientX: number, clientY: number): void {
    if (!Number.isFinite(clientX) || !Number.isFinite(clientY) || this.bounds.width <= 0 || this.bounds.height <= 0) return;
    const point: Point = [Math.max(0, Math.min(1, (clientX - this.bounds.left) / this.bounds.width)), Math.max(0, Math.min(1, (clientY - this.bounds.top) / this.bounds.height))];
    const last = this.points.at(-1);
    if (last && Math.hypot(point[0] - last[0], point[1] - last[1]) < 0.004) return;
    this.points.push(point);
    if (this.points.length > MAX_TRACE_POINTS) {
      this.points = this.points.filter((_, index) => index === 0 || index === this.points.length - 1 || index % 2 === 0);
    }
  }

  completed(): Point[] { return this.points.length >= 2 ? this.points.map(point => [...point]) : []; }

  displacement(): Point {
    if (this.points.length < 2) return [0, 0];
    const first = this.points[0]; const last = this.points.at(-1)!;
    return [last[0] - first[0], last[1] - first[1]];
  }

  preview(circlesToCharge: number): number {
    if (this.points.length < 6) return 0;
    const center = this.points.reduce(([x, y], point) => [x + point[0], y + point[1]], [0, 0]).map(value => value / this.points.length);
    let signed = 0; let absolute = 0;
    for (let index = 1; index < this.points.length; index++) {
      const before = Math.atan2(this.points[index - 1][1] - center[1], this.points[index - 1][0] - center[0]);
      const after = Math.atan2(this.points[index][1] - center[1], this.points[index][0] - center[0]);
      const step = Math.atan2(Math.sin(after - before), Math.cos(after - before));
      signed += step; absolute += Math.abs(step);
    }
    if (absolute < Math.PI * 0.75 || Math.abs(signed) / absolute < 0.65) return 0;
    return Math.min(1, Math.abs(signed) / (Math.PI * 2 * Math.max(1, circlesToCharge)));
  }
}
