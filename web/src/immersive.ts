export async function attemptImmersive(
  requestFullscreen: (() => Promise<void> | void) | undefined,
  requestOrientationLock: (() => Promise<void>) | undefined,
): Promise<void> {
  try {
    await requestFullscreen?.();
  } catch {
    /* Permission denial is a supported fallback. */
  }
  try {
    await requestOrientationLock?.();
  } catch {
    /* Orientation lock is optional. */
  }
}

/** Safari gesture events predate touch-action. Block defaults only on play surfaces. */
export function protectControllerSurface(surface: HTMLElement): void {
  const prevent = (event: Event): void => {
    if (!surface.hidden && event.cancelable) event.preventDefault();
  };
  surface.addEventListener(
    "touchstart",
    (event) => {
      if (event.touches.length > 1) prevent(event);
    },
    { passive: false },
  );
  for (const name of [
    "touchmove",
    "gesturestart",
    "gesturechange",
    "gestureend",
    "contextmenu",
    "selectstart",
  ]) {
    surface.addEventListener(name, prevent, { passive: false });
  }
}

export function bindControllerLifecycle(
  cancel: (event?: Event) => void,
  target: Window = window,
  page: Document = document,
): () => void {
  const bindings: Array<() => void> = [];
  const listen = (surface: EventTarget, name: string, handler: (event: Event) => void): void => {
    surface.addEventListener(name, handler);
    bindings.push(() => surface.removeEventListener(name, handler));
  };
  const resize = (event?: Event): void => {
    page.documentElement.style.setProperty(
      "--controller-height",
      `${target.visualViewport?.height ?? target.innerHeight}px`,
    );
    cancel(event);
  };
  listen(target, "blur", cancel);
  listen(target, "pagehide", cancel);
  listen(page, "visibilitychange", (event) => {
    if (page.hidden) cancel(event);
  });
  listen(target, "resize", resize);
  listen(target, "orientationchange", resize);
  if (target.visualViewport) listen(target.visualViewport, "resize", resize);
  listen(page, "fullscreenchange", resize);
  resize();
  return () => {
    for (const unbind of bindings) unbind();
  };
}
