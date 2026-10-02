/** A second platform context: records shared intent without a lobby protocol or game. */
export function createPreviewContext(record) {
  return { activeClass: "lobby-active", send: intent => record({ context: "preview", intent }) };
}
