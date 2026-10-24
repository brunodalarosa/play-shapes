// Exports the vector face parts at 8x and verifies the preset manifest against the owner's faces.
//
// Usage: node art/shape_characters_face_system_assets/export_faces.mjs [--check] [--review]
//
// Renders every SVG master in vector/ with Playwright's Chromium into assets/runtime/shape_faces/,
// then draws the presets and compares the originals with their supplied references. Emoji
// presets have structural checks; recognizability needs the Godot 3D captures. --check leaves
// PNGs unchanged. --review writes legacy sheets into ignored scratch/review/: original presets
// beside their references at 1x enlarged four times, and at 8x. Writes
// vector/verification.json and exits non-zero when any check fails.
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..", "..");
const require = createRequire(join(root, "web", "package.json"));
const { chromium } = require("playwright");
const { PNG } = require("pngjs");

const VECTOR = join(here, "vector");
const RUNTIME = join(root, "assets", "runtime", "shape_faces");
const MANIFEST = join(RUNTIME, "face_presets.json");
const SCALE = 8;
const NAVY = [0x3d, 0x46, 0x5d];
const WHITE = [255, 255, 255];
const TONGUE_PINK = [0xf4, 0x7d, 0xa8];
const WATER_BLUE = [0x75, 0xcb, 0xee];
const GOLD = [0xff, 0xd1, 0x66];
const MONEY_GREEN = [0x7f, 0xd7, 0x8b];
const PART_PALETTES = {
  facial_part_tongue: [NAVY, TONGUE_PINK],
  facial_part_eye_heart: [NAVY, TONGUE_PINK],
  facial_part_eye_star: [NAVY, GOLD],
  facial_part_tear_drop: [NAVY, WATER_BLUE, WHITE],
  facial_part_sleep_bubble: [NAVY, WATER_BLUE, WHITE],
  facial_part_drool: [NAVY, WATER_BLUE, WHITE],
  facial_part_money_tongue: [NAVY, MONEY_GREEN],
  facial_part_tear_stream: [NAVY, WATER_BLUE, WHITE],
  facial_part_tear_pool: [NAVY, WATER_BLUE, WHITE],
  facial_part_halo: [NAVY, GOLD, WHITE],
};
// The owner's twelve faces, named for their emoji counterparts; each has a reference image.
const ORIGINALS = [
  "face_slightly_smiling",
  "face_unamused",
  "face_content",
  "face_suspicious",
  "face_scheming",
  "face_mischievous",
  "face_furious",
  "face_smirking",
  "face_worried",
  "face_dizzy",
  "face_disappointed",
  "face_smiling_eyes",
];
// The X-eye is cut from face_dizzy's left eye: a 40 x 40 box like the open eye's.
const EYE_X_CUT = { face: "face_dizzy", x: 0, y: 19, size: 40 };

const checkOnly = process.argv.includes("--check");
const review = process.argv.includes("--review");
const BACKGROUND = [232, 138, 60];
const failures = [];
const fail = (message) => failures.push(message);

// Coverage of navy and white per pixel, 0..1, from RGBA bytes.
function planes(data, width, height, x0 = 0, y0 = 0, w = width, h = height) {
  const navy = new Float32Array(w * h);
  const white = new Float32Array(w * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const sx = x + x0;
      const sy = y + y0;
      if (sx < 0 || sy < 0 || sx >= width || sy >= height) continue;
      const i = (sy * width + sx) * 4;
      const alpha = data[i + 3] / 255;
      const t = Math.min(1, Math.max(0, (data[i] - NAVY[0]) / (255 - NAVY[0])));
      white[y * w + x] = alpha * t;
      navy[y * w + x] = alpha * (1 - t);
    }
  }
  return { w, h, navy, white };
}

