import test from "node:test";
import assert from "node:assert/strict";
import { LobbyInputState } from "../public/lobby_input.js";

test("stick and jump use separate touches; jump fires on release only", () => {
  const actions = [];
  const input = new LobbyInputState(action => actions.push(action));
  input.activate();
  input.move(-0.7);
  input.pressJump(42);
  assert.deepEqual(actions, [{ type: "lobby_move", horizontal: -0.7 }]);
  input.repeatMove();
  input.releaseJump(43);
  assert.equal(actions.filter(action => action.type === "lobby_jump_release").length, 0);
  input.releaseJump(42);
  assert.equal(actions.filter(action => action.type === "lobby_jump_release").length, 1);
  assert.equal(input.horizontal, -0.7);
  input.endStick();
  assert.deepEqual(actions.at(-1), { type: "lobby_move", horizontal: 0 });
});

test("cancel, inactive controls, and nonfinite stick input cannot produce a jump or movement", () => {
  const actions = [];
  const input = new LobbyInputState(action => actions.push(action));
  input.move(1);
  input.pressJump(4);
  input.releaseJump(4);
  assert.equal(actions.length, 0);
  input.activate();
  input.move(Number.NaN);
  input.move(3);
  input.pressJump(7);
  input.releaseJump(7, true);
  input.deactivate();
  input.repeatMove();
  input.releaseJump(7);
  assert.deepEqual(actions, [
    { type: "lobby_move", horizontal: 1 },
    { type: "lobby_move", horizontal: 0 },
  ]);
});
