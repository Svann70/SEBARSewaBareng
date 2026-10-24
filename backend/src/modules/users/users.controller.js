import * as service from './users.service.js';
import { changePasswordSchema, updateMeSchema } from './users.schema.js';

export function userDto(u) {
  return { id: u.id, email: u.email, fullName: u.full_name, phone: u.phone, role: u.role, reliabilityScore: u.reliability_score };
}

export async function me(req, res) {
  res.json(userDto(await service.getById(req.user.id)));
}

export async function updateMe(req, res) {
  const body = updateMeSchema.parse(req.body);
  res.json(userDto(await service.update(req.user.id, body)));
}

// 204 on success. Every refresh token is revoked server-side, so the client must log in again.
export async function changePassword(req, res) {
  const body = changePasswordSchema.parse(req.body);
  await service.changePassword(req.user.id, body);
  res.status(204).end();
}
