import { copyFileSync, mkdirSync } from "node:fs";

const destination = new URL("../public/models/", import.meta.url);
const character = "../../assets/runtime/animated_characters/squircle/v1/model/";
const creature = "../../assets/runtime/minigames/bubbles_3d/jellyfish/";
mkdirSync(destination, { recursive: true });
for (const [source, name] of [
  [character + "squircle.glb", "squircle.glb"],
  [creature + "jellyfish.glb", "jellyfish.glb"],
]) {
  copyFileSync(new URL(source, import.meta.url), new URL(name, destination));
}
