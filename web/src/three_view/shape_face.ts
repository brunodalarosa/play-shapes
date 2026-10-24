import {
  DoubleSide,
  Group,
  Mesh,
  MeshBasicMaterial,
  PlaneGeometry,
  SRGBColorSpace,
  TextureLoader,
  type Texture,
} from "three";
import { FACE_BASE, type FaceLayer, type FaceManifest } from "../shape_paddle/face.js";

const textures = new Map<string, Promise<Texture>>();
const loader = new TextureLoader();
/** Loads finish one at a time, so many phones starting together stay within the host's limit. */
let queue: Promise<unknown> = Promise.resolve();
const RETRY_MSEC = 1000;

function partTexture(manifest: FaceManifest, part: string, base: string): Promise<Texture> {
  let texture = textures.get(part);
  if (!texture) {
    const url = base + manifest.parts[part].file;
    const load = (): Promise<Texture> => loader.loadAsync(url);
    texture = queue
      .then(load)
      .catch(() => new Promise<void>((done) => setTimeout(done, RETRY_MSEC)).then(load))
      .then((loaded) => {
        loaded.colorSpace = SRGBColorSpace;
        return loaded;
      });
    queue = texture.catch(() => undefined);
    textures.set(part, texture);
  }
  return texture;
}

/**
 * A shape face in 3D, as the host draws it: one flat part per layer facing +Z, centred on
 * [root], later layers in front.
 */
export class ShapeFace3D {
  readonly root = new Group();
  private readonly plane = new PlaneGeometry(1, 1);
  private readonly materials = new Map<string, MeshBasicMaterial>();
  private key = "";
  private pending = 0;
  private arrived = false;

  constructor(
    private readonly manifest: FaceManifest,
    private readonly base = FACE_BASE,
  ) {}

  /** Draws [layers] in a face box [height] world units tall, rebuilding only on a change. */
  set(layers: FaceLayer[], height: number): void {
    const key = JSON.stringify([layers, height]);
    if (key === this.key) return;
    this.key = key;
    this.root.clear();
    layers.forEach((layer, index) => {
      const mesh = new Mesh(this.plane, this.material(layer.part));
      mesh.scale.set(layer.size[0] * height * (layer.mirror ? -1 : 1), layer.size[1] * height, 1);
      mesh.position.set(layer.center[0] * height, -layer.center[1] * height, index * 0.0015);
      // The manifest turns clockwise on screen, a negative turn about +Z.
      mesh.rotation.z = (-layer.rotation_degrees * Math.PI) / 180;
      mesh.renderOrder = 10 + index;
      this.root.add(mesh);
    });
  }

  /** True while a face part is still loading, or just arrived and is not yet drawn. */
  loading(): boolean {
    const waiting = this.pending > 0 || this.arrived;
    this.arrived = this.pending > 0;
    return waiting;
  }

  dispose(): void {
    this.plane.dispose();
    for (const material of this.materials.values()) material.dispose();
  }

  private material(part: string): MeshBasicMaterial {
    let material = this.materials.get(part);
    if (!material) {
      // Hidden until its image arrives; without one it would draw as a white block.
      material = new MeshBasicMaterial({
        transparent: true,
        depthWrite: false,
        side: DoubleSide,
        visible: false,
      });
      const created = material;
      this.pending++;
      partTexture(this.manifest, part, this.base)
        .then(
          (texture) => {
            created.map = texture;
            created.visible = true;
            created.needsUpdate = true;
          },
          () => textures.delete(part),
        )
        .finally(() => this.pending--);
      this.materials.set(part, material);
    }
    return material;
  }
}
