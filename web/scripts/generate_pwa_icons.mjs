// Reuse the current Cubio icon render and the approved logo; no animation sheets.
import { PNG } from "pngjs";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
const root = new URL("../../", import.meta.url);
const load = (path) => PNG.sync.read(readFileSync(new URL(path, root)));
const character = load("art/cubio/previews/three-quarter.png");
const logo = cutOut(load("art/logo/play-shapes-logo.png"));

// The logo master is opaque on cream. Saturation separates the colored letters from the
// background, giving alpha with soft edges; the result is cropped to the lettering.
function cutOut(image) {
  let left = image.width,
    top = image.height,
    right = 0,
    bottom = 0;
  for (let y = 0; y < image.height; y++)
    for (let x = 0; x < image.width; x++) {
      const at = (y * image.width + x) * 4,
        rgb = image.data.subarray(at, at + 3),
        saturation = (Math.max(...rgb) - Math.min(...rgb)) / 255,
        alpha = Math.min(Math.max((saturation - 0.12) / 0.3, 0), 1);
      image.data[at + 3] = Math.round(alpha * 255);
      if (alpha > 0) {
        left = Math.min(left, x);
        right = Math.max(right, x);
        top = Math.min(top, y);
        bottom = Math.max(bottom, y);
      }
    }
  const cropped = new PNG({ width: right - left + 1, height: bottom - top + 1 });
  PNG.bitblt(image, cropped, left, top, cropped.width, cropped.height, 0, 0);
  return cropped;
}
for (const size of [180, 192, 512]) {
  const output = new PNG({ width: size, height: size });
  for (let i = 0; i < output.data.length; i += 4) output.data.set([214, 244, 225, 255], i);
  function draw(image, sourceWidth, sourceHeight, left, top, width, height) {
    // Area-average the source for crisp downscaled Home Screen artwork.
    for (let y = 0; y < height; y++)
      for (let x = 0; x < width; x++) {
        const totals = [0, 0, 0, 0];
        let samples = 0;
        const x0 = Math.floor((x * sourceWidth) / width),
          x1 = Math.max(x0 + 1, Math.floor(((x + 1) * sourceWidth) / width));
        const y0 = Math.floor((y * sourceHeight) / height),
          y1 = Math.max(y0 + 1, Math.floor(((y + 1) * sourceHeight) / height));
        for (let sy = y0; sy < Math.min(y1, sourceHeight); sy++)
          for (let sx = x0; sx < Math.min(x1, sourceWidth); sx++) {
            const from = (sy * image.width + sx) * 4,
              a = image.data[from + 3] / 255;
            for (let channel = 0; channel < 3; channel++)
              totals[channel] += image.data[from + channel] * a;
            totals[3] += a;
            samples++;
          }
        const to = ((top + y) * size + left + x) * 4,
          alpha = totals[3] / samples;
        for (let channel = 0; channel < 3; channel++)
          output.data[to + channel] = Math.round(
            totals[channel] / samples + output.data[to + channel] * (1 - alpha),
          );
      }
  }
  // The stacked logo is tall, so the character sits smaller above it.
  const tileSize = Math.round(size * 0.66),
    tileLeft = Math.floor((size - tileSize) / 2);
  draw(character, character.width, character.height, tileLeft, 0, tileSize, tileSize);
  const logoWidth = Math.round(size * 0.8),
    logoHeight = Math.round((logoWidth * logo.height) / logo.width);
  draw(
    logo,
    logo.width,
    logo.height,
    Math.floor((size - logoWidth) / 2),
    size - logoHeight - Math.round(size * 0.08),
    logoWidth,
    logoHeight,
  );
  writeFileSync(
    fileURLToPath(new URL(`web/public/app-icon-${size}.png`, root)),
    PNG.sync.write(output),
  );
}
