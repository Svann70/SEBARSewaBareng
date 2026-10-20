import crypto from 'node:crypto';

export function requestId(req, res, next) {
  req.id = `req_${crypto.randomUUID()}`;
  res.set('X-Request-Id', req.id);
  next();
}
