import { test } from 'node:test';
import assert from 'node:assert/strict';
import { PwaOnboarding, isStandalone, installGuidance } from '../public/pwa.js';

function fixture({ standalone = false, browser = { userAgent: 'Android', platform: 'Linux', maxTouchPoints: 1 }, storage = new Map(), restricted = false } = {}) {
  const target = Object.assign(new EventTarget(), {
    matchMedia: query => ({ matches: standalone && query.includes('standalone') }),
    sessionStorage: { getItem: key => { if (restricted) throw Error(); return storage.get(key); }, setItem: (key, value) => { if (restricted) throw Error(); storage.set(key, value); } },
  });
  const element = () => Object.assign(new EventTarget(), { hidden: true, textContent: '', disabled: false, focus() {} });
  const panel = element(), action = element(), guidance = element(), continueButton = element();
  let continued = 0;
  const offer = new PwaOnboarding(panel, action, guidance, continueButton, () => continued++, target, browser);
  return { target, panel, action, guidance, continueButton, offer, continued: () => continued, storage };
}

test('onboarding offers app once, continuing never interrupts subsequent play/rejoin', () => {
  const f = fixture();
  assert.equal(f.offer.show(), true);
  f.continueButton.dispatchEvent(new Event('click'));
  assert.equal(f.offer.visible, false); assert.equal(f.continued(), 1);
  assert.equal(f.offer.show(), false);
  assert.equal(fixture({ storage: f.storage }).offer.show(), false);
  const denied = fixture({ restricted: true });
  denied.offer.show(); denied.continueButton.dispatchEvent(new Event('click'));
  assert.equal(denied.offer.show(), false);
});

test('standalone display modes and Apple legacy flag suppress redundant prompts', () => {
  assert.equal(fixture({ standalone: true }).offer.show(), false);
  assert.equal(isStandalone({ matchMedia: query => ({ matches: query.includes('fullscreen') }) }, {}), true);
  assert.equal(fixture({ browser: { standalone: true } }).offer.show(), false);
});

test('Safari/iPad guidance uses real Home Screen steps without an automatic prompt', async () => {
  const f = fixture({ browser: { userAgent: 'iPhone Safari', platform: 'iPhone', maxTouchPoints: 5 } });
  f.offer.show(); f.action.dispatchEvent(new Event('click'));
  assert.match(f.guidance.textContent, /Share → Add to Home Screen/);
  assert.match(f.guidance.textContent, /Open as Web App/);
  assert.match(f.guidance.textContent, /before joining/);
  assert.match(installGuidance({ userAgent: 'Safari', platform: 'MacIntel', maxTouchPoints: 5 }), /Share/);
  f.continueButton.dispatchEvent(new Event('click')); assert.equal(f.continued(), 1);
});

test('native installation is invoked synchronously by a gesture and used only once', async () => {
  const f = fixture(); let calls = 0;
  f.offer.show();
  const event = Object.assign(new Event('beforeinstallprompt', { cancelable: true }), {
    prompt: () => { calls++; return Promise.resolve(); }, userChoice: Promise.resolve({ outcome: 'accepted' }),
  });
  f.target.dispatchEvent(event); assert.equal(event.defaultPrevented, true);
  f.action.dispatchEvent(new Event('click')); assert.equal(calls, 1);
  f.action.dispatchEvent(new Event('click')); assert.equal(calls, 1);
  await new Promise(resolve => setImmediate(resolve));
  assert.match(f.guidance.textContent, /new icon/); assert.equal(f.offer.visible, true);
  f.action.dispatchEvent(new Event('click')); assert.equal(calls, 1);
  f.continueButton.dispatchEvent(new Event('click')); assert.equal(f.continued(), 1);
});

test('install dismissal/denial and late install events retain browser fallback', async () => {
  for (const throws of [false, true]) {
    const f = fixture(); f.offer.show();
    f.target.dispatchEvent(Object.assign(new Event('beforeinstallprompt'), {
      prompt: () => throws ? Promise.reject(Error('denied')) : Promise.resolve(), userChoice: Promise.resolve({ outcome: 'dismissed' }),
    }));
    f.action.dispatchEvent(new Event('click'));
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(f.action.disabled, false); assert.match(f.guidance.textContent, /browser menu/);
    f.continueButton.dispatchEvent(new Event('click'));
    f.target.dispatchEvent(new Event('appinstalled'));
    assert.equal(f.offer.visible, false); assert.equal(f.offer.show(), false);
  }
});
