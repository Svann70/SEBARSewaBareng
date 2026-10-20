import crypto from 'node:crypto';
import { promisify } from 'node:util';

const scrypt = promisify(crypto.scrypt);
const KEY_LEN = 64;
// OWASP minimum for scrypt. Parameters are stored in the hash so the cost can be raised later.
const PARAMS = { N: 2 ** 17, r: 8, p: 1 };
const maxmem = (N, r) => 256 * N * r;

export async function hashPassword(password) {
  const salt = crypto.randomBytes(16);
  const { N, r, p } = PARAMS;
  const key = await scrypt(password, salt, KEY_LEN, { N, r, p, maxmem: maxmem(N, r) });
  return `scrypt$${N}$${r}$${p}$${salt.toString('base64')}$${key.toString('base64')}`;
}

export async function verifyPassword(password, stored) {
  const [scheme, nStr, rStr, pStr, saltB64, keyB64] = stored.split('$');
  const [N, r, p] = [nStr, rStr, pStr].map(Number);
  if (scheme !== 'scrypt' || !saltB64 || !keyB64 || ![N, r, p].every(Number.isInteger)) return false;
  if (N < 2 ** 14 || N > 2 ** 20 || r < 1 || r > 16 || p < 1 || p > 4) return false;
  const expected = Buffer.from(keyB64, 'base64');
  if (expected.length !== KEY_LEN) return false;
  const key = await scrypt(password, Buffer.from(saltB64, 'base64'), KEY_LEN, { N, r, p, maxmem: maxmem(N, r) });
  return crypto.timingSafeEqual(key, expected);
}
