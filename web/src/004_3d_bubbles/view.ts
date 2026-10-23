import {
  Group,
  HemisphereLight,
  DirectionalLight,
  Mesh,
  MeshBasicMaterial,
  SphereGeometry,
  Vector2,
} from "three";
import { Viewport } from "../three_view/viewport.js";
import { createCubio } from "../three_view/cubio.js";
import { createBubbleShell } from "../three_view/bubble_shell.js";
import { modelInstance } from "../three_view/assets.js";
import type { Frame, Presentation } from "./types.js";

export async function createBubbleView(canvas: HTMLCanvasElement): Promise<Presentation> {
  let frame: Frame | undefined;
  let radius = 0;
  let zoomRadius = 0;
  const stretch = new Vector2();
  const velocity = new Vector2();
  const shell = createBubbleShell();
  const character = new Group();
  const caught = new Group();
  const droplets = new Group();
  const dropletGeometry = new SphereGeometry(1, 6, 4);
  const dropletMaterial = new MeshBasicMaterial({ color: 0xc5f8ff, transparent: true });
  for (let index = 0; index < 24; index++) droplets.add(new Mesh(dropletGeometry, dropletMaterial));
  let cubio: Awaited<ReturnType<typeof createCubio>> | undefined;
  let jellyfish: Awaited<ReturnType<typeof modelInstance>> | undefined;
  let viewport: Viewport | undefined;
  const dispose = (): void => {
    viewport?.dispose();
    cubio?.dispose();
    shell.dispose();
    dropletGeometry.dispose();
    dropletMaterial.dispose();
  };
  try {
    viewport = new Viewport(canvas, (delta, seconds) => {
      if (!frame || !viewport || !cubio) return;

      const { snapshot, visual } = frame;
      const tuning = snapshot.visual_tuning;
      const amount = 1 - Math.exp(-delta / 0.085);
      radius += (visual.radius - radius) * amount;
      stretch.lerp(new Vector2(...visual.stretch), amount);
      velocity.lerp(new Vector2(...visual.velocity), amount);
      shell.update(radius, stretch.x, stretch.y, seconds);
      const targetZoom = Math.max(snapshot.bubble_radius, radius, tuning.starting_radius);
      // Expanding framing leads shell growth so a fast catch never clips its rim.
      zoomRadius = Math.max(radius, zoomRadius + (targetZoom - zoomRadius) * amount);
      const aspect = Math.min(1, viewport.camera.aspect);
      const halfFov = (viewport.camera.fov * Math.PI) / 360;
      const distance = (zoomRadius * 1.65) / (Math.sin(halfFov) * aspect);
      viewport.camera.position.set(0, 0, Math.max(1, distance));
      const height = Math.min(
        tuning.character_max_height,
        snapshot.bubble_radius * tuning.character_height_per_radius,
      );
      character.position.y = -height / 2 + Math.sin(seconds * 2.2) * tuning.character_bob;
      character.rotation.z =
        (-Math.max(-1, Math.min(1, velocity.x)) * tuning.character_lean_degrees * Math.PI) / 180;
      const white = visual.white && Math.floor(visual.host_time_msec / 100) % 2 === 0;
      cubio.update(delta, height, snapshot.character_color, white);
      const count = Math.min(tuning.visual_cap, Math.max(0, visual.caught));
      while (caught.children.length < count && jellyfish) {
        const instance = jellyfish.scene.clone(true);
        instance.rotation.y = Math.PI;
        caught.add(instance);
      }
      caught.children.forEach((object, index) => {
        object.visible = index < count;
        const angle = seconds * 0.18 + (index * Math.PI * 2) / Math.max(1, count);
        const orbit = radius * (0.6 + (0.17 * (index % 3)) / 2);
        object.position.set(Math.cos(angle) * orbit, Math.sin(angle) * orbit, -0.05);
        // As on the shared screen, small bubbles shrink their catch so it stays inside.
        object.scale.setScalar(Math.min(tuning.caught_width, radius * 0.42) / 0.55);
      });
      const popAge = visual.pop_age_msec / 1000;
      const burst = Math.max(0.01, tuning.burst_seconds);
      droplets.visible = popAge >= 0 && popAge < burst;
      if (droplets.visible) {
        const progress = popAge / burst;
        dropletMaterial.opacity = 1 - progress;
        droplets.children.forEach((object, index) => {
          const angle = (index * Math.PI * 2) / droplets.children.length;
          const reach = snapshot.bubble_radius * (1 + progress * 0.65);
          object.position.set(Math.cos(angle) * reach, Math.sin(angle) * reach, 0.1);
          object.scale.setScalar(snapshot.bubble_radius * 0.045 * (1 - progress));
        });
      }
    });
    cubio = await createCubio();
    jellyfish = await modelInstance("/models/jellyfish.glb");
    character.add(cubio.root);
    viewport.scene.add(shell.mesh, character, caught, droplets);
    viewport.scene.add(new HemisphereLight(0xe2faff, 0x3b6586, 2.4));
    const light = new DirectionalLight(0xffffff, 2.2);
    light.position.set(-3, 5, 6);
    viewport.scene.add(light);
  } catch (error) {
    dispose();
    throw error;
  }
  return {
    update(next: Frame): void {
      if (!frame) radius = zoomRadius = next.visual.radius;
      frame = next;
    },
    dispose,
  };
}
