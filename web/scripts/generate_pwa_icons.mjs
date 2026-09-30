// Reuse the approved Squircle idle frame and Playground logo; no external art.
import { PNG } from 'pngjs';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const root = new URL('../../', import.meta.url);
const load = path => PNG.sync.read(readFileSync(new URL(path, root)));
const body = load('assets/runtime/animated_characters/squircle/v1/idle-front-colorable.png');
const face = load('assets/runtime/animated_characters/squircle/v1/idle-front-neutral.png');
const logo = load('assets/runtime/lobby_playground/play_shapes_logo.png');
for (const size of [180, 192, 512]) {
  const output = new PNG({ width: size, height: size });
  for (let i = 0; i < output.data.length; i += 4) output.data.set([214, 244, 225, 255], i);
  function draw(image, sourceWidth, sourceHeight, left, top, width, height) {
    // Area-average the source for crisp downscaled Home Screen artwork.
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const totals = [0, 0, 0, 0]; let samples = 0;
      const x0 = Math.floor(x * sourceWidth / width), x1 = Math.max(x0 + 1, Math.floor((x + 1) * sourceWidth / width));
      const y0 = Math.floor(y * sourceHeight / height), y1 = Math.max(y0 + 1, Math.floor((y + 1) * sourceHeight / height));
      for (let sy = y0; sy < Math.min(y1, sourceHeight); sy++) for (let sx = x0; sx < Math.min(x1, sourceWidth); sx++) {
        const from = (sy * image.width + sx) * 4, a = image.data[from + 3] / 255;
        for (let channel = 0; channel < 3; channel++) totals[channel] += image.data[from + channel] * a;
        totals[3] += a; samples++;
      }
      const to = ((top + y) * size + left + x) * 4, alpha = totals[3] / samples;
      for (let channel = 0; channel < 3; channel++) output.data[to + channel] = Math.round(totals[channel] / samples + output.data[to + channel] * (1 - alpha));
    }
  }
  const tileSize = Math.round(size * .82), tileLeft = Math.floor((size - tileSize) / 2);
  draw(body, 256, 256, tileLeft, 0, tileSize, tileSize);
  draw(face, 256, 256, tileLeft, 0, tileSize, tileSize);
  const logoWidth = Math.round(size * .92), logoHeight = Math.round(logoWidth * logo.height / logo.width);
  draw(logo, logo.width, logo.height, Math.floor((size - logoWidth) / 2), size - logoHeight - Math.round(size * .04), logoWidth, logoHeight);
  writeFileSync(fileURLToPath(new URL(`web/public/app-icon-${size}.png`, root)), PNG.sync.write(output));
}
