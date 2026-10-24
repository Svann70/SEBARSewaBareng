import { z } from 'zod';
import { SPORTS } from '../../lib/sql.js';

export const idSchema = z.object({ id: z.uuid() });

export const listSchema = z.object({
  city: z.string().trim().min(1).max(60).optional(),
  sport: z.enum(SPORTS).optional(),
  date: z.iso.date().optional(),
  minScore: z.coerce.number().min(0).max(100).optional(),
  page: z.coerce.number().int().min(1).max(1000).default(1),
});

// Two ways to pick the time: an existing slot (`slotId`), or any free hour inside the court's
// opening hours (`courtId` + `startAt` + `hours`), for which the slot is created with the room.
export const createSchema = z
  .object({
    slotId: z.uuid().optional(),
    courtId: z.uuid().optional(),
    startAt: z.iso.datetime({ offset: true }).optional(),
    hours: z.number().int().min(1).max(3).optional(),
    sport: z.enum(SPORTS).optional(),
    title: z.string().trim().min(3).max(100),
    quota: z.number().int().min(2).max(30),
    minReliability: z.number().min(0).max(100).default(0),
  })
  .refine((b) => (b.slotId ? !b.courtId : b.courtId && b.startAt && b.hours), {
    message: 'Isi slotId, atau courtId + startAt + hours',
    path: ['slotId'],
  });
