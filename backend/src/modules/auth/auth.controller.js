import { config } from '../../config/env.js';
import { userDto } from '../users/users.controller.js';
import { loginSchema, refreshSchema, registerSchema } from './auth.schema.js';
import * as service from './auth.service.js';

function tokensDto(t) {
  return {
    accessToken: t.accessToken,
    accessExpiresIn: config.jwtExpiresIn,
    refreshToken: t.refreshToken,
    refreshExpiresAt: t.refreshExpiresAt,
  };
}

// Tokens must not be stored by any intermediary cache.
const noStore = (res) => res.set('Cache-Control', 'no-store');

export async function register(req, res) {
  const { user, tokens } = await service.register(registerSchema.parse(req.body));
  noStore(res).status(201).json({ ...tokensDto(tokens), user: userDto(user) });
}

export async function login(req, res) {
  const { user, tokens } = await service.login(loginSchema.parse(req.body));
  noStore(res).json({ ...tokensDto(tokens), user: userDto(user) });
}

export async function refresh(req, res) {
  const { refreshToken } = refreshSchema.parse(req.body);
  noStore(res).json(tokensDto(await service.refresh(refreshToken)));
}

// Idempotent: a malformed, unknown or already revoked token still answers 204.
export async function logout(req, res) {
  const parsed = refreshSchema.safeParse(req.body);
  if (parsed.success) await service.logout(parsed.data.refreshToken);
  res.status(204).end();
}
