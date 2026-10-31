#!/usr/bin/env node
// Development-only. Lists the knowledge base pages worth checking against the code
// again, from the code anchors and verified date in each page's frontmatter.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { VAULT, frontmatter, isVaultPage, vaultName, wikiLinks } from "./doc_rules.mjs";
import { root } from "./environment.mjs";
import { repositoryFiles } from "./sources.mjs";

const DEFAULT_DAYS = 90;
const REPORT = "scratch/knowledge-base-staleness.md";
const DAY_MSEC = 24 * 60 * 60 * 1000;

const USAGE = `Usage: node tools/kb_staleness.mjs [--days N]

Reads the code and verified fields of every page in ${VAULT} and flags:
  MISSING  a code anchor no longer found in the source tree
  CHANGED  a file holding an anchor changed in git after the verified date
  OLD      verified is missing or older than N days (default ${DEFAULT_DAYS})
It also lists duplicate page names and gap links. Writes ${REPORT} and prints
a one-line summary. It never fails on findings: they are work to review.
`;

function readText(file) {
  const content = readFileSync(join(root, file));
  return content.includes(0) ? null : content.toString("utf8");
}

/** Returns the date of the last commit that touched any of the files, as YYYY-MM-DD. */
function lastChange(files) {
  if (files.length === 0) return "";
  const log = spawnSync("git", ["log", "-1", "--format=%cs", "--", ...files], {
    cwd: root,
    encoding: "utf8",
  });
  return log.status === 0 ? log.stdout.trim() : "";
}

/**
 * Finds the source files an anchor names: a path names itself (a folder, every file
 * under it), a symbol names the files that contain it, and `Type::member` the files that
 * contain both.
 */
function anchorFiles(anchor, sources, texts) {
  const path = anchor.replace(/\/$/, "");
  if (anchor.includes("/") || /\.[a-z0-9]+$/i.test(anchor)) {
    if (sources.includes(path)) return [path];
    return sources.filter((file) => file.startsWith(`${path}/`));
  }

  const parts = anchor.split("::").filter((part) => part !== "");
  return sources.filter((file) => {
    const text = texts.get(file);
    return text !== null && parts.every((part) => text.includes(part));
  });
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    process.stdout.write(USAGE);
    return 0;
  }
  let days = DEFAULT_DAYS;
  if (args[0] === "--days" && /^\d+$/.test(args[1] ?? "")) {
    days = Number(args[1]);
  } else if (args.length > 0) {
    process.stderr.write(`Unknown option ${args[0]}\n\n${USAGE}`);
    return 2;
  }

  const files = repositoryFiles();
  const sources = files.filter((file) => !file.startsWith(VAULT) && !file.startsWith("addons/"));
  const texts = new Map();
  for (const file of sources) {
    texts.set(file, existsSync(join(root, file)) ? readText(file) : null);
  }

  const names = new Map();
  const duplicates = [];
  for (const file of files.filter((candidate) => candidate.startsWith(VAULT))) {
    const name = vaultName(file);
    if (names.has(name)) duplicates.push(`${file} and ${names.get(name)}`);
    else names.set(name, file);
  }

  const today = Date.now();
  const rows = [];
  const gaps = new Set();
  for (const page of files.filter(isVaultPage)) {
    const text = readText(page) ?? "";
    for (const link of wikiLinks(text)) {
      if (link.name && !names.has(link.name)) gaps.add(link.name);
    }

    const fields = frontmatter(text) ?? {};
    const anchors = Array.isArray(fields.code) ? fields.code : [];
    const verified = typeof fields.verified === "string" ? fields.verified : "";
    const flags = [];

    const anchored = [];
    for (const anchor of anchors) {
      const found = anchorFiles(anchor, sources, texts);
      if (found.length === 0) flags.push(`MISSING \`${anchor}\``);
      anchored.push(...found);
    }
    const changed = lastChange([...new Set(anchored)]);
    if (verified && changed > verified) flags.push(`CHANGED ${changed}`);

    const age = verified ? (today - Date.parse(verified)) / DAY_MSEC : Infinity;
    if (age > days) flags.push(verified ? `OLD ${verified}` : "OLD never verified");

    if (flags.length > 0) rows.push(`| ${page} | ${flags.join("; ")} |`);
  }

  const lines = [
    "# Knowledge base staleness",
    "",
    `Pages: ${files.filter(isVaultPage).length}. Flagged: ${rows.length}. OLD after ${days} days.`,
    "",
    "| Page | Flags |",
    "| --- | --- |",
    ...rows,
    "",
    "## Duplicate names",
    "",
    ...(duplicates.length > 0 ? duplicates.map((pair) => `- ${pair}`) : ["None."]),
    "",
    "## Gap links",
    "",
    ...(gaps.size > 0 ? [...gaps].sort().map((gap) => `- [[${gap}]]`) : ["None."]),
    "",
  ];
  mkdirSync(join(root, "scratch"), { recursive: true });
  writeFileSync(join(root, REPORT), lines.join("\n"));

  const summary =
    `${rows.length} flagged pages, ${duplicates.length} duplicate names, ` +
    `${gaps.size} gap links; see ${REPORT}`;
  process.stdout.write(`${summary}\n`);
  return 0;
}

process.exitCode = main();
