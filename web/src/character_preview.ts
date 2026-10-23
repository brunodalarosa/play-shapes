export interface CharacterPreview {
  setColor(color: string): void;
  dispose(): void;
}

export interface CharacterPreviewModule {
  createCharacterPreview: (
    canvas: HTMLCanvasElement,
    signal?: AbortSignal,
  ) => Promise<CharacterPreview>;
}

/** Only the visible setup canvas owns a renderer. Model and texture downloads stay cached. */
export class JoinCharacterPreview {
  private canvas?: HTMLCanvasElement;
  private view?: CharacterPreview;
  private generation = 0;
  private color = "#1E88E5";
  private loading?: AbortController;

  constructor(
    private readonly canvases: HTMLCanvasElement[],
    private readonly load: () => Promise<CharacterPreviewModule>,
  ) {
    const observer = new MutationObserver(() => this.refresh(this.color));
    for (const canvas of canvases) {
      const section = canvas.closest("section");
      if (section) observer.observe(section, { attributes: true, attributeFilter: ["hidden"] });
    }
    document.addEventListener("visibilitychange", () => this.refresh(this.color));
    window.addEventListener("pagehide", () => this.clear());
    window.addEventListener("pageshow", () => this.refresh(this.color));
  }

  refresh(color: string): void {
    this.color = color;
    const canvas = document.hidden
      ? undefined
      : this.canvases.find((candidate) => !candidate.closest("section")?.hidden);
    if (canvas === this.canvas) {
      this.view?.setColor(color);
      return;
    }
    this.clear();
    if (!canvas) return;

    this.canvas = canvas;
    this.loading = new AbortController();
    canvas.dataset.preview = "loading";
    void this.activate(canvas, this.generation);
  }

  private clear(): void {
    this.generation++;
    this.loading?.abort();
    this.loading = undefined;
    this.view?.dispose();
    this.view = undefined;
    if (this.canvas) this.canvas.dataset.preview = "idle";
    this.canvas = undefined;
  }

  private async activate(canvas: HTMLCanvasElement, generation: number): Promise<void> {
    try {
      const module = await this.load();
      if (generation !== this.generation) return;

      const view = await module.createCharacterPreview(canvas, this.loading?.signal);
      if (generation !== this.generation) {
        view.dispose();
        return;
      }
      this.view = view;
      view.setColor(this.color);
      canvas.dataset.preview = "ready";
    } catch {
      // Selection and joining remain available when a device cannot create a 3D view.
      if (generation === this.generation) canvas.dataset.preview = "unavailable";
    }
  }
}
