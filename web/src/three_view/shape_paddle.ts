import {
  BufferGeometry,
  DoubleSide,
  Float32BufferAttribute,
  Group,
  Mesh,
  MeshBasicMaterial,
  MeshStandardMaterial,
  PlaneGeometry,
  SRGBColorSpace,
  TextureLoader,
  type Texture,
} from "three";
import { roundedOutline, CORNER_SEGMENTS } from "../shape_paddle/rounded_bar.js";
import { FACE_BASE, type FaceLayer, type FaceManifest } from "../shape_paddle/face.js";
import type { PaddleShape } from "../shape_paddle/paddle.js";

/** The bar's mesh, as the host builds it: flat faces front and back, a wall that follows it. */
export function roundedBarGeometry(
  length: number,
  thickness: number,
  depth: number,
  radius: number,
  segments = CORNER_SEGMENTS,
): BufferGeometry {
  const points = roundedOutline(length, thickness, radius, segments);
  const front = depth / 2;
  const vertices: number[] = [];
  const normals: number[] = [];
  const indices: number[] = [];
  // three.js treats counter-clockwise triangles, seen from outside, as front faces.
  for (const side of [front, -front]) {
    const centre = vertices.length / 3;
    vertices.push(0, 0, side);
    normals.push(0, 0, Math.sign(side));
    for (const [x, y] of points) {
      vertices.push(x, y, side);
      normals.push(0, 0, Math.sign(side));
    }
    points.forEach((_, index) => {
      const next = (index + 1) % points.length;
      if (side > 0) indices.push(centre, centre + 1 + index, centre + 1 + next);
      else indices.push(centre, centre + 1 + next, centre + 1 + index);
    });
  }
  const half = [length / 2, thickness / 2];
  const corner = Math.min(Math.max(radius, 0), half[0], half[1]);
  const inner = [half[0] - corner, half[1] - corner];
  points.forEach((a, index) => {
    const b = points[(index + 1) % points.length];
    const base = vertices.length / 3;
    const edge = [b[1] - a[1], a[0] - b[0]];
    const edgeLength = Math.hypot(edge[0], edge[1]) || 1;
    for (const [x, y] of [a, b]) {
      // On a corner arc the normal points away from the arc's centre.
      const away = [
        x - Math.min(inner[0], Math.max(-inner[0], x)),
        y - Math.min(inner[1], Math.max(-inner[1], y)),
      ];
      const reach = Math.hypot(away[0], away[1]);
      const normal =
        corner > 0 && reach >= corner / 2
          ? [away[0] / reach, away[1] / reach]
          : [edge[0] / edgeLength, edge[1] / edgeLength];
      vertices.push(x, y, front, x, y, -front);
      normals.push(normal[0], normal[1], 0, normal[0], normal[1], 0);
    }
    indices.push(base, base + 1, base + 2, base + 2, base + 1, base + 3);
  });
  const geometry = new BufferGeometry();
  geometry.setAttribute("position", new Float32BufferAttribute(vertices, 3));
  geometry.setAttribute("normal", new Float32BufferAttribute(normals, 3));
  geometry.setIndex(indices);
  return geometry;
}

const textures = new Map<string, Promise<Texture>>();
const loader = new TextureLoader();

function partTexture(manifest: FaceManifest, part: string, base: string): Promise<Texture> {
  let texture = textures.get(part);
  if (!texture) {
    texture = loader.loadAsync(base + manifest.parts[part].file).then((loaded) => {
      loaded.colorSpace = SRGBColorSpace;
      return loaded;
    });
    texture.catch(() => textures.delete(part));
    textures.set(part, texture);
  }
  return texture;
}

/**
 * A shape paddle in 3D: the outline and gap rings, the body and a face of flat parts on its
 * front. One unit of its measurements is one world unit.
 */
export class ShapePaddle3D {
  readonly root = new Group();
  private readonly body = new MeshStandardMaterial({ roughness: 0.65 });
  private readonly gap = new MeshStandardMaterial({ roughness: 0.8 });
  private readonly outline = new MeshStandardMaterial({ roughness: 0.7 });
  private readonly face = new Group();
  private readonly plane = new PlaneGeometry(1, 1);
  private readonly materials = new Map<string, MeshBasicMaterial>();
  private meshes: Mesh[] = [];
  private shapeKey = "";
  private faceKey = "";

  constructor(
    private readonly manifest: FaceManifest,
    private readonly base = FACE_BASE,
  ) {
    this.root.add(this.face);
  }

  /** Rebuilds the meshes when the size or look changes, and repaints. */
  update(shape: PaddleShape, layers: FaceLayer[]): void {
    const { length, thickness, look } = shape;
    const key = JSON.stringify([length, thickness, look]);
    if (key !== this.shapeKey) {
      this.shapeKey = key;
      for (const mesh of this.meshes) {
        this.root.remove(mesh);
        mesh.geometry.dispose();
      }
      const radius = thickness * look.corner_ratio;
      const depth = thickness * look.depth_ratio;
      const gap = thickness * look.gap_ratio;
      const reach = gap + thickness * look.outline_ratio;
      this.meshes = [
        new Mesh(
          roundedBarGeometry(
            length + reach * 2,
            thickness + reach * 2,
            depth * 0.88,
            radius + reach,
          ),
          this.outline,
        ),
        new Mesh(
          roundedBarGeometry(length + gap * 2, thickness + gap * 2, depth * 0.94, radius + gap),
          this.gap,
        ),
        new Mesh(roundedBarGeometry(length, thickness, depth, radius), this.body),
      ];
      this.root.add(...this.meshes);
      this.face.position.z = depth / 2 + 0.004 * thickness;
    }
    this.body.color.set(`#${shape.body}`);
    this.gap.color.set(`#${look.gap_color}`);
    this.outline.color.set(`#${shape.outline}`);
    this.setFace(layers, thickness * look.face_ratio);
  }

  private setFace(layers: FaceLayer[], height: number): void {
    const key = JSON.stringify([layers, height]);
    if (key === this.faceKey) return;
    this.faceKey = key;
    this.face.clear();
    layers.forEach((layer, index) => {
      const mesh = new Mesh(this.plane, this.material(layer.part));
      mesh.scale.set(layer.size[0] * height * (layer.mirror ? -1 : 1), layer.size[1] * height, 1);
      mesh.position.set(layer.center[0] * height, -layer.center[1] * height, index * 0.0015);
      // The manifest turns clockwise on screen, a negative turn about +Z.
      mesh.rotation.z = (-layer.rotation_degrees * Math.PI) / 180;
      mesh.renderOrder = 10 + index;
      this.face.add(mesh);
    });
  }

  private material(part: string): MeshBasicMaterial {
    let material = this.materials.get(part);
    if (!material) {
      material = new MeshBasicMaterial({ transparent: true, depthWrite: false, side: DoubleSide });
      const created = material;
      void partTexture(this.manifest, part, this.base).then((texture) => {
        created.map = texture;
        created.needsUpdate = true;
      });
      this.materials.set(part, material);
    }
    return material;
  }

  dispose(): void {
    for (const mesh of this.meshes) mesh.geometry.dispose();
    this.plane.dispose();
    for (const material of [this.body, this.gap, this.outline, ...this.materials.values()])
      material.dispose();
  }
}
