import { z } from 'zod';
import { SPORTS } from '../../lib/sql.js';

const price = z.number().int().min(1_000).max(100_000_000);
const capacity = z.number().int().min(2).max(30);
const name = z.string().trim().min(2).max(60);

export const idSchema = z.object({ id: z.uuid() });
export const photoParamsSchema = z.object({ id: z.uuid(), photoId: z.uuid() });
export const dateSchema = z.object({ date: z.iso.date() });
// Ticket check-in code as typed by the venue; dashes and spaces are ignored.
export const scanSchema = z.object({ code: z.string().trim().min(1).max(40) });

// Venue pertama untuk akun VENUE_ADMIN yang belum punya venue (mis. akun
// lama yang role-nya diubah manual). Batasan sama dengan venueSchema di auth.
export const createVenueSchema = z.object({
  name: z.string().trim().min(3).max(120),
  address: z.string().trim().min(5).max(300),
  city: z.string().trim().min(2).max(60),
  description: z.string().trim().max(1000).optional(),
});

export const patchVenueSchema = createVenueSchema
  .partial()
  .refine((b) => Object.values(b).some((v) => v !== undefined), { message: 'Isi minimal satu field' });

// venueId opsional: tanpa itu, slot semua venue milik akun ini dikembalikan.
export const slotsQuerySchema = z.object({
  date: z.iso.date(),
  venueId: z.uuid().optional(),
});

// Whole hours only (the booking grid is hourly). Close may be '24:00' (midnight).
const openTime = z.string().regex(/^([01]\d|2[0-3]):00$/, 'Jam buka harus format HH:00');
const closeTime = z.string().regex(/^([01]\d|2[0-4]):00$/, 'Jam tutup harus format HH:00');

// Multi-purpose court: one physical court, several sports, a player capacity per sport.
const sports = z
  .array(z.object({ sport: z.enum(SPORTS), capacity }))
  .min(1)
  .max(SPORTS.length)
  .refine((list) => new Set(list.map((x) => x.sport)).size === list.length, { message: 'Olahraga tidak boleh dobel' });

const hoursInOrder = (b) => !b.openTime || !b.closeTime || b.closeTime > b.openTime;
const hoursMessage = { message: 'Jam tutup harus setelah jam buka', path: ['closeTime'] };

// `sport` + `capacity` is the old single-sport form; it becomes a one-item `sports` list.
export const createCourtSchema = z
  .object({
    venueId: z.uuid(),
    name,
    sports: sports.optional(),
    sport: z.enum(SPORTS).optional(),
    capacity: capacity.optional(),
    pricePerHour: price,
    priceWeekend: price.nullable().optional(),
    openTime: openTime.default('06:00'),
    closeTime: closeTime.default('22:00'),
  })
  .refine((b) => b.sports || (b.sport && b.capacity), { message: 'Isi olahraga dan kapasitas', path: ['sports'] })
  .refine(hoursInOrder, hoursMessage)
  .transform(({ sport, capacity: cap, ...b }) => ({ ...b, sports: b.sports ?? [{ sport, capacity: cap }] }));

export const patchCourtSchema = z
  .object({
    name: name.optional(),
    sports: sports.optional(),
    pricePerHour: price.optional(),
    priceWeekend: price.nullable().optional(),
    capacity: capacity.optional(),
    openTime: openTime.optional(),
    closeTime: closeTime.optional(),
    status: z.enum(['ACTIVE', 'MAINTENANCE']).optional(),
  })
  .refine((b) => Object.values(b).some((v) => v !== undefined), { message: 'Isi minimal satu field' })
  .refine(hoursInOrder, hoursMessage);

export const createSlotSchema = z
  .object({
    courtId: z.uuid(),
    startAt: z.iso.datetime({ offset: true }),
    endAt: z.iso.datetime({ offset: true }),
    price,
    // BLOCKED = owner closes these hours (maintenance, private use) so no room can take them.
    status: z.enum(['OPEN', 'BLOCKED']).default('OPEN'),
  })
  .refine((b) => new Date(b.endAt) > new Date(b.startAt), { message: 'endAt harus setelah startAt', path: ['endAt'] })
  .refine((b) => new Date(b.endAt) - new Date(b.startAt) <= 12 * 3600_000, { message: 'Durasi maksimal 12 jam', path: ['endAt'] });

export const patchSlotSchema = z
  .object({ status: z.enum(['OPEN', 'BLOCKED']).optional(), price: price.optional() })
  .refine((b) => b.status !== undefined || b.price !== undefined, { message: 'Isi status atau price' });
