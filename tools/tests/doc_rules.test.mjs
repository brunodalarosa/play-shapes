import assert from "node:assert/strict";
import test from "node:test";
import {
  anchors,
  hasTicketName,
  headingAnchor,
  isProjectDocument,
  localLinks,
  mayNameTickets,
  paragraphs,
  ticketLines,
} from "../doc_rules.mjs";

// Built from two pieces so this file does not itself contain a ticket number.
const ticket = (number) => `PS-${number}`;

test("covers project Markdown and leaves vendored addons and the design vault alone", () => {
  assert.equal(isProjectDocument("README.md"), true);
  assert.equal(isProjectDocument("docs/protocol.md"), true);
  assert.equal(isProjectDocument("addons/godot_mcp/README.md"), false);
  assert.equal(isProjectDocument("game-design-documents/Glossary.md"), false);
  assert.equal(isProjectDocument("tools/check.mjs"), false);
});

test("finds ticket numbers in text and in file names", () => {
  const text = `first line\nsee ${ticket("082")} for details\nthird\nscene ${"PS"}057 | Idle`;
  assert.deepEqual(ticketLines(text), [2, 4]);
  assert.deepEqual(ticketLines("HTTPS on port 8080, GPS 12, caps 100"), []);

  assert.equal(hasTicketName(`docs/${ticket("080").toLowerCase()}-animations.md`), true);
  assert.equal(hasTicketName("docs/squircle-animations.md"), false);
});

test("lets only the Squircle art source name tickets", () => {
  assert.equal(mayNameTickets("art/squircle/export_frames.py"), true);
  assert.equal(mayNameTickets("art/bubbles/README.md"), false);
  assert.equal(mayNameTickets("docs/architecture.md"), false);
});

test("splits Markdown into paragraphs, list items and table rows", () => {
  const text = [
    "# Title",
    "",
    "A paragraph",
    "wrapped over two lines.",
    "",
    "- first item",
    "  continued",
    "- second item",
    "",
    "| a | b |",
    "| 1 | 2 |",
  ].join("\n");

  assert.deepEqual(paragraphs(text), [
    { line: 1, text: "# Title" },
    { line: 3, text: "A paragraph wrapped over two lines." },
    { line: 6, text: "- first item continued" },
    { line: 8, text: "- second item" },
    { line: 10, text: "| a | b |" },
    { line: 11, text: "| 1 | 2 |" },
  ]);
});

test("leaves fenced code out of paragraphs", () => {
  const text = ["before", "", "```json", `{"long": "${"x".repeat(900)}"}`, "```", "", "after"];
  assert.deepEqual(
    paragraphs(text.join("\n")).map((unit) => unit.text),
    ["before", "after"],
  );
});

test("gives headings the anchors GitHub gives them", () => {
  assert.equal(
    headingAnchor("Host components and platform setup"),
    "host-components-and-platform-setup",
  );
  assert.equal(headingAnchor("Formatting and linting"), "formatting-and-linting");
  assert.equal(
    headingAnchor("The `check` command: what it runs"),
    "the-check-command-what-it-runs",
  );
  assert.equal(headingAnchor("F12 motion lab"), "f12-motion-lab");

  const text = "# One\n\n```\n# not a heading\n```\n\n## Two parts ##\n";
  assert.deepEqual(anchors(text), ["one", "two-parts"]);
});

test("resolves links inside the repository from the linking file", () => {
  const text = [
    "See [setup](../README.md#requirements) and [protocol](protocol.md).",
    "An [image](<images/a b.png>), a [section](#running) and a [site](https://example.com).",
    "Not a link: `[text](code.md)`",
    "[spaced](Art%20direction.md)",
  ].join("\n");

  assert.deepEqual(localLinks("docs/overview.md", text), [
    { line: 1, target: "../README.md#requirements", path: "README.md", anchor: "requirements" },
    { line: 1, target: "protocol.md", path: "docs/protocol.md", anchor: "" },
    { line: 2, target: "#running", path: "docs/overview.md", anchor: "running" },
    { line: 4, target: "Art%20direction.md", path: "docs/Art direction.md", anchor: "" },
  ]);
});
