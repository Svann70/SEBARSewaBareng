import { AppError } from '../lib/errors.js';

const MAX_KEYS = 50_000;

// Fixed-window in-memory limiter. Per process: fine for one instance; use a shared store if scaled out.
// countIf(res) decides after the response whether the request counts (default: every request).
export function rateLimit({ windowMs, max, key = (req) => req.ip, countIf }) {
  const hits = new Map();
  setInterval(() => {
    const now = Date.now();
    for (const [k, v] of hits) if (v.resetAt <= now) hits.delete(k);
  }, windowMs).unref();

  function entryFor(k, now) {
    let entry = hits.get(k);
    if (!entry || entry.resetAt <= now) {
      // Bounded memory under key spraying: drop the oldest key (Map keeps insertion order).
      if (!entry && hits.size >= MAX_KEYS) hits.delete(hits.keys().next().value);
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(k, entry);
    }
    return entry;
  }

  return (req, res, next) => {
    const k = key(req);
    if (k === undefined) return next();
    const now = Date.now();
    const entry = entryFor(k, now);
    if (entry.count >= max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return next(new AppError(429, 'RATE_LIMITED', 'Terlalu banyak percobaan. Coba lagi nanti.'));
    }
    if (countIf) res.on('finish', () => countIf(res) && entryFor(k, Date.now()).count++);
    else entry.count++;
    next();
  };
}
