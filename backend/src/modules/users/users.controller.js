import * as service from './users.service.js';

export function userDto(u) {
  return { id: u.id, email: u.email, fullName: u.full_name, phone: u.phone, role: u.role, reliabilityScore: u.reliability_score };
}

export async function me(req, res) {
  res.json(userDto(await service.getById(req.user.id)));
}
