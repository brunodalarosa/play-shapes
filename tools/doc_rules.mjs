// Development-only. The rules the project's documents follow, as functions over
// text so they can be tested without files.
import { posix } from "node:path";

export const PARAGRAPH_LENGTH = 600;

// A task tracker's ticket number, such as the letters PS followed by digits. The
// repository names things by what they are, because nobody can look a ticket up here.
const TICKET = /\bPS[-_ ]?\d{2,3}\b/i;

/**
 * True for a Markdown file the document rules cover; vendored addons and the design
 * vault are not.
 */
export function isProjectDocument(file) {
  if (!file.endsWith(".md")) return false;
  return !file.startsWith("addons/") && !file.startsWith("game-design-documents/");
}

/**
 * True where a ticket number may stay for now: the Squircle art source stores scene and
 * action names that start with one, and its scripts and guide have to quote those names
 * until they are renamed in the Blender file itself.
 */
export function mayNameTickets(file) {
  return file.startsWith("art/squircle/");
}

/** Returns the 1-based numbers of the lines that contain a ticket number. */
export function ticketLines(text) {
  return text.split(/\r?\n/).flatMap((line, index) => (TICKET.test(line) ? [index + 1] : []));
}

/** True when a file's path itself carries a ticket number. */
export function hasTicketName(file) {
  return TICKET.test(file);
}

/**
 * Splits Markdown into the units a reader takes in at once: a paragraph, one list item,
 * one table row. Fenced code is left out. Each unit has its first line number and its
 * text with line breaks turned into spaces.
 */
export function paragraphs(text) {
  const units = [];
  let current = null;
  let fenced = false;

  const close = () => {
    if (current) units.push(current);
    current = null;
  };

  for (const [index, line] of text.split(/\r?\n/).entries()) {
    if (/^\s*(```|~~~)/.test(line)) {
      close();
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;

    const startsUnit = /^\s*([-*+]|\d+\.)\s/.test(line) || /^\s*\|/.test(line) || /^#/.test(line);
    if (line.trim() === "") {
      close();
    } else if (startsUnit || !current) {
      close();
      current = { line: index + 1, text: line.trim() };
    } else {
      current.text += ` ${line.trim()}`;
    }
  }
  close();
  return units;
}

/**
 * Returns the anchor GitHub gives a heading: lower case, punctuation dropped, spaces as
 * hyphens.
 */
export function headingAnchor(heading) {
  return heading
    .trim()
    .toLowerCase()
    .replace(/`/g, "")
    .replace(/[^\p{L}\p{N}\s_-]/gu, "")
    .replace(/\s/g, "-");
}

/** Returns the anchors of every heading in a Markdown text. */
export function anchors(text) {
  let fenced = false;
  const found = [];

  for (const line of text.split(/\r?\n/)) {
    if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
    const heading = fenced ? null : /^#{1,6}\s+(.+?)\s*#*$/.exec(line);
    if (heading) found.push(headingAnchor(heading[1]));
  }
  return found;
}

/**
 * Returns the links of a Markdown text that point inside the repository, each with its
 * line number, the path it resolves to from the linking file, and its anchor if any.
 * Web addresses are not included.
 */
export function localLinks(file, text) {
  const links = [];
  let fenced = false;

  for (const [index, line] of text.split(/\r?\n/).entries()) {
    if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
    if (fenced) continue;

    const withoutCode = line.replace(/`[^`]*`/g, "");
    for (const match of withoutCode.matchAll(/\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)/g)) {
      const target = match[1];
      if (/^[a-z][a-z0-9+.-]*:/i.test(target)) continue;

      const [path, anchor = ""] = target.split("#");
      const resolved = path
        ? posix.normalize(posix.join(posix.dirname(file), decodeURIComponent(path)))
        : file;
      links.push({ line: index + 1, target, path: resolved, anchor });
    }
  }
  return links;
}
