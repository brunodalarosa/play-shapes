import { TextureLoader, SRGBColorSpace } from "three";
import { GLTFLoader, type GLTF } from "three/examples/jsm/loaders/GLTFLoader.js";
import { clone } from "three/examples/jsm/utils/SkeletonUtils.js";

const loader = new GLTFLoader();
const models = new Map<string, Promise<GLTF>>();
const textures = new TextureLoader();
const faces = new Map<string, ReturnType<TextureLoader["loadAsync"]>>();

export function loadModel(url: string): Promise<GLTF> {
  let model = models.get(url);
  if (!model) {
    model = loader.loadAsync(url).catch((error: unknown) => {
      models.delete(url);
      throw error;
    });
    models.set(url, model);
  }
  return model;
}

export async function modelInstance(url: string) {
  const model = await loadModel(url);
  return { scene: clone(model.scene), animations: model.animations };
}

export function loadFace(url: string) {
  let face = faces.get(url);
  if (!face) {
    face = textures
      .loadAsync(url)
      .then((texture) => {
        texture.flipY = false;
        texture.colorSpace = SRGBColorSpace;
        return texture;
      })
      .catch((error: unknown) => {
        faces.delete(url);
        throw error;
      });
    faces.set(url, face);
  }
  return face;
}
