import { slotDto } from '../venues/slots.shared.js';
import {
  createCourtSchema,
  createSlotSchema,
  idSchema,
  patchCourtSchema,
  patchSlotSchema,
  slotsQuerySchema,
} from './venue-admin.schema.js';
import * as service from './venue-admin.service.js';

export async function listVenues(req, res) {
  res.json({ items: await service.listVenues(req.user.id) });
}

export async function createCourt(req, res) {
  res.status(201).json(await service.createCourt(req.user.id, createCourtSchema.parse(req.body)));
}

export async function updateCourt(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.updateCourt(req.user.id, id, patchCourtSchema.parse(req.body)));
}

export async function listSlots(req, res) {
  res.json({ items: (await service.listSlots(req.user.id, slotsQuerySchema.parse(req.query))).map(slotDto) });
}

export async function createSlot(req, res) {
  res.status(201).json(slotDto(await service.createSlot(req.user.id, createSlotSchema.parse(req.body))));
}

export async function updateSlot(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(slotDto(await service.updateSlot(req.user.id, id, patchSlotSchema.parse(req.body))));
}
