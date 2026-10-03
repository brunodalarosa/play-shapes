import assert from "node:assert/strict";
import test from "node:test";
import { deflateRawSync } from "node:zlib";
import {
  FORMATTER_VERSION,
  extractOnlyFile,
  formatterBuild,
  formatterPath,
} from "../gdscript_formatter.mjs";

/** Builds a zip archive of the given files, enough of the format for extractOnlyFile to read. */
function zipOf(files, { deflate = true, comment = "" } = {}) {
  const locals = [];
  const directory = [];
  let offset = 0;

  for (const [name, content] of files) {
    const packed = deflate ? deflateRawSync(content) : content;
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(deflate ? 8 : 0, 8);
    local.writeUInt32LE(packed.length, 18);
    local.writeUInt32LE(content.length, 22);
    local.writeUInt16LE(name.length, 26);

    const entry = Buffer.alloc(46);
    entry.writeUInt32LE(0x02014b50, 0);
    entry.writeUInt16LE(deflate ? 8 : 0, 10);
    entry.writeUInt32LE(packed.length, 20);
    entry.writeUInt32LE(content.length, 24);
    entry.writeUInt16LE(name.length, 28);
    entry.writeUInt32LE(offset, 42);

    locals.push(local, Buffer.from(name), packed);
    directory.push(entry, Buffer.from(name));
    offset += local.length + name.length + packed.length;
  }

  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(Buffer.concat(directory).length, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(comment.length, 20);
  return Buffer.concat([...locals, ...directory, end, Buffer.from(comment)]);
}

test("names the release archive for each supported platform", () => {
  const windows = formatterBuild("win32", "x64");
  assert.equal(windows.file, `gdscript-formatter-${FORMATTER_VERSION}-windows-x86_64.exe`);
  const releases = "https://github.com/GDQuest/GDScript-formatter/releases/download";
  assert.equal(windows.url, `${releases}/${FORMATTER_VERSION}/${windows.file}.zip`);
  assert.match(windows.sha256, /^[0-9a-f]{64}$/);

  assert.equal(
    formatterBuild("darwin", "arm64").file,
    `gdscript-formatter-${FORMATTER_VERSION}-macos-aarch64`,
  );
  assert.equal(
    formatterBuild("linux", "x64").file,
    `gdscript-formatter-${FORMATTER_VERSION}-linux-x86_64`,
  );
});

test("has no build, and so no path, for a platform the release does not cover", () => {
  assert.equal(formatterBuild("freebsd", "x64"), null);
  assert.equal(formatterPath("freebsd", "x64"), null);
});

test("installs under local/tools with the version in the file name", () => {
  const path = formatterPath("linux", "arm64").replaceAll("\\", "/");
  assert.ok(
    path.endsWith(`/local/tools/gdscript-formatter-${FORMATTER_VERSION}-linux-aarch64`),
    path,
  );
});

test("extracts the single file of a zip archive", () => {
  const content = Buffer.from("formatter program bytes ".repeat(200));
  assert.deepEqual(extractOnlyFile(zipOf([["tool", content]])), content);
  assert.deepEqual(extractOnlyFile(zipOf([["tool", content]], { deflate: false })), content);
  assert.deepEqual(
    extractOnlyFile(zipOf([["tool", content]], { comment: "a trailing comment" })),
    content,
  );
});

test("refuses an archive that is not one file in a zip", () => {
  const content = Buffer.from("bytes");
  assert.throws(
    () =>
      extractOnlyFile(
        zipOf([
          ["one", content],
          ["two", content],
        ]),
      ),
    /expected one file/,
  );
  assert.throws(
    () => extractOnlyFile(Buffer.from("this is not a zip archive at all")),
    /not a zip archive/,
  );
});
