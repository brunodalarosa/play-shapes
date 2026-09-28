import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const webRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const destination = join(webRoot, "public", "vendor", "nipplejs.mjs");
mkdirSync(dirname(destination), { recursive: true });
copyFileSync(join(webRoot, "node_modules", "nipplejs", "dist", "index.mjs"), destination);
