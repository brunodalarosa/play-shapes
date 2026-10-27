import {
  BoxGeometry,
  CylinderGeometry,
  DirectionalLight,
  Group,
  HemisphereLight,
  Mesh,
  MeshStandardMaterial,
} from "three";
import { createCubio } from "../three_view/cubio.js";
import { Viewport } from "../three_view/viewport.js";
import { courseWindow, toCanvas } from "./framing.js";
import type { Frame, Presentation, ViewSetup } from "./types.js";

/** How far the hanging stone reaches above its gap, so flying high never shows its end. */
const HANGING_REACH = 400;
const DEPTH = 6;
/** Cubio's body centre above its soles, at the source standing height of 2.62 m. */
const BODY_CENTRE = 1.62;
const CUBIO_HEIGHT = 2.62;

/**
 * The phone's 3D race: its own Cubio, the course and the pickups it has not taken. The course
 * is placeholder stone until the cave models land. The picture is drawn when the phone draws a
 * frame, so a tap shows in the frame that follows it.
 */
export async function createFlappyRaceView(
  canvas: HTMLCanvasElement,
  setup: ViewSetup,
): Promise<Presentation> {
  const { course } = setup;
  const stone = new MeshStandardMaterial({ color: 0xd6a86c, flatShading: true, roughness: 0.9 });
  const floor = new MeshStandardMaterial({ color: 0xb98a55, flatShading: true, roughness: 1 });
  const gold = new MeshStandardMaterial({ color: 0xf2c230, metalness: 0.35, roughness: 0.3 });
  const finish = new MeshStandardMaterial({ color: 0xfff3cb, roughness: 0.8 });
  const unit = new BoxGeometry(1, 1, 1);
  const coin = new CylinderGeometry(0.5, 0.5, 0.18, 20);
  coin.rotateX(Math.PI / 2);
  const world = new Group();
  const pickups: Mesh[] = [];
  let cubio: Awaited<ReturnType<typeof createCubio>> | undefined;
  const viewport = new Viewport(
    canvas,
    () => {},
    () => false,
  );
  const dispose = (): void => {
    viewport.dispose();
    cubio?.dispose();
    for (const resource of [stone, floor, gold, finish, unit, coin]) resource.dispose();
  };

  const block = (
    material: MeshStandardMaterial,
    x0: number,
    x1: number,
    y0: number,
    y1: number,
  ) => {
    const mesh = new Mesh(unit, material);
    mesh.scale.set(x1 - x0, y1 - y0, DEPTH);
    mesh.position.set((x0 + x1) / 2, (y0 + y1) / 2, 0);
    world.add(mesh);
  };
  try {
    const flight = course.flight;
    block(floor, flight.start_x - 60, flight.finish_x + 60, -8, 0);
    block(finish, flight.finish_x - 0.25, flight.finish_x + 0.25, 0, course.view_height);
    for (const obstacle of flight.obstacles) {
      block(stone, obstacle.x_start, obstacle.x_end, -1, obstacle.gap_bottom);
      block(
        stone,
        obstacle.x_start,
        obstacle.x_end,
        obstacle.gap_top,
        obstacle.gap_top + HANGING_REACH,
      );
    }
    for (const pickup of flight.pickups) {
      const mesh = new Mesh(coin, gold);
      mesh.scale.setScalar(pickup.half_size * 2);
      mesh.position.set(pickup.x, pickup.y, 0.5);
      pickups.push(mesh);
      world.add(mesh);
    }
    cubio = await createCubio();
    world.add(cubio.root);
    viewport.scene.add(world, new HemisphereLight(0xfff4dc, 0x7a5f8c, 2.2));
    const light = new DirectionalLight(0xffffff, 2);
    light.position.set(-4, 8, 10);
    viewport.scene.add(light);
  } catch (error) {
    dispose();
    throw error;
  }

  let spin = 0;
  let focus = course.flight.start_x;
  const window = (focusX: number) =>
    courseWindow(course.view_height, viewport.camera.aspect, focusX, setup.focusShare);
  return {
    draw(frame: Frame): void {
      if (!cubio) return;

      focus = frame.focusX;
      const shown = window(focus);
      const halfFov = (viewport.camera.fov * Math.PI) / 360;
      const distance = shown.height / 2 / Math.tan(halfFov);
      viewport.camera.position.set(shown.left + shown.width / 2, shown.height / 2, distance);
      viewport.camera.lookAt(shown.left + shown.width / 2, shown.height / 2, 0);
      spin += frame.delta * 3;
      pickups.forEach((mesh, index) => {
        mesh.visible = frame.taken[index] === 0;
        mesh.rotation.y = spin;
      });
      cubio.root.visible = frame.cubioVisible;
      cubio.root.position.set(frame.cubioX, frame.cubioY, 1);
      cubio.root.rotation.z = frame.tilt;
      cubio.root.children[0]!.position.y = -BODY_CENTRE;
      cubio.update(frame.delta, CUBIO_HEIGHT, setup.color, false, frame.face);
      viewport.renderer.render(viewport.scene, viewport.camera);
    },
    project(x: number, y: number): [number, number] {
      const rect = canvas.getBoundingClientRect();
      return toCanvas(window(focus), [rect.width, rect.height], x, y);
    },
    dispose,
  };
}
