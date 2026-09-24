import { test } from 'node:test';
import assert from 'node:assert/strict';
import { GestureTrace, MAX_TRACE_POINTS } from '../public/bubbles_gesture.js';

test('completed trace clamps coordinates and requires movement', () => {
  const trace = new GestureTrace({ left: 10, top: 20, width: 100, height: 200 });
  trace.add(60, 120);
  assert.deepEqual(trace.completed(), []);
  trace.add(1100, -30);
  assert.deepEqual(trace.completed(), [[0.5, 0.5], [1, 0]]);
  assert.deepEqual(trace.displacement(), [0.5, -0.5]);
});

test('dense circle stays bounded and previews charge without changing action truth', () => {
  const trace = new GestureTrace({ left: 0, top: 0, width: 100, height: 100 });
  for (let index = 0; index <= 400; index++) {
    const angle = index / 400 * Math.PI * 4;
    trace.add(50 + 25 * Math.cos(angle), 50 + 25 * Math.sin(angle));
  }
  assert.ok(trace.completed().length <= MAX_TRACE_POINTS);
  assert.ok(trace.preview(2) > 0.8);
  assert.equal(trace.preview(3) < 1, true);
});

test('invalid bounds and coordinates never enter the trace', () => {
  const trace = new GestureTrace({ left: 0, top: 0, width: 0, height: 100 });
  trace.add(2, 2);
  trace.add(Number.NaN, 2);
  assert.deepEqual(trace.completed(), []);
});
