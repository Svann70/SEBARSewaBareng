import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';

// Access token. Refresh tokens are opaque random strings (see modules/auth), never JWTs.
export function signToken(userId) {
  return jwt.sign({}, config.jwtSecret, { subject: userId, expiresIn: config.jwtExpiresIn, algorithm: 'HS256' });
}

// Throws on invalid or expired tokens.
export function verifyToken(token) {
  return jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
}
