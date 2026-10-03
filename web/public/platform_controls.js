import nipplejs from "./vendor/nipplejs.mjs";
import { PlatformInputState, DEFAULT_PLATFORM_SETTINGS, } from "./platform_input.js";
import { bindControllerLifecycle } from "./immersive.js";
/** One actual control component, mounted by a context adapter with its own transport. */
export class PlatformControls {
    screen;
    stickZone;
    actionButton;
    context;
    input;
    manager;
    repeat;
    listeners = new AbortController();
    unbindLifecycle;
    lastMoveAt = -Infinity;
    constructor(screen, stickZone, actionButton, context, settings = DEFAULT_PLATFORM_SETTINGS) {
        this.screen = screen;
        this.stickZone = stickZone;
        this.actionButton = actionButton;
        this.context = context;
        this.input = new PlatformInputState((intent) => this.context.send(intent), settings);
        this.repeat = setInterval(() => this.input.refresh(), this.input.settings.refreshIntervalMsec);
        const options = { signal: this.listeners.signal };
        actionButton.addEventListener("pointerdown", (event) => {
            if ((event.pointerType === "mouse" && event.button !== 0) ||
                !this.input.pressAction(event.pointerId))
                return;
            event.preventDefault();
            try {
                actionButton.setPointerCapture(event.pointerId);
            }
            catch {
                this.input.releaseAction(event.pointerId, true);
            }
            this.renderAction();
        }, options);
        actionButton.addEventListener("pointerup", (event) => {
            if (event.pointerId !== this.input.actionPointer)
                return;
            event.preventDefault();
            // The latest stick snapshot is embedded in this one synchronous release send.
            this.input.releaseAction(event.pointerId);
            this.releaseCapture(event.pointerId);
            this.renderAction();
        }, options);
        for (const name of ["pointercancel", "lostpointercapture"]) {
            actionButton.addEventListener(name, (event) => {
                if (event.pointerId !== this.input.actionPointer)
                    return;
                this.input.releaseAction(event.pointerId, true);
                this.releaseCapture(event.pointerId);
                this.renderAction();
            }, options);
            stickZone.addEventListener(name, () => {
                this.input.endStick();
                this.renderAction();
                this.destroyJoystick();
                if (this.input.active && !document.hidden && document.hasFocus())
                    this.createJoystick();
            }, options);
        }
        actionButton.addEventListener("keydown", (event) => {
            if (event.key !== " " && event.key !== "Enter")
                return;
            event.preventDefault();
            if (!event.repeat)
                this.input.pressKey(event.key);
            this.renderAction();
        }, options);
        actionButton.addEventListener("keyup", (event) => {
            if (event.key !== " " && event.key !== "Enter")
                return;
            event.preventDefault();
            this.input.releaseKey(event.key);
            this.renderAction();
        }, options);
        actionButton.addEventListener("blur", () => {
            const pointer = this.input.actionPointer;
            this.input.cancelAction();
            this.releaseCapture(pointer);
            this.renderAction();
        }, options);
        actionButton.addEventListener("click", (event) => {
            if (event.detail === 0)
                this.input.activateAction();
        }, options);
        this.unbindLifecycle = bindControllerLifecycle((event) => {
            this.cancelTouches();
            if (event?.type !== "blur" &&
                event?.type !== "pagehide" &&
                this.input.active &&
                !document.hidden &&
                document.hasFocus())
                this.createJoystick();
        });
        window.addEventListener("focus", () => {
            if (this.input.active)
                this.createJoystick();
        }, options);
        document.addEventListener("visibilitychange", () => {
            if (!document.hidden && this.input.active)
                this.createJoystick();
        }, options);
        this.renderAction();
    }
    activate() {
        if (this.input.active)
            return;
        this.screen.hidden = false;
        document.documentElement.classList.add(this.context.activeClass);
        this.input.activate();
        this.lastMoveAt = -Infinity;
        this.renderAction();
        this.createJoystick();
    }
    createJoystick() {
        if (this.manager)
            return;
        const manager = nipplejs.create({
            zone: this.stickZone,
            mode: "static",
            position: { left: "50%", top: "50%" },
            size: 116,
            color: { back: "#168573", front: "#ffd879" },
            restJoystick: true,
            restOpacity: 0.9,
            fadeTime: 0,
        });
        this.manager = manager;
        manager.on("move", (event) => {
            if (this.manager !== manager)
                return;
            const firstMove = !this.input.stickHeld;
            if (!this.input.updateAxes(event.data.vector.x, event.data.vector.y))
                return;
            this.renderAction();
            const now = performance.now();
            if (firstMove || now - this.lastMoveAt >= this.input.settings.moveIntervalMsec) {
                this.input.refresh();
                this.lastMoveAt = now;
            }
        });
        manager.on("end", () => {
            if (this.manager !== manager)
                return;
            this.input.endStick();
            this.renderAction();
        });
    }
    renderAction() {
        const label = this.input.action === "fall" ? "FALL" : "JUMP";
        this.actionButton.textContent = label;
        this.actionButton.setAttribute("aria-label", label === "FALL" ? "Fall" : "Jump");
        this.actionButton.classList.toggle("is-held", this.input.actionHeld);
    }
    releaseCapture(pointer) {
        if (pointer === undefined)
            return;
        try {
            if (this.actionButton.hasPointerCapture(pointer))
                this.actionButton.releasePointerCapture(pointer);
        }
        catch {
            /* A browser may already have released capture during cancellation. */
        }
    }
    destroyJoystick() {
        const manager = this.manager;
        this.manager = undefined;
        manager?.destroy();
    }
    cancelTouches() {
        const pointer = this.input.actionPointer;
        this.input.cancel();
        this.releaseCapture(pointer);
        this.renderAction();
        this.destroyJoystick();
        this.lastMoveAt = -Infinity;
    }
    deactivate() {
        this.cancelTouches();
        this.input.deactivate();
        this.screen.hidden = true;
        document.documentElement.classList.remove(this.context.activeClass);
    }
    /** Cancel against the old transport before replacing it; never carry touches across contexts. */
    setContext(context) {
        const wasActive = this.input.active;
        this.deactivate();
        this.context = context;
        if (wasActive)
            this.activate();
    }
    destroy() {
        this.deactivate();
        clearInterval(this.repeat);
        this.listeners.abort();
        this.unbindLifecycle();
    }
}
