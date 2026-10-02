export async function attemptImmersive(requestFullscreen, requestOrientationLock) {
    try {
        await requestFullscreen?.();
    }
    catch { /* Permission denial is a supported fallback. */ }
    try {
        await requestOrientationLock?.();
    }
    catch { /* Orientation lock is optional. */ }
}
/** Safari gesture events predate touch-action. Block defaults only on play surfaces. */
export function protectControllerSurface(surface) {
    const prevent = (event) => {
        if (!surface.hidden && event.cancelable)
            event.preventDefault();
    };
    surface.addEventListener("touchstart", event => { if (event.touches.length > 1)
        prevent(event); }, { passive: false });
    for (const name of ["touchmove", "gesturestart", "gesturechange", "gestureend", "contextmenu", "selectstart"]) {
        surface.addEventListener(name, prevent, { passive: false });
    }
}
export function bindControllerLifecycle(cancel, target = window, page = document) {
    const bindings = [];
    const listen = (surface, name, handler) => {
        surface.addEventListener(name, handler);
        bindings.push(() => surface.removeEventListener(name, handler));
    };
    const resize = (event) => {
        page.documentElement.style.setProperty("--controller-height", `${target.visualViewport?.height ?? target.innerHeight}px`);
        cancel(event);
    };
    listen(target, "blur", cancel);
    listen(target, "pagehide", cancel);
    listen(page, "visibilitychange", event => { if (page.hidden)
        cancel(event); });
    listen(target, "resize", resize);
    listen(target, "orientationchange", resize);
    if (target.visualViewport)
        listen(target.visualViewport, "resize", resize);
    listen(page, "fullscreenchange", resize);
    resize();
    return () => { for (const unbind of bindings)
        unbind(); };
}
