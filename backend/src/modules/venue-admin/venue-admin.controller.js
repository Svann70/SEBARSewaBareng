import { venueSlotDto } from '../venues/slots.shared.js';
import {
  createCourtSchema,
  createSlotSchema,
  createVenueSchema,
  patchVenueSchema,
  photoParamsSchema,
  idSchema,
  patchCourtSchema,
  patchSlotSchema,
  slotsQuerySchema,
} from './venue-admin.schema.js';
import * as service from './venue-admin.service.js';

export async function listVenues(req, res) {
  res.json({ items: await service.listVenues(req.user.id) });
}

export async function createVenue(req, res) {
  res.status(201).json(await service.createVenue(req.user.id, createVenueSchema.parse(req.body)));
}

export async function updateVenue(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.updateVenue(req.user.id, id, patchVenueSchema.parse(req.body)));
}

export async function createCourt(req, res) {
  res.status(201).json(await service.createCourt(req.user.id, createCourtSchema.parse(req.body)));
}

export async function updateCourt(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(await service.updateCourt(req.user.id, id, patchCourtSchema.parse(req.body)));
}

export async function addPhoto(req, res) {
  const { id } = idSchema.parse(req.params);
  res.status(201).json(await service.addPhoto(req.user.id, id, req.body));
}

export async function deletePhoto(req, res) {
  const { id, photoId } = photoParamsSchema.parse(req.params);
  await service.deletePhoto(req.user.id, id, photoId);
  res.status(204).end();
}

export async function listSlots(req, res) {
  res.json({ items: (await service.listSlots(req.user.id, slotsQuerySchema.parse(req.query))).map(venueSlotDto) });
}

export async function createSlot(req, res) {
  res.status(201).json(venueSlotDto(await service.createSlot(req.user.id, createSlotSchema.parse(req.body))));
}

export async function updateSlot(req, res) {
  const { id } = idSchema.parse(req.params);
  res.json(venueSlotDto(await service.updateSlot(req.user.id, id, patchSlotSchema.parse(req.body))));
}
