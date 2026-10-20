import { dateSchema, idSchema, listSchema } from './venues.schema.js';
import * as service from './venues.service.js';
import { slotDto } from './slots.shared.js';

export async function list(req, res) {
  const rows = await service.list(listSchema.parse(req.query));
  res.json({ items: rows.map(({ photo_url, ...v }) => ({ ...v, photoUrl: photo_url })) });
}

export async function listSlots(req, res) {
  const { id } = idSchema.parse(req.params);
  const { date } = dateSchema.parse(req.query);
  res.json({ items: (await service.listSlots(id, date)).map(slotDto) });
}
