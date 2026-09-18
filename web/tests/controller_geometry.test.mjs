import { test } from 'node:test';
import assert from 'node:assert/strict';
import { attemptImmersive, chargedColor, directionAtPoint, heldDirectionAfterUpdate } from '../public/controller_geometry.js';

test('two, three, and four region geometry covers representative and boundary points', () => {
  const d = (count, x, y) => directionAtPoint(count, x, y, 100, 100);
  assert.deepEqual([d(2, 10, 50), d(2, 50, 50), d(2, 100, 100)], ['left', 'right', 'right']);
  assert.deepEqual([d(3, 10, 10), d(3, 90, 10), d(3, 50, 50), d(3, 0, 100), d(3, 100, 100)], ['left', 'right', 'down', 'down', 'down']);
  assert.deepEqual([d(4, 50, 0), d(4, 100, 50), d(4, 50, 100), d(4, 0, 50), d(4, 50, 50)], ['up', 'right', 'down', 'left', 'left']);
});

test('charge color uses exact brightness endpoints and interpolation', () => {
  assert.equal(chargedColor('#80ff40', 0.4, 1, 0), 'rgb(51 102 26)');
  assert.equal(chargedColor('#80ff40', 0.4, 1, 0.5), 'rgb(90 179 45)');
  assert.equal(chargedColor('#80ff40', 0.4, 1, 1), 'rgb(128 255 64)');
});

test('direction transitions preserve valid holds and release removed holds', () => {
  assert.equal(heldDirectionAfterUpdate('left', ['left', 'right', 'down']), 'left');
  assert.equal(heldDirectionAfterUpdate('up', ['left', 'right', 'down']), undefined);
});

test('fullscreen and orientation denials resolve as playable fallbacks', async () => {
  let attempts = 0;
  await assert.doesNotReject(attemptImmersive(
    async () => { attempts += 1; throw new Error('denied'); },
    async () => { attempts += 1; throw new Error('unsupported'); },
  ));
  assert.equal(attempts, 2);
});
