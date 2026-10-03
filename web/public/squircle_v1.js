const ROOT = "/squircle-v1/";
const BLUE = [30, 136, 229];
export class SquircleV1Canvas {
    clip;
    tile = [256, 256];
    colorable = new Image();
    neutral = new Image();
    blink = new Image();
    tinted = new Map();
    constructor() {
        void this.load();
    }
    async load() {
        try {
            const response = await fetch(`${ROOT}manifest.json`);
            if (!response.ok)
                return;
            const manifest = (await response.json());
            this.tile = manifest.resolution;
            this.clip = manifest.clips.find((clip) => clip.name === "idle" && clip.view === "front");
            this.colorable.src = `${ROOT}idle-front-colorable.png`;
            this.neutral.src = `${ROOT}idle-front-neutral.png`;
            this.blink.src = `${ROOT}idle-front-blink.png`;
        }
        catch {
            /* The page remains usable if character art is unavailable. */
        }
    }
    draw(context, color, x, y, scale, timeMsec, blinking = false, rotation = 0) {
        const clip = this.clip;
        const face = blinking ? this.blink : this.neutral;
        if (!clip ||
            !this.colorable.complete ||
            !face.complete ||
            !this.colorable.naturalWidth ||
            !face.naturalWidth)
            return false;
        const sheet = this.tint(color);
        if (!sheet)
            return false;
        const frame = Math.floor((Math.max(0, timeMsec) * clip.fps) / 1000) % clip.frames;
        const sx = (frame % clip.sheet_columns) * this.tile[0];
        const sy = Math.floor(frame / clip.sheet_columns) * this.tile[1];
        context.save();
        context.translate(x, y);
        context.rotate(rotation);
        for (const layer of [sheet, face])
            context.drawImage(layer, sx, sy, this.tile[0], this.tile[1], -clip.anchor_px[0] * scale, -clip.anchor_px[1] * scale, this.tile[0] * scale, this.tile[1] * scale);
        context.restore();
        return true;
    }
    tint(color) {
        const key = /^#[0-9a-f]{6}$/i.test(color) ? color.toUpperCase() : "#1E88E5";
        const cached = this.tinted.get(key);
        if (cached)
            return cached;
        const canvas = document.createElement("canvas");
        canvas.width = this.colorable.naturalWidth;
        canvas.height = this.colorable.naturalHeight;
        const context = canvas.getContext("2d", { willReadFrequently: true });
        if (!context)
            return undefined;
        context.drawImage(this.colorable, 0, 0);
        const image = context.getImageData(0, 0, canvas.width, canvas.height);
        const rgb = [1, 3, 5].map((index) => Number.parseInt(key.slice(index, index + 2), 16));
        for (let offset = 0; offset < image.data.length; offset += 4) {
            if (image.data[offset + 3] === 0)
                continue;
            const diffuse = Math.min(1.4, Math.max(0, (image.data[offset + 2] - image.data[offset]) / 199));
            for (let channel = 0; channel < 3; channel++)
                image.data[offset + channel] = Math.min(255, Math.max(0, image.data[offset + channel] + diffuse * (rgb[channel] - BLUE[channel])));
        }
        context.putImageData(image, 0, 0);
        this.tinted.set(key, canvas);
        return canvas;
    }
}
