// Removes the previous per-module build, so that a module deleted from src/ does not
// linger where the tests import from.
import { rmSync } from "node:fs";

rmSync(new URL("../build/", import.meta.url), { recursive: true, force: true });
