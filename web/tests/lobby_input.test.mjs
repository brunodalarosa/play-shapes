import test from "node:test";
import assert from "node:assert/strict";
import { PlatformInputState } from "../build/platform_input.js";
import { createLobbyContext } from "../build/lobby_input.js";

test("Playground adapter keeps ordinary movement/jump and hands off explicit fall without a jump fallback", () => {
  const sent = [];
  const context = createLobbyContext((value) => sent.push(value));
  const input = new PlatformInputState(context.send);
  input.activate();
  input.updateAxes(-0.7, 0.4);
  input.refresh();
  input.pressAction(1);
  input.releaseAction(1);
  input.updateAxes(0, -1);
  input.pressAction(2);
  input.releaseAction(2);
  input.endStick();
  assert.deepEqual(sent, [
    { type: "lobby_move", horizontal: -0.7, vertical: 0.4, stance: "move" },
    { type: "lobby_jump_release", action: "jump", horizontal: -0.7, vertical: 0.4, stance: "move" },
    { type: "lobby_fall_release", action: "fall", horizontal: 0, vertical: -1, stance: "crouch" },
    { type: "lobby_move", horizontal: 0, vertical: 0, stance: "neutral" },
  ]);
});
