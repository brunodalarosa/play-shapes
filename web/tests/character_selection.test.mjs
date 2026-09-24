import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  advanceJoinFlow, bodyAssetPath, CHARACTER_COLORS, CHARACTER_SHAPES, chooseJoinColor,
  colorOption, createJoinMessage, cycleJoinShape, defaultJoinFlow,
  FALLBACK_CHARACTER, isCharacterShape, returnToCharacterSelection, shapeAtOffset
} from '../public/character_selection.js';

test('character selector exposes the approved shape order and wraps in both directions', () => {
  assert.deepEqual(CHARACTER_SHAPES, ['square', 'circle', 'squircle', 'rhombus']);
  assert.equal(shapeAtOffset('rhombus', 1), 'square');
  assert.equal(shapeAtOffset('square', -1), 'rhombus');
  assert.equal(isCharacterShape('squircle'), true);
  assert.equal(isCharacterShape('triangle'), false);
  assert.deepEqual(CHARACTER_SHAPES.map(bodyAssetPath), [
    '/shape-square.png', '/shape-circle.png', '/shape-squircle.png', '/shape-rhombus.png'
  ]);
});

test('character selector exposes all ten agreed colors in order and keeps fallback separate', () => {
  assert.deepEqual(CHARACTER_COLORS.map(({ name, hex }) => [name, hex]), [
    ['Red', '#E53935'], ['Orange', '#F57C00'], ['Golden Yellow', '#FBC02D'],
    ['Green', '#43A047'], ['Cyan', '#00ACC1'], ['Blue', '#1E88E5'],
    ['Indigo', '#3949AB'], ['Purple', '#8E24AA'], ['Pink', '#EC407A'], ['Brown', '#8D6E63']
  ]);
  assert.equal(colorOption('#ec407a')?.name, 'Pink');
  assert.equal(colorOption('#598df2'), undefined);
  assert.deepEqual(FALLBACK_CHARACTER, { shape: 'circle', color: '#598DF2' });
});

test('join selection survives the name screen back action and submits as one host request', () => {
  let flow = defaultJoinFlow();
  flow = cycleJoinShape(flow, 1);
  flow = cycleJoinShape(flow, 1);
  flow = chooseJoinColor(flow, '#EC407A');
  flow = advanceJoinFlow(flow);
  assert.deepEqual(flow, { screen: 'name', shape: 'rhombus', color: '#EC407A' });
  flow = returnToCharacterSelection(flow);
  assert.deepEqual(flow, { screen: 'selection', shape: 'rhombus', color: '#EC407A' });
  assert.deepEqual(createJoinMessage('  Player One  ', flow), {
    type: 'join', name: 'Player One', character_shape: 'rhombus', character_color: '#EC407A'
  });
});
