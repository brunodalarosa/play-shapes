import { AmbientLight, DirectionalLight } from "three";
import type { CharacterPreview } from "../character_preview.js";
import { createCubio } from "./cubio.js";
import { Viewport } from "./viewport.js";

export async function createCharacterPreview(
  canvas: HTMLCanvasElement,
  signal?: AbortSignal,
): Promise<CharacterPreview> {
  let character: Awaited<ReturnType<typeof createCubio>> | undefined;
  let color = "#1E88E5";
  const viewport = new Viewport(canvas, (delta) => {
    if (!character) return;

    const aspect = Math.min(1, viewport.camera.aspect);
    const distance = 1.65 / (2 * Math.tan((viewport.camera.fov * Math.PI) / 360) * aspect);
    viewport.camera.position.set(0, 0.5 + distance * 0.12, distance);
    viewport.camera.lookAt(0, 0.5, 0);
    character.update(delta, 1, color, false);
  });
  let disposed = false;
  const dispose = (): void => {
    if (disposed) return;

    disposed = true;
    viewport.dispose();
    character?.dispose();
    signal?.removeEventListener("abort", dispose);
  };
  signal?.addEventListener("abort", dispose, { once: true });
  try {
    if (signal?.aborted) throw new DOMException("Preview retired", "AbortError");

    const loaded = await createCubio();
    if (disposed) {
      loaded.dispose();
      throw new DOMException("Preview retired", "AbortError");
    }
    character = loaded;
    character.root.rotation.y = -0.22;
    viewport.scene.add(character.root, new AmbientLight(0xffffff, 1.4));
    const light = new DirectionalLight(0xffffff, 2.4);
    light.position.set(-3, 5, 5);
    viewport.scene.add(light);
    return {
      setColor(value: string): void {
        color = value;
      },
      dispose,
    };
  } catch (error) {
    dispose();
    throw error;
  }
}