// Pixels of either image that are at least half one colour with no pixel of that colour
// within one pixel in the other image, where a pixel at least a quarter covered by the colour
// counts: an edge of that colour reaches into it. "Within one source pixel" means none.
function farPixels(a, b, columns = a.w) {
  const near = (p, x, y, plane) => {
    for (let dy = -1; dy <= 1; dy++) {
      for (let dx = -1; dx <= 1; dx++) {
        const X = x + dx;
        const Y = y + dy;
        if (X >= 0 && Y >= 0 && X < p.w && Y < p.h && p[plane][Y * p.w + X] >= 0.25) return true;
      }
    }
    return false;
  };
  const far = [];
  for (let y = 0; y < a.h; y++) {
    for (let x = 0; x < columns; x++) {
      const i = y * a.w + x;
      for (const plane of ["navy", "white"]) {
        if (a[plane][i] >= 0.5 && !near(b, x, y, plane)) far.push([x, y]);
        if (b[plane][i] >= 0.5 && !near(a, x, y, plane)) far.push([x, y]);
      }
    }
  }
  return far;
}

// The largest coverage difference over all pixels, for the record.
function largestDifference(a, b) {
  let largest = 0;
  for (let i = 0; i < a.navy.length; i++) {
    const d = Math.abs(a.navy[i] - b.navy[i]) + Math.abs(a.white[i] - b.white[i]);
    largest = Math.max(largest, d);
  }
  return Math.round(largest * 1000) / 1000;
}

// At 8x, every partially covered or blended pixel touches clear space or a solid palette
// colour. A blurred edge would be a wider band. Coloured accents have their own palettes.
function soft(png, palette) {
  const { width, height, data } = png;
  const at = (x, y) => {
    const i = (y * width + x) * 4;
    const alpha = data[i + 3] / 255;
    return { alpha, rgb: [data[i], data[i + 1], data[i + 2]] };
  };
  const solid = ({ alpha, rgb }) => alpha <= 0.05 || (
    alpha >= 0.95 && palette.some((colour) =>
      colour.every((channel, index) => Math.abs(channel - rgb[index]) <= 255 * 0.05),
    )
  );
  let count = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (solid(at(x, y))) continue;
      let touches = false;
      for (let dy = -1; dy <= 1 && !touches; dy++) {
        for (let dx = -1; dx <= 1 && !touches; dx++) {
          const X = x + dx;
          const Y = y + dy;
          if (X >= 0 && Y >= 0 && X < width && Y < height) touches = solid(at(X, Y));
        }
      }
      if (!touches) count++;
    }
  }
  return count;
}

function svgSize(svg) {
  const width = Number(/<svg[^>]*\swidth="([\d.]+)"/.exec(svg)[1]);
  const height = Number(/<svg[^>]*\sheight="([\d.]+)"/.exec(svg)[1]);
  return [width, height];
}

const sha256 = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");
const readPng = (path) => PNG.sync.read(readFileSync(path));

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
const report = { parts: {}, faces: {}, eye_x: null };

