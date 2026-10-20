import { slotDto } from '../venues/slots.shared.js';
import { createSlotSchema, dateSchema, idSchema, patchSlotSchema } from './venue-admin.schema.js';
import * as service from './venue-admin.service.js';

export async function listVenues(req, res) {
  res.json({ items: await service.listVenues(req.user.id) });
}

export async function listSlots(req, res) {
  const { date } = dateSchema.parse(req.query);
  res.json({ items: (await service.listSlots(req.user.id, date)).map(slotDto) });
}

export async function createSlot(req, res) {
  res.status(201).json(slotDto(await service.createSlot(req.user.id, createSlotSchema.parse(req.body))));
}

export async function updateSlot(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(slotDto(await service.updateSlot(req.user.id, id, patchSlotSchema.parse(req.body))));
}
