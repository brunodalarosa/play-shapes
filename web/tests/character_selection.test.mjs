import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  advanceJoinFlow, CHARACTER_COLORS, CHARACTER_SHAPE, chooseJoinColor,
  colorOption, createJoinMessage, defaultJoinFlow,
  FALLBACK_CHARACTER, returnToCharacterSelection
} from '../public/character_selection.js';

test('phone setup keeps one approved body and all ten player colors', () => {
  assert.equal(CHARACTER_SHAPE, 'squircle');
  assert.deepEqual(CHARACTER_COLORS.map(({ name, hex }) => [name, hex]), [
    ['Red', '#E53935'], ['Orange', '#F57C00'], ['Golden Yellow', '#FBC02D'],
    ['Green', '#43A047'], ['Cyan', '#00ACC1'], ['Blue', '#1E88E5'],
    ['Indigo', '#3949AB'], ['Purple', '#8E24AA'], ['Pink', '#EC407A'], ['Brown', '#8D6E63']
  ]);
  assert.equal(colorOption('#ec407a')?.name, 'Pink');
  assert.deepEqual(FALLBACK_CHARACTER, { shape: 'squircle', color: '#598DF2' });
});

test('join preserves color through the name screen and submits Squircle automatically', () => {
  let flow = chooseJoinColor(defaultJoinFlow(), '#EC407A');
  flow = advanceJoinFlow(flow);
  assert.deepEqual(flow, { screen: 'name', color: '#EC407A' });
  flow = returnToCharacterSelection(flow);
  assert.deepEqual(flow, { screen: 'selection', color: '#EC407A' });
  assert.deepEqual(createJoinMessage('  Player One  ', flow), {
    type: 'join', name: 'Player One', character_shape: 'squircle', character_color: '#EC407A'
  });
});
