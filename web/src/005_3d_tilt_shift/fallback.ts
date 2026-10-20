import { Blinker, FaceImages, faceLayers, type FaceManifest } from "../shape_paddle/face.js";
import { drawPaddle } from "../shape_paddle/paddle.js";
import type { Frame, Presentation } from "./types.js";

/** The player's paddle drawn flat on a 2D canvas, for browsers without WebGL. */
export class FlatPaddleView implements Presentation {
  private frame: Frame | undefined;
  private readonly context: CanvasRenderingContext2D | null;
  private readonly blinker = new Blinker();
  private readonly images: FaceImages | undefined;
  private request = 0;
  private disposed = false;

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly manifest: FaceManifest | undefined,
  ) {
    this.context = canvas.getContext("2d");
    this.images = manifest ? new FaceImages(manifest, undefined, () => this.draw()) : undefined;
    this.request = requestAnimationFrame(this.tick);
  }

  update(frame: Frame): void {
    this.frame = frame;
  }

  dispose(): void {
    this.disposed = true;
    cancelAnimationFrame(this.request);
  }

  private tick = (): void => {
    if (this.disposed) return;
    this.draw();
    this.request = requestAnimationFrame(this.tick);
  };

  private draw(): void {
    const context = this.context;
    if (!context || !this.frame) return;
    const width = this.canvas.clientWidth;
    const height = this.canvas.clientHeight;
    const ratio = Math.min(devicePixelRatio || 1, 2);
    if (this.canvas.width !== Math.round(width * ratio))
      this.canvas.width = Math.round(width * ratio);
    if (this.canvas.height !== Math.round(height * ratio))
      this.canvas.height = Math.round(height * ratio);
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);
    const { shape, angle, face, resting } = this.frame;
    const scale = (Math.min(width, height) * (resting ? 0.6 : 0.82)) / shape.length;
    context.translate(width / 2, height / 2);
    context.scale(scale, scale);
    const layers = this.manifest
      ? faceLayers(this.manifest, face, this.blinker.closed(performance.now() / 1000))
      : [];
    drawPaddle(context, shape, angle, this.images, layers);
  }
}
