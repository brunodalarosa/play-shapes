import test from 'node:test';
import assert from 'node:assert/strict';
import { namesFor } from '../../tools/local_https.mjs';

test('certificate SAN selection requires explicit IP and keeps hostname optional', () => {
  assert.deepEqual(namesFor('192.168.1.20', 'playshapes.local'), ['192.168.1.20', 'playshapes.local', 'localhost', '127.0.0.1']);
  assert.deepEqual(namesFor('127.0.0.1'), ['127.0.0.1', 'localhost']);
  for (const address of ['', 'not-an-ip', '0.0.0.0', '192.168.1.1;whoami']) assert.throws(() => namesFor(address));
  assert.throws(() => namesFor('192.168.1.20', 'https://playshapes.local'));
});
