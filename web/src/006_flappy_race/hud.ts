/** The heart that floats at the respawn spot while the player waits. */
export interface FloatingHeart {
  /** Canvas position, CSS pixels. */
  at: [number, number];
  /** owed: an outline that fills as a heart refills; cooling: spent, not tappable yet; ready. */
  state: "owed" | "cooling" | "ready";
  refillShare: number;
}

export interface HudFrame {
  hearts: { count: number; full: number; refillShare: number };
  /** Share of the course behind the player, 0 to 1. */
  progress: number;
  secondsLeft: number;
  lastSeconds: boolean;
  /** The large centre text: the countdown, GO, or the player's finish. */
  cue: string;
  floating?: FloatingHeart;
}

/** 1st, 2nd, 3rd, 4th, ..., 11th, 12th, 13th, ..., 21st. */
export function ordinal(place: number): string {
  const tens = place % 100;
  const ones = place % 10;
  const suffix =
    tens >= 11 && tens <= 13
      ? "th"
      : ones === 1
        ? "st"
        : ones === 2
          ? "nd"
          : ones === 3
            ? "rd"
            : "th";
  return `${place}${suffix}`;
}

/** Whole seconds as m:ss. */
export function clockText(seconds: number): string {
  const whole = Math.max(0, Math.ceil(seconds));
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}

/** The race's text and hearts over the phone's view, in plain DOM. */
export class FlappyRaceHud {
  private readonly hearts: HTMLElement;
  private readonly progress: HTMLElement;
  private readonly timer: HTMLElement;
  private readonly cue: HTMLElement;
  private readonly floating: HTMLElement;
  private readonly layer: HTMLElement;
  private shownCount = -1;

  constructor(private readonly root: HTMLElement) {
    const find = (selector: string) => root.querySelector<HTMLElement>(selector)!;
    this.hearts = find(".flappy-hearts");
    this.progress = find(".flappy-progress-fill");
    this.timer = find(".flappy-timer");
    this.cue = find(".flappy-cue");
    this.floating = find(".flappy-floating-heart");
    this.layer = find(".flappy-hud");
  }

  update(frame: HudFrame): void {
    const { count, full, refillShare } = frame.hearts;
    if (this.shownCount !== count) {
      this.shownCount = count;
      this.hearts.replaceChildren(
        ...Array.from({ length: count }, () => {
          const heart = document.createElement("span");
          heart.className = "flappy-heart";
          heart.textContent = "♥";
          return heart;
        }),
      );
    }
    Array.from(this.hearts.children).forEach((child, index) => {
      const heart = child as HTMLElement;
      heart.dataset.fill = index < full ? "full" : index === full ? "refill" : "empty";
      heart.style.setProperty("--refill", index === full ? String(refillShare) : "0");
    });
    const progress = Math.min(1, Math.max(0, frame.progress));
    this.progress.style.inlineSize = `${Math.round(progress * 1000) / 10}%`;
    this.timer.textContent = clockText(frame.secondsLeft);
    this.timer.dataset.last = String(frame.lastSeconds);
    if (this.cue.textContent !== frame.cue) this.cue.textContent = frame.cue;
    this.cue.hidden = frame.cue === "";

    const floating = frame.floating;
    this.floating.hidden = !floating;
    if (floating) {
      this.floating.dataset.state = floating.state;
      this.floating.style.setProperty("--refill", String(floating.refillShare));
      this.floating.style.transform = `translate(${floating.at[0]}px, ${floating.at[1]}px)`;
    }
  }

  /** Flies a copy of heart `index` from the row to `to`, in canvas CSS pixels. */
  flyHeart(index: number, to: [number, number], seconds: number): void {
    const source = this.hearts.children[index] as HTMLElement | undefined;
    if (!source) return;

    const layer = this.layer.getBoundingClientRect();
    const start = source.getBoundingClientRect();
    const flying = document.createElement("span");
    flying.className = "flappy-heart flappy-heart-flight";
    flying.textContent = "♥";
    flying.dataset.fill = "full";
    this.root.append(flying);
    const from = [
      start.left + start.width / 2 - layer.left,
      start.top + start.height / 2 - layer.top,
    ];
    const keyframes = [
      { transform: `translate(${from[0]}px, ${from[1]}px) scale(1)` },
      { transform: `translate(${to[0]}px, ${to[1]}px) scale(1.6)` },
    ];
    const animation = flying.animate?.(keyframes, {
      duration: seconds * 1000,
      easing: "ease-in-out",
    });
    if (!animation) {
      flying.remove();
      return;
    }
    animation.onfinish = animation.oncancel = () => flying.remove();
  }

  /** Removes any heart still in flight. */
  clear(): void {
    for (const flying of Array.from(this.root.querySelectorAll(".flappy-heart-flight")))
      flying.remove();
  }
}
