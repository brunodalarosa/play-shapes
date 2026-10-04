// Development-only. Reads what a Godot process printed and finds the lines that fail a
// test script.

// What Godot prints at exit when something was never freed. Some of these are warnings.
const HELD_AT_EXIT = [
  /resources still in use at exit/,
  /were leaked at exit/,
  /RIDs of type .* were leaked/,
];

const LEVEL = /^(SCRIPT ERROR|ERROR|WARNING):\s*/;

/**
 * Returns the lines that fail a test script: every error, and every report of something
 * still held at exit. A script that quits the editor is excused the reports, because the
 * editor always holds a great deal when a script quits it.
 */
export function godotFailureLines(output, { editor = false } = {}) {
  return output.split(/\r?\n/).filter((line) => {
    if (HELD_AT_EXIT.some((pattern) => pattern.test(line))) return !editor;

    return /^(SCRIPT )?ERROR:/.test(line);
  });
}

/** Returns a line without the level Godot puts in front of it. */
export function withoutLevel(line) {
  return line.replace(LEVEL, "");
}
