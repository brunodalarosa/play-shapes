// Development-only. The rules the project's documents follow, as functions over
// text so they can be tested without files.
import { posix } from "node:path";

export const PARAGRAPH_LENGTH = 600;

// A task tracker's ticket number, such as the letters PS followed by digits. The
// repository names things by what they are, because nobody can look a ticket up here.
const TICKET = /\bPS[-_ ]?\d{2,3}\b/i;

export const VAULT = "KnowledgeBase/";

// The page kinds the knowledge base knows, and the frontmatter each one must carry.
const PAGE_KINDS = {
  hub: [],
  system: ["area"],
  architecture: ["level", "parent", "status"],
  reference: [],
  stub: [],
  decision: [],
};
const LEVELS = ["macro", "system", "implementation"];
const STATUSES = ["draft", "reviewed"];

// [[Name]], [[Name#Heading]], [[Name|shown text]], and the same with ! for an embed.
const WIKILINK = /!?\[\[([^\]|#]*)(?:#([^\]|]*))?(?:\|[^\]]*)?\]\]/g;

/** True for a Markdown file the document rules cover; vendored addons are not. */
export function isProjectDocument(file) {
  return file.endsWith(".md") && !file.startsWith("addons/");
}

/** True for a page of the knowledge base, which carries frontmatter; templates do not. */
export function isVaultPage(file) {
  return file.startsWith(VAULT) && file.endsWith(".md") && !file.startsWith(`${VAULT}_Templates/`);
}

/**
 * The name a wikilink uses for a vault file: a page without its extension, any other
 * file with it.
 */
export function vaultName(file) {
  const base = posix.basename(file);
  return base.endsWith(".md") ? base.slice(0, -3) : base;
}

/**
 * Reads the frontmatter block at the top of a Markdown text: plain `key: value` lines,
 * with `[a, b]` lists. Returns null when the text has none.
 */
export function frontmatter(text) {
  const block = /^---\r?\n([\s\S]*?)\r?\n---(\r?\n|$)/.exec(text);
  if (!block) return null;

  const fields = {};
  for (const line of block[1].split(/\r?\n/)) {
    const field = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
    if (!field) continue;

    const value = field[2].trim();
    const list = /^\[(.*)\]$/.exec(value);
    fields[field[1]] = list
      ? list[1]
          .split(",")
          .map((item) => unquote(item.trim()))
          .filter((item) => item !== "")
      : unquote(value);
  }
  return fields;
}

function unquote(value) {
  return /^(["']).*\1$/.test(value) ? value.slice(1, -1) : value;
}

/** Returns what is wrong with the frontmatter of a vault page, one sentence each. */
export function frontmatterProblems(fields) {
  if (fields === null) return ["The page has no frontmatter"];

  const tags = Array.isArray(fields.tags) ? fields.tags : [];
  const kinds = tags.filter((tag) => tag in PAGE_KINDS);
  if (kinds.length === 0) {
    return [`tags must name one of ${Object.keys(PAGE_KINDS).join(", ")}`];
  }

  const problems = [];
  for (const key of new Set(kinds.flatMap((kind) => PAGE_KINDS[kind]))) {
    if (!fields[key]) problems.push(`A ${kinds.join("/")} page needs ${key}`);
  }
  if (fields.level && !LEVELS.includes(fields.level)) {
    problems.push(`level must be one of ${LEVELS.join(", ")}`);
  }
  if (fields.status && !STATUSES.includes(fields.status)) {
    problems.push(`status must be one of ${STATUSES.join(", ")}`);
  }
  if (fields.verified && !/^\d{4}-\d{2}-\d{2}$/.test(fields.verified)) {
    problems.push("verified must be a date written YYYY-MM-DD");
  }
  return problems;
}

/**
 * Returns the wikilinks and embeds of a Markdown text, each with its line number, the
 * name it points at and its heading, if any. Links inside code are left out.
 */
export function wikiLinks(text) {
  const links = [];
  let fenced = false;

  for (const [index, line] of text.split(/\r?\n/).entries()) {
    if (/^\s*(```|~~~)/.test(line)) fenced = !fenced;
    if (fenced) continue;

    const withoutCode = line.replace(/`[^`]*`/g, "");
    for (const match of withoutCode.matchAll(WIKILINK)) {
      links.push({ line: index + 1, name: match[1].trim(), heading: (match[2] ?? "").trim() });
    }
  }
  return links;
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
