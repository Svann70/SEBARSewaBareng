import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { test } from 'node:test';
import { rateLimit } from '../src/middleware/rate-limit.js';

function call(mw, req, statusCode = 200) {
  const res = Object.assign(new EventEmitter(), { headers: {}, statusCode, set(k, v) { this.headers[k] = v; } });
  let error;
  mw(req, res, (err) => (error = err));
  if (!error) res.emit('finish');
  return { error, headers: res.headers };
}

test('allows max requests per key per window, then 429 with Retry-After', () => {
  const mw = rateLimit({ windowMs: 60_000, max: 2 });
  assert.equal(call(mw, { ip: '1.1.1.1' }).error, undefined);
  assert.equal(call(mw, { ip: '1.1.1.1' }).error, undefined);
  const third = call(mw, { ip: '1.1.1.1' });
  assert.equal(third.error.status, 429);
  assert.equal(third.error.code, 'RATE_LIMITED');
  assert.ok(Number(third.headers['Retry-After']) > 0);
  assert.equal(call(mw, { ip: '2.2.2.2' }).error, undefined, 'other keys are independent');
});

test('countIf: only matching responses use up the budget', () => {
  const mw = rateLimit({ windowMs: 60_000, max: 2, countIf: (res) => res.statusCode === 401 });
  for (let i = 0; i < 5; i++) assert.equal(call(mw, { ip: '1.1.1.1' }, 200).error, undefined, 'successes are free');
  call(mw, { ip: '1.1.1.1' }, 401);
  call(mw, { ip: '1.1.1.1' }, 401);
  assert.equal(call(mw, { ip: '1.1.1.1' }, 200).error?.status, 429);
});

test('requests without a key are not limited', () => {
  const mw = rateLimit({ windowMs: 60_000, max: 1, key: () => undefined });
  for (let i = 0; i < 3; i++) assert.equal(call(mw, {}).error, undefined);
});
