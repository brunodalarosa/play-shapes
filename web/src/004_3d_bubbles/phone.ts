import { bindControllerLifecycle } from "../immersive.js";
import { canTouch, TouchInput } from "./input.js";
import type { InputMessage } from "./input.js";
import { BubbleState, choosePresentation, isSnapshot } from "./state.js";
import type { Message, Presentation, ViewModule } from "./types.js";

export class BubblePhone {
  private state = new BubbleState();
  private presentation?: Presentation;
  private pointer?: number;
  private timer?: ReturnType<typeof setInterval>;
  private unbind?: () => void;
  private generation = 0;
  private feedback = "";
  private readonly input: TouchInput;

  constructor(
    private readonly surface: HTMLElement,
    private readonly canvas: HTMLCanvasElement,
    private readonly score: HTMLElement,
    private readonly circle: HTMLElement,
    connected: () => boolean,
    nextSequence: () => number,
    send: (message: InputMessage) => void,
    private readonly load: () => Promise<ViewModule>,
  ) {
    this.input = new TouchInput(
      () => !surface.hidden && canTouch(this.state.snapshot, connected()),
      nextSequence,
      send,
    );
    surface.addEventListener("pointerdown", (event) => {
      if (this.pointer !== undefined || (event.pointerType === "mouse" && event.button !== 0))
        return;

      const rect = surface.getBoundingClientRect();
      if (
        !this.input.start(
          [event.clientX, event.clientY],
          [rect.width, rect.height],
          performance.now(),
        )
      )
        return;

      event.preventDefault();
      this.pointer = event.pointerId;
      try {
        surface.setPointerCapture(event.pointerId);
      } catch {
        this.cancel();
      }
    });
    surface.addEventListener("pointermove", (event) => {
      if (event.pointerId !== this.pointer) return;

      event.preventDefault();
      this.input.move([event.clientX, event.clientY], performance.now());
    });
    surface.addEventListener("pointerup", (event) => {
      if (event.pointerId !== this.pointer) return;

      event.preventDefault();
      this.input.release([event.clientX, event.clientY]);
      this.cancel();
    });
    for (const name of ["pointercancel", "lostpointercapture"])
      surface.addEventListener(name, (event) => {
        if ((event as PointerEvent).pointerId === this.pointer) this.cancel();
      });
  }

  receive(message: Message): void {
    const previous = this.state.snapshot;
    if (isSnapshot(message) && message.phase === "lobby_return") {
      this.hide();
      return;
    }
    if (isSnapshot(message) && !canTouch(message, true)) this.cancel();
    if (!this.state.receive(message, performance.now())) return;

    if (isSnapshot(message)) {
      this.surface.hidden = false;
      this.score.textContent = String(Math.max(0, Math.floor(message.score)));
      const key = `${message.host_time_msec}:${message.event}`;
      if (message.type === "bubbles_3d_feedback" && this.feedback !== key) {
        this.feedback = key;
        try {
          if (message.event === "captured") navigator.vibrate?.(18);
          else if (message.event === "pop") navigator.vibrate?.([35, 45, 35]);
        } catch {
          /* Vibration support is optional. */
        }
      }
      if (!previous) this.mount();
    }
    this.paint();
  }

  private mount(): void {
    const generation = ++this.generation;
    this.presentation = this.fallback();
    this.unbind = bindControllerLifecycle(() => this.cancel());
    this.timer = setInterval(() => {
      this.input.tick(performance.now());
      this.paint();
    }, 30);
    void choosePresentation(
      async () => (await this.load()).createBubbleView(this.canvas),
      () => this.fallback(),
    ).then((presentation) => {
      if (generation !== this.generation) {
        presentation.dispose();
        return;
      }
      this.presentation?.dispose();
      this.presentation = presentation;
      this.canvas.hidden = false;
      this.circle.hidden = true;
      this.paint();
    });
  }

  private fallback(): Presentation {
    return {
      update: ({ snapshot, visual }) => {
        this.canvas.hidden = true;
        this.circle.hidden = false;
        this.circle.style.backgroundColor = snapshot.character_color;
        const maximum = Math.max(snapshot.visual_tuning.max_radius, visual.radius, 0.01);
        const size = 24 + (60 * visual.radius) / maximum;
        this.circle.style.setProperty("--bubble-size", `${size}%`);
      },
      dispose: () => {},
    };
  }

  private paint(): void {
    if (document.hidden) return;

    const frame = this.state.frame(performance.now());
    if (frame) this.presentation?.update(frame);
  }

  cancel(): void {
    this.input.cancel();
    const pointer = this.pointer;
    this.pointer = undefined;
    if (pointer !== undefined && this.surface.hasPointerCapture(pointer))
      this.surface.releasePointerCapture(pointer);
  }

  hide(): void {
    this.cancel();
    this.generation++;
    clearInterval(this.timer);
    this.timer = undefined;
    this.unbind?.();
    this.unbind = undefined;
    this.presentation?.dispose();
    this.presentation = undefined;
    this.state = new BubbleState();
    this.feedback = "";
    this.surface.hidden = true;
  }
}