try {
  const masters = readdirSync(VECTOR)
    .filter((f) => f.endsWith(".svg"))
    .sort();
  const sizes = {};
  for (const file of masters) {
    const name = file.replace(/\.svg$/, "");
    const svg = readFileSync(join(VECTOR, file), "utf8");
    const [w, h] = svgSize(svg);
    sizes[name] = [w, h];
    const target = join(RUNTIME, `${name}.png`);
    if (!checkOnly) {
      const scaled = svg.replace(/(<svg[^>]*\s)width="[\d.]+"(\s+)height="[\d.]+"/, (_, a, b) => {
        return `${a}width="${w * SCALE}"${b}height="${h * SCALE}"`;
      });
      await page.setViewportSize({ width: w * SCALE, height: h * SCALE });
      await page.setContent(
        `<html><body style="margin:0;background:transparent">${scaled}</body></html>`,
      );
      const clip = { x: 0, y: 0, width: w * SCALE, height: h * SCALE };
      writeFileSync(target, await page.screenshot({ clip, omitBackground: true }));
    }
    const png = readPng(target);
    if (png.width !== w * SCALE || png.height !== h * SCALE) fail(`${name}.png is not 8x`);
    const palette = PART_PALETTES[name] ?? [NAVY, WHITE];
    const softPixels = soft(png, palette);
    if (softPixels > 0) fail(`${name}.png has ${softPixels} pixels off a sharp edge`);
    report.parts[name] = {
      size: [w, h], soft_pixels: softPixels, sha256: sha256(target),
      master_sha256: sha256(join(VECTOR, file)),
    };
  }

  // Draws a list of layers, in face-height units, from the 8x PNGs at the given 1x size.
  const draw = async (layers, width, height) => {
    const images = {};
    for (const layer of layers) {
      const png = readFileSync(join(RUNTIME, `${layer.part}.png`));
      images[layer.part] = `data:image/png;base64,${png.toString("base64")}`;
    }
    return page.evaluate(
      async ({ layers, images, width, height }) => {
        const loaded = {};
        for (const [name, src] of Object.entries(images)) {
          const image = new Image();
          image.src = src;
          await image.decode();
          loaded[name] = image;
        }
        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const context = canvas.getContext("2d");
        context.imageSmoothingEnabled = true;
        context.imageSmoothingQuality = "high";
        for (const layer of layers) {
          context.save();
          context.translate(width / 2 + layer.center[0] * height, height / 2 + layer.center[1] * height);
          context.rotate((layer.rotation_degrees * Math.PI) / 180);
          context.scale(layer.mirror ? -1 : 1, 1);
          const w = layer.size[0] * height;
          const h = layer.size[1] * height;
          context.drawImage(loaded[layer.part], -w / 2, -h / 2, w, h);
          context.restore();
        }
        return Array.from(context.getImageData(0, 0, width, height).data);
      },
      { layers, images, width, height },
    );
  };

  const manifest = JSON.parse(readFileSync(MANIFEST, "utf8"));
  for (const [name, part] of Object.entries(manifest.parts)) {
    if (!sizes[name]) fail(`the manifest names ${name}, which has no master`);
    else if (part.size.join() !== sizes[name].join()) fail(`${name} size differs`);
    if (part.file !== `${name}.png`) fail(`${name} file is ${part.file}`);
  }
  for (const name of Object.keys(sizes)) {
    if (!manifest.parts[name]) fail(`${name} is missing from the manifest`);
  }

  // A part as a layer on its source's canvas: the margin falls outside it, and so does the
  // winged eye's wing beyond the source's 50 pixels.
  const onSource = (name, width, height) => {
    const [w, h] = manifest.parts[name].size;
    const padding = manifest.parts[name].padding;
    const center = [(w / 2 - padding - width / 2) / height, (h / 2 - padding - height / 2) / height];
    return { part: name, center, size: [w / height, h / height], rotation_degrees: 0, mirror: false };
  };

  // Each part alone at 1x against its source PNG.
  for (const name of Object.keys(sizes)) {
    if (name === "facial_part_eye_x") continue;
    // New SVG parts have no supplied raster reference. Sharpness and hashes still apply.
    if (!existsSync(join(here, `${name}.png`))) continue;
    const source = readPng(join(here, `${name}.png`));
    const { width, height } = source;
    const drawn = await draw([onSource(name, width, height)], width, height);
    const far = farPixels(planes(drawn, width, height), planes(source.data, width, height));
    report.parts[name].source_far_pixels = far.length;
    if (far.length > 0) fail(`${name} differs from its source at ${JSON.stringify(far)}`);
  }

  const expected = ORIGINALS;
  if (expected.some((name) => !manifest.faces[name])) {
    fail("the manifest must keep the twelve original faces");
  }
  for (const [name, face] of Object.entries(manifest.faces)) {
    const [w, h] = face.source_size;
    if (Math.abs(face.box_aspect - w / h) > 1e-4) fail(`${name} aspect is not ${w}/${h}`);
    if (!/^face_[a-z]+(?:_[a-z]+)*$/.test(name) || name.length > 64) fail(`${name} is not a face ID`);
    if (!face.layers.length || face.layers.some((layer) =>
      !manifest.parts[layer.part] ||
      [...layer.center, ...layer.size, layer.rotation_degrees].some((value) => !Number.isFinite(value)) ||
      layer.size.some((value) => value <= 0)
    )) fail(`${name} has invalid layers`);
    const drawn = await draw(face.layers, w, h);
    const reference = join(here, `${name}.png`);
    if (!face.emoji_reference) fail(`${name} has no emoji reference`);
    if (!expected.includes(name)) {
      if (!drawn.some((value, index) => index % 4 === 3 && value > 0)) fail(`${name} is empty`);
      report.faces[name] = { emoji_reference: face.emoji_reference, reference_comparison: false };
      continue;
    }
    const source = readPng(reference);
    if (source.width !== w || source.height !== h) fail(`${name} source size differs`);
    const a = planes(drawn, w, h);
    const b = planes(source.data, w, h);
    const far = farPixels(a, b);
    report.faces[name] = {
      far_pixels: far.length,
      largest_coverage_difference: largestDifference(a, b),
    };
    if (far.length > 0) fail(`${name} differs by more than one pixel at ${JSON.stringify(far)}`);
  }

  // The X-eye at 1x against both of face_dizzy's eyes; the right eye is the same part mirrored.
  const faceJ = readPng(join(here, `${EYE_X_CUT.face}.png`));
  const { x, y, size } = EYE_X_CUT;
  const eyeX = onSource("facial_part_eye_x", size, size);
  const drawnX = planes(await draw([eyeX], size, size), size, size);
  const cuts = [x, faceJ.width - x - size].map((left) => {
    const cut = planes(faceJ.data, faceJ.width, faceJ.height, left, y, size, size);
    return farPixels(drawnX, cut).length;
  });
  report.eye_x = { cut: EYE_X_CUT, far_pixels_left: cuts[0], far_pixels_right: cuts[1] };
  if (cuts.some((n) => n > 0)) fail(`the X-eye differs from face_dizzy: ${cuts}`);

  if (review) {
    // This legacy comparison sheet is only for the supplied raster references.
    const faces = Object.entries(manifest.faces).filter(([name]) => expected.includes(name));
    const ZOOM = 4;
    const GAP = 24;
    const cellW = 2 * 118 * ZOOM + 3 * GAP;
    const cellH = 84 * ZOOM + 2 * GAP;
    const pairs = new PNG({ width: 2 * cellW, height: 6 * cellH });
    const large = new PNG({ width: 4 * (118 * SCALE + GAP) + GAP, height: 3 * (84 * SCALE + GAP) + GAP });
    fill(pairs);
    fill(large);
    for (const [index, [name, face]] of faces.entries()) {
      const [w, h] = face.source_size;
      const source = readPng(join(here, `${name}.png`));
      const drawn = await draw(face.layers, w, h);
      const x = (index % 2) * cellW + GAP;
      const y = Math.floor(index / 2) * cellH + GAP;
      paste(pairs, source.data, w, h, x, y, ZOOM);
      paste(pairs, drawn, w, h, x + w * ZOOM + GAP, y, ZOOM);
      const eight = await draw(face.layers, w * SCALE, h * SCALE);
      const lx = (index % 4) * (118 * SCALE + GAP) + GAP;
      const ly = Math.floor(index / 4) * (84 * SCALE + GAP) + GAP;
      paste(large, eight, w * SCALE, h * SCALE, lx, ly, 1);
    }
    const folder = join(here, "scratch", "review");
    mkdirSync(folder, { recursive: true });
    writeFileSync(join(folder, "faces-1x-reference-and-preset.png"), PNG.sync.write(pairs));
    writeFileSync(join(folder, "faces-8x.png"), PNG.sync.write(large));
  }
} finally {
  await browser.close();
}

function fill(png) {
  for (let i = 0; i < png.data.length; i += 4) {
    png.data.set([...BACKGROUND, 255], i);
  }
}

// Draws RGBA pixels over a sheet at an integer zoom, without smoothing.
function paste(sheet, data, w, h, x0, y0, zoom) {
  for (let y = 0; y < h * zoom; y++) {
    for (let x = 0; x < w * zoom; x++) {
      const s = (Math.floor(y / zoom) * w + Math.floor(x / zoom)) * 4;
      const d = ((y0 + y) * sheet.width + x0 + x) * 4;
      const a = data[s + 3] / 255;
      for (let c = 0; c < 3; c++) {
        sheet.data[d + c] = Math.round(data[s + c] * a + sheet.data[d + c] * (1 - a));
      }
    }
  }
}

report.manifest_sha256 = sha256(MANIFEST);
report.result = failures.length ? "FAIL" : "PASS";
report.failures = failures;
writeFileSync(join(VECTOR, "verification.json"), JSON.stringify(report, null, 2) + "\n");
for (const failure of failures) console.error(failure);
console.log(`face parts: ${report.result}`);
process.exit(failures.length ? 1 : 0);
