#!/usr/bin/env node
// Development-only. Checks the project's documents against their rules and
// prints one finding per line.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  PARAGRAPH_LENGTH,
  anchors,
  hasTicketName,
  isProjectDocument,
  localLinks,
  paragraphs,
  ticketLines,
} from "./doc_rules.mjs";
import { root } from "./environment.mjs";
import { repositoryFiles } from "./sources.mjs";

const USAGE = `Usage: node tools/docs.mjs

Checks every Markdown file outside addons/ and game-design-documents/: each
link inside the repository must point to an existing file, and to an existing
heading when it names one, and no paragraph, list item or table row may be
longer than ${PARAGRAPH_LENGTH} characters. Also reports a ticket number in any text
file or file name. Prints one finding per line and fails when there is any.
`;

/** Reads a file as text, or returns null when it holds binary data. */
function readText(file) {
  const content = readFileSync(join(root, file));
  return content.includes(0) ? null : content.toString("utf8");
}

function main() {
  const args = process.argv.slice(2);
  if (args.includes("--help") || args.includes("-h")) {
    process.stdout.write(USAGE);
    return 0;
  }
  if (args.length > 0) {
    process.stderr.write(`Unknown option ${args[0]}\n\n${USAGE}`);
    return 2;
  }

  const files = repositoryFiles().filter((file) => !file.startsWith("addons/"));
  // Compared exactly, so a link that only works on a file system that ignores case is reported.
  const known = new Set(files);
  const findings = [];
  const headings = new Map();

  const anchorsOf = (file) => {
    if (!headings.has(file)) headings.set(file, anchors(readText(file) ?? ""));
    return headings.get(file);
  };

  for (const file of files) {
    if (hasTicketName(file)) {
      findings.push(`${file}:1: ticket-id: The file name carries a ticket number`);
    }

    const text = readText(file);
    if (text === null) continue;

    for (const line of ticketLines(text)) {
      findings.push(`${file}:${line}: ticket-id: Name the thing, not the ticket it came from`);
    }
    if (!isProjectDocument(file)) continue;

    for (const unit of paragraphs(text)) {
      if (unit.text.length <= PARAGRAPH_LENGTH) continue;

      findings.push(
        `${file}:${unit.line}: long-paragraph: ${unit.text.length} characters, ` +
          `maximum is ${PARAGRAPH_LENGTH}; split it or make it a list`,
      );
    }

    for (const link of localLinks(file, text)) {
      if (!known.has(link.path)) {
        findings.push(`${file}:${link.line}: broken-link: ${link.target} does not exist`);
      } else if (link.anchor && link.path.endsWith(".md")) {
        if (!anchorsOf(link.path).includes(link.anchor)) {
          findings.push(`${file}:${link.line}: broken-link: ${link.target} names no heading`);
        }
      }
    }
  }

  if (findings.length === 0) {
    process.stdout.write("No document findings.\n");
    return 0;
  }

  for (const finding of findings) process.stdout.write(`${finding}\n`);
  process.stdout.write(`${findings.length} document findings\n`);
  return 1;
}

process.exitCode = main();
