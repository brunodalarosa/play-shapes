import { AnimationMixer, Color, Group, Mesh, MeshStandardMaterial } from "three";
import { Blinker, faceLayers, loadManifest, type FaceManifest } from "../shape_paddle/face.js";
import { modelInstance } from "./assets.js";
import { ShapeFace3D } from "./shape_face.js";

const TINTED = ["Body", "HandL", "HandR", "FootL", "FootR"];
/** The face a Cubio shows, as on the host. */
const FACE = "face_neutral";

/** Where the face sits on the model's FaceAnchor, in source units, X right and Y up. */
export interface FaceAnchor {
  offset: [number, number];
  height: number;
}

export function validAnchor(value: unknown): value is FaceAnchor {
  const anchor = value as FaceAnchor;
  return (
    !!anchor &&
    Array.isArray(anchor.offset) &&
    anchor.offset.length === 2 &&
    anchor.offset.every(Number.isFinite) &&
    Number.isFinite(anchor.height) &&
    anchor.height > 0
  );
}

async function loadAnchor(): Promise<FaceAnchor> {
  const response = await fetch("/models/cubio-face-anchor.json");
  if (!response.ok) throw new Error("Cubio's face placement could not load");
  const anchor: unknown = await response.json();
  if (!validAnchor(anchor)) throw new Error("Cubio's face placement is malformed");
  return anchor;
}

let faceData: Promise<[FaceManifest, FaceAnchor]> | undefined;

/** The face manifest and Cubio's placement, fetched once and again after a failure. */
function loadFaceData(): Promise<[FaceManifest, FaceAnchor]> {
  faceData ??= Promise.all([loadManifest(), loadAnchor()]).catch((error: unknown) => {
    faceData = undefined;
    throw error;
  });
  return faceData;
}

export async function createCubio() {
  const [model, [manifest, anchor]] = await Promise.all([
    modelInstance("/models/cubio.glb"),
    loadFaceData(),
  ]);
  const root = new Group();
  root.add(model.scene);
  const tint = new MeshStandardMaterial({ roughness: 0.32, metalness: 0 });
  model.scene.traverse((object) => {
    if (!(object instanceof Mesh)) return;

    const name = object.name.replace(/_\d+$/, "");
    if (TINTED.includes(name)) object.material = tint;
    if (name === "Face") object.visible = false;
  });
  const face = new ShapeFace3D(manifest);
  // The anchor faces out of the body's front, toward the phone camera.
  model.scene.getObjectByName("FaceAnchor")?.add(face.root);
  face.root.position.set(anchor.offset[0], anchor.offset[1], 0);
  const mixer = new AnimationMixer(model.scene);
  const idle = model.animations.find((clip) => clip.name === "idle");
  if (idle) mixer.clipAction(idle).play();
  const blinker = new Blinker();
  let seconds = 0;
  const color = new Color();
  return {
    root,
    face,
    update(delta: number, height: number, playerColor: string, white: boolean): void {
      mixer.update(delta);
      seconds += delta;
      root.scale.setScalar(height / 2.62);
      color.set(playerColor);
      tint.color.copy(white ? color.set(0xffffff) : color);
      face.set(faceLayers(manifest, FACE, blinker.closed(seconds)), anchor.height);
    },
    dispose(): void {
      mixer.stopAllAction();
      mixer.uncacheRoot(model.scene);
      tint.dispose();
      face.dispose();
    },
  };
}
