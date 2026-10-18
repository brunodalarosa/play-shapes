import {
  AnimationMixer,
  Color,
  DoubleSide,
  Group,
  Mesh,
  MeshBasicMaterial,
  MeshStandardMaterial,
} from "three";
import { loadFace, modelInstance } from "./assets.js";

const TINTED = ["Body", "HandL", "HandR", "FootL", "FootR"];

export async function createSquircle() {
  const [model, neutral, blink] = await Promise.all([
    modelInstance("/models/squircle.glb"),
    loadFace("/models/squircle-face-neutral.png"),
    loadFace("/models/squircle-face-blink.png"),
  ]);
  const root = new Group();
  // The face's parent transform puts it on +Z, toward the phone camera.
  root.add(model.scene);
  const tint = new MeshStandardMaterial({ roughness: 0.32, metalness: 0 });
  const face = new MeshBasicMaterial({ map: neutral, alphaTest: 0.5, side: DoubleSide });
  model.scene.traverse((object) => {
    if (!(object instanceof Mesh)) return;

    const name = object.name.replace(/_\d+$/, "");
    if (TINTED.includes(name)) object.material = tint;
    if (name === "Face") object.material = face;
  });
  const mixer = new AnimationMixer(model.scene);
  const idle = model.animations.find((clip) => clip.name === "idle");
  if (idle) mixer.clipAction(idle).play();
  let wait = 2.4 + Math.random() * 3.2;
  let blinkLeft = 0;
  const color = new Color();
  return {
    root,
    update(delta: number, height: number, playerColor: string, white: boolean): void {
      mixer.update(delta);
      root.scale.setScalar(height / 2.62);
      color.set(playerColor);
      tint.color.copy(white ? color.set(0xffffff) : color);
      if (blinkLeft > 0) {
        blinkLeft -= delta;
        if (blinkLeft <= 0) wait = 2.4 + Math.random() * 3.2;
      } else {
        wait -= delta;
        if (wait <= 0) blinkLeft = 0.12;
      }
      face.map = blinkLeft > 0 ? blink : neutral;
    },
    dispose(): void {
      mixer.stopAllAction();
      mixer.uncacheRoot(model.scene);
      tint.dispose();
      face.dispose();
    },
  };
}
