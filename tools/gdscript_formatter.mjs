// Development-only. Locates the pinned GDScript formatter and downloads it into
// the ignored local/tools/ folder. A version change needs a new checksum for
// every platform below.
import { createHash } from "node:crypto";
import { chmodSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { inflateRawSync } from "node:zlib";
import { root } from "./environment.mjs";

export const FORMATTER_VERSION = "0.27.0";

const RELEASES = "https://github.com/GDQuest/GDScript-formatter/releases/download";

// Node's platform and architecture names, each with the release's name for it and
// the SHA-256 of that release archive.
const BUILDS = {
  "linux-arm64": [
    "linux-aarch64",
    "b400fcf7145715d0868a2b5ef05bb99d86d32395264c0c239c8826ac979ac5b9",
  ],
  "linux-x64": ["linux-x86_64", "56c8b7566b6ba6eb8738156ca13b2e93c2489b66a15ae6070aea0321d37a5323"],
  "darwin-arm64": [
    "macos-aarch64",
    "e7d9fe240d5c5630b8738f6e0616a2473807037b9d10b70a11690ab1a73bc5bc",
  ],
  "darwin-x64": [
    "macos-x86_64",
    "0aa9e345b879de2d2211801be83728a44246ff1b75a6e319bfafa672f282b995",
  ],
  "win32-arm64": [
    "windows-aarch64.exe",
    "5124b8085123d587cac3ca09ec3ae0f4703ab2a8a9e33026145f479f0050c43d",
  ],
  "win32-x64": [
    "windows-x86_64.exe",
    "5da94d9ae2d000b81ee8de23f8e693eb15c0718fe72d4984174c7f153b5b4289",
  ],
};

/** Returns the formatter build for a platform, or null when the release has none. */
export function formatterBuild(platform = process.platform, arch = process.arch) {
  const build = BUILDS[`${platform}-${arch}`];
  if (!build) return null;

  const [name, sha256] = build;
  const file = `gdscript-formatter-${FORMATTER_VERSION}-${name}`;
  return { file, sha256, url: `${RELEASES}/${FORMATTER_VERSION}/${file}.zip` };
}

/** Returns where the formatter is installed. The version is in the name, so a new pin is a new file. */
export function formatterPath(platform = process.platform, arch = process.arch) {
  const build = formatterBuild(platform, arch);
  return build ? join(root, "local", "tools", build.file) : null;
}

/** Returns the contents of the single file in a zip archive. */
export function extractOnlyFile(zip) {
  // The directory of a zip is at its end, located by a record that may be followed by a comment.
  let end = zip.length - 22;
  while (end >= 0 && zip.readUInt32LE(end) !== 0x06054b50) end -= 1;
  if (end < 0) throw new Error("not a zip archive");
  if (zip.readUInt16LE(end + 10) !== 1) throw new Error("expected one file in the archive");

  const entry = zip.readUInt32LE(end + 16);
  if (zip.readUInt32LE(entry) !== 0x02014b50) throw new Error("damaged zip directory");
  const method = zip.readUInt16LE(entry + 10);
  const packedSize = zip.readUInt32LE(entry + 20);
  const size = zip.readUInt32LE(entry + 24);
  const header = zip.readUInt32LE(entry + 42);

  if (zip.readUInt32LE(header) !== 0x04034b50) throw new Error("damaged zip entry");
  const start = header + 30 + zip.readUInt16LE(header + 26) + zip.readUInt16LE(header + 28);
  const packed = zip.subarray(start, start + packedSize);

  const stored = 0;
  const deflated = 8;
  if (method !== stored && method !== deflated)
    throw new Error(`unsupported zip compression ${method}`);
  const content = method === stored ? Buffer.from(packed) : inflateRawSync(packed);
  if (content.length !== size) throw new Error("zip entry has the wrong size");
  return content;
}

/** Downloads the pinned formatter, checks the archive against its recorded checksum and installs it. */
export async function installFormatter() {
  const build = formatterBuild();
  if (!build)
    throw new Error(`the GDScript formatter has no build for ${process.platform}-${process.arch}`);

  const response = await fetch(build.url);
  if (!response.ok) throw new Error(`could not download ${build.url}: HTTP ${response.status}`);
  const archive = Buffer.from(await response.arrayBuffer());

  const sha256 = createHash("sha256").update(archive).digest("hex");
  if (sha256 !== build.sha256)
    throw new Error(`${build.url} has checksum ${sha256}, expected ${build.sha256}`);

  const path = formatterPath();
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, extractOnlyFile(archive));
  chmodSync(path, 0o755);
  return path;
}
