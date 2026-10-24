// The shared shape character face for the phone: the host's part manifest, the presets it
// composes, natural blinks, and a flat drawing for screens without WebGL. The 3D drawing in
// three_view builds on the same layers.

export const FACE_BASE = "/shape_faces/";
const BLINK_EYE = "facial_part_eye_closed_down";
const UNBLINKING_EYES = [
  "facial_part_eye_closed_down",
  "facial_part_eye_closed_up",
  "facial_part_eye_x",
  "facial_part_eye_squeezed",
  "facial_part_eye_soft_closed_up",
  "facial_part_eye_soft_closed_down",
  "facial_part_eye_spiral",
  "facial_part_eye_heart",
  "facial_part_eye_star",
  "facial_part_eye_money",
];
const EYE_PREFIX = "facial_part_eye_";

export interface FaceLayer {
  part: string;
  /** Centre from the face box's centre, in face heights, X right and Y down. */
  center: [number, number];
  /** Drawn size in face heights. */
  size: [number, number];
  /** Clockwise turn about the centre. */
  rotation_degrees: number;
  /** Flipped horizontally about its centre before it turns. */
  mirror: boolean;
}

export interface FacePreset {
  source_size: [number, number];
  box_aspect: number;
  layers: FaceLayer[];
}

export interface FaceManifest {
  export_scale: number;
  parts: Record<string, { file: string; size: [number, number]; padding: number }>;
  faces: Record<string, FacePreset>;
}

export function validManifest(value: unknown): value is FaceManifest {
  if (!value || typeof value !== "object") return false;
  const manifest = value as FaceManifest;
  return (
    !!manifest.parts &&
    typeof manifest.parts === "object" &&
    !!manifest.faces &&
    typeof manifest.faces === "object" &&
    Object.values(manifest.faces).every(
      (face) =>
        Number.isFinite(face.box_aspect) &&
        Array.isArray(face.layers) &&
        face.layers.every(
          (layer) => typeof layer.part === "string" && layer.part in manifest.parts,
        ),
    )
  );
}

export async function loadManifest(base = FACE_BASE): Promise<FaceManifest> {
  const response = await fetch(base + "face_presets.json");
  if (!response.ok) throw new Error("The face presets could not load");
  const manifest: unknown = await response.json();
  if (!validManifest(manifest)) throw new Error("The face presets are not a face manifest");
  return manifest;
}

/** True for an eye part that a blink may close. */
export function canClose(part: string): boolean {
  return part.startsWith(EYE_PREFIX) && !UNBLINKING_EYES.includes(part);
}

/** The layers of [name], with open eyes closed when [blinking]; an unknown face has none. */
export function faceLayers(manifest: FaceManifest, name: string, blinking: boolean): FaceLayer[] {
  const face = manifest.faces[name];
  if (!face) return [];
  if (!blinking) return face.layers;
  const closed = manifest.parts[BLINK_EYE].size;
  const height = face.source_size[1];
  return face.layers.map((layer) =>
    canClose(layer.part)
      ? {
          ...layer,
          part: BLINK_EYE,
          size: [closed[0] / height, closed[1] / height],
          rotation_degrees: 0,
        }
      : layer,
  );
}

/** Natural blinks: the eyes close for [closedSeconds] at random gaps within [gaps]. */
export class Blinker {
  private next = -1;

  constructor(
    private readonly gaps: [number, number] = [2.4, 5.6],
    private readonly closedSeconds = 0.12,
    private readonly random: () => number = Math.random,
  ) {}

  /** True while a blink closes the eyes at [seconds]; calls must move forward in time. */
  closed(seconds: number): boolean {
    if (this.next < 0) this.next = seconds + this.gap();
    while (seconds >= this.next + this.closedSeconds) this.next += this.closedSeconds + this.gap();
    return seconds >= this.next;
  }

  private gap(): number {
    const [shortest, longest] = this.gaps;
    return shortest + (Math.max(shortest, longest) - shortest) * this.random();
  }
}

/** Part images, loaded once each. */
export class FaceImages {
  private readonly images = new Map<string, HTMLImageElement>();

  constructor(
    private readonly manifest: FaceManifest,
    private readonly base = FACE_BASE,
    private readonly loaded: () => void = () => {},
  ) {}

  image(part: string): HTMLImageElement | undefined {
    const entry = this.manifest.parts[part];
    if (!entry) return undefined;
    let image = this.images.get(part);
    if (!image) {
      image = new Image();
      image.addEventListener("load", this.loaded);
      image.src = this.base + entry.file;
      this.images.set(part, image);
    }
    return image;
  }
}

/** Draws [layers] centred on the context's origin, [height] pixels tall. */
export function drawFace(
  context: CanvasRenderingContext2D,
  images: FaceImages,
  layers: FaceLayer[],
  height: number,
): void {
  for (const layer of layers) {
    const image = images.image(layer.part);
    if (!image?.complete || !image.naturalWidth) continue;
    const width = layer.size[0] * height;
    const tall = layer.size[1] * height;
    context.save();
    context.translate(layer.center[0] * height, layer.center[1] * height);
    context.rotate((layer.rotation_degrees * Math.PI) / 180);
    if (layer.mirror) context.scale(-1, 1);
    context.drawImage(image, -width / 2, -tall / 2, width, tall);
    context.restore();
  }
}
