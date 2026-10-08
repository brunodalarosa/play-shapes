/** One wake lock for the visible page, independent of game and connection state. */
export function bindScreenWakeLock(
  page: Document = document,
  target: Window = window,
  wakeLock: WakeLock | undefined = navigator.wakeLock,
): () => void {
  let sentinel: WakeLockSentinel | undefined;
  let pending = false;
  let retry = false;
  let suspended = false;
  let stopped = false;
  let generation = 0;

  const visible = (): boolean => !stopped && !suspended && page.visibilityState === "visible";
  const release = (lock: WakeLockSentinel | undefined): void => {
    if (lock && !lock.released) void lock.release().catch(() => {});
  };
  const request = async (): Promise<void> => {
    if (!wakeLock || !visible() || sentinel) return;
    if (pending) {
      retry = true;
      return;
    }

    pending = true;
    const requestedGeneration = generation;
    try {
      const lock = await wakeLock.request("screen");
      if (!visible() || requestedGeneration !== generation) {
        release(lock);
        return;
      }

      if (lock.released) return;
      sentinel = lock;
      lock.addEventListener("release", () => {
        if (sentinel === lock) sentinel = undefined;
      });
    } catch {
      // Battery and browser policy can refuse protection; retry only on a page event.
    } finally {
      pending = false;
      if (retry) {
        retry = false;
        void request();
      }
    }
  };
  const retire = (): void => {
    generation++;
    retry = false;
    release(sentinel);
    sentinel = undefined;
  };
  const visibility = (): void => {
    if (visible()) void request();
    else retire();
  };
  const hide = (): void => {
    suspended = true;
    retire();
  };
  const show = (): void => {
    suspended = false;
    void request();
  };
  const interact = (): void => {
    void request();
  };

  page.addEventListener("visibilitychange", visibility);
  page.addEventListener("pointerdown", interact);
  page.addEventListener("keydown", interact);
  target.addEventListener("pagehide", hide);
  target.addEventListener("pageshow", show);
  void request();
  return () => {
    stopped = true;
    retire();
    page.removeEventListener("visibilitychange", visibility);
    page.removeEventListener("pointerdown", interact);
    page.removeEventListener("keydown", interact);
    target.removeEventListener("pagehide", hide);
    target.removeEventListener("pageshow", show);
  };
}
