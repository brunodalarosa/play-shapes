import { test } from 'node:test';
import assert from 'node:assert/strict';
import { attemptImmersive } from '../public/immersive.js';

test('fullscreen and orientation denials resolve as playable fallbacks', async () => {
  let orientationAttempted = false;
  await attemptImmersive(
    () => Promise.reject(new Error('Fullscreen denied')),
    () => { orientationAttempted = true; return Promise.reject(new Error('Orientation denied')); }
  );
  assert.equal(orientationAttempted, true);
});
