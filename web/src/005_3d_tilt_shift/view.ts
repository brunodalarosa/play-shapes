import { DirectionalLight, HemisphereLight } from "three";
import { Viewport } from "../three_view/viewport.js";
import { ShapePaddle3D } from "../three_view/shape_paddle.js";
import { Blinker, faceLayers, type FaceManifest } from "../shape_paddle/face.js";
import type { Frame, Presentation } from "./types.js";

/** Seconds for the drawn angle to close most of the gap to the host's, between snapshots. */
const ANGLE_SMOOTHING = 0.04;
/** Share of the screen's shorter side the turning paddle's length takes. */
const PLAY_FIT = 0.82;
const RESTING_FIT = 0.6;

/** The player's own paddle in real-time 3D, through the same narrow camera as the host's. */
export async function createTiltPaddleView(
  canvas: HTMLCanvasElement,
  manifest: FaceManifest,
): Promise<Presentation> {
  let frame: Frame | undefined;
  let angle = 0;
  // The picture changes only while the paddle turns, its face or size changes, or it blinks.
  let drawn = "";
  let picture = "";
  const blinker = new Blinker();
  const paddle = new ShapePaddle3D(manifest);
  const viewport = new Viewport(
    canvas,
    (delta, seconds) => {
      if (!frame) return;

      angle += (frame.angle - angle) * (1 - Math.exp(-delta / ANGLE_SMOOTHING));
      if (Math.abs(frame.angle - angle) < 0.0005) angle = frame.angle;
      const blinking = blinker.closed(seconds);
      paddle.update(frame.shape, faceLayers(manifest, frame.face, blinking));
      // Positive angles turn clockwise on screen, a negative turn about +Z.
      paddle.root.rotation.z = -angle;
      const fit = frame.shape.length / (frame.resting ? RESTING_FIT : PLAY_FIT);
      const camera = viewport.camera;
      const height = camera.aspect >= 1 ? fit : fit / camera.aspect;
      const distance = height / 2 / Math.tan((camera.fov * Math.PI) / 360);
      camera.position.set(0, 0, distance);
      camera.lookAt(0, 0, 0);
      camera.near = distance / 20;
      camera.far = distance * 4;
      camera.updateProjectionMatrix();
      picture = JSON.stringify([angle, frame.face, blinking, frame.shape, frame.resting]);
    },
    () => {
      const changed = picture !== drawn || paddle.loading();
      drawn = picture;
      return changed;
    },
  );
  viewport.scene.add(paddle.root);
  viewport.scene.add(new HemisphereLight(0xfff8ee, 0xd9c7a6, 2.0));
  const light = new DirectionalLight(0xffffff, 1.6);
  light.position.set(-3, 5, 8);
  viewport.scene.add(light);
  return {
    update(next: Frame): void {
      if (!frame) angle = next.angle;
      frame = next;
    },
    dispose(): void {
      viewport.dispose();
      paddle.dispose();
    },
  };
}
