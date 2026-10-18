import { PerspectiveCamera, Scene, WebGLRenderer } from "three";

export class Viewport {
  readonly scene = new Scene();
  readonly camera = new PerspectiveCamera(30, 1, 0.01, 200);
  readonly renderer: WebGLRenderer;
  private readonly observer: ResizeObserver;
  private request = 0;
  private previous = 0;
  private disposed = false;

  constructor(
    canvas: HTMLCanvasElement,
    private readonly frame: (delta: number, seconds: number) => void,
  ) {
    this.renderer = new WebGLRenderer({ canvas, alpha: true, antialias: true });
    this.renderer.setClearColor(0x000000, 0);
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(canvas);
    document.addEventListener("visibilitychange", this.visibility);
    this.resize();
    this.visibility();
  }

  private resize(): void {
    const { width, height } = this.renderer.domElement.getBoundingClientRect();
    this.renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
    this.renderer.setSize(Math.max(1, width), Math.max(1, height), false);
    this.camera.aspect = Math.max(1, width) / Math.max(1, height);
    this.camera.updateProjectionMatrix();
  }

  private visibility = (): void => {
    cancelAnimationFrame(this.request);
    this.previous = 0;
    if (!document.hidden && !this.disposed) this.request = requestAnimationFrame(this.render);
  };

  private render = (now: number): void => {
    if (this.disposed || document.hidden) return;

    const delta = this.previous ? Math.min(0.1, (now - this.previous) / 1000) : 0;
    this.previous = now;
    this.frame(delta, now / 1000);
    this.renderer.render(this.scene, this.camera);
    this.request = requestAnimationFrame(this.render);
  };

  dispose(): void {
    this.disposed = true;
    cancelAnimationFrame(this.request);
    this.observer.disconnect();
    document.removeEventListener("visibilitychange", this.visibility);
    this.renderer.dispose();
  }
}
