import { z } from 'zod';
import { SPORTS } from '../../lib/sql.js';

const price = z.number().int().min(1_000).max(100_000_000);
const capacity = z.number().int().min(2).max(30);
const name = z.string().trim().min(2).max(60);

export const idSchema = z.object({ id: z.uuid() });
export const dateSchema = z.object({ date: z.iso.date() });

// Venue pertama untuk akun VENUE_ADMIN yang belum punya venue (mis. akun
// lama yang role-nya diubah manual). Batasan sama dengan venueSchema di auth.
export const createVenueSchema = z.object({
  name: z.string().trim().min(3).max(120),
  address: z.string().trim().min(5).max(300),
  city: z.string().trim().min(2).max(60),
  description: z.string().trim().max(1000).optional(),
});

// venueId opsional: tanpa itu, slot semua venue milik akun ini dikembalikan.
export const slotsQuerySchema = z.object({
  date: z.iso.date(),
  venueId: z.uuid().optional(),
});

export const createCourtSchema = z.object({
  venueId: z.uuid(),
  name,
  sport: z.enum(SPORTS),
  pricePerHour: price,
  priceWeekend: price.optional(),
  capacity,
});

export const patchCourtSchema = z
  .object({
    name: name.optional(),
    pricePerHour: price.optional(),
    priceWeekend: price.optional(),
    capacity: capacity.optional(),
    status: z.enum(['ACTIVE', 'MAINTENANCE']).optional(),
  })
  .refine((b) => Object.values(b).some((v) => v !== undefined), { message: 'Isi minimal satu field' });

export const createSlotSchema = z
  .object({
    courtId: z.uuid(),
    startAt: z.iso.datetime({ offset: true }),
    endAt: z.iso.datetime({ offset: true }),
    price,
  })
  .refine((b) => new Date(b.endAt) > new Date(b.startAt), { message: 'endAt harus setelah startAt', path: ['endAt'] })
  .refine((b) => new Date(b.endAt) - new Date(b.startAt) <= 12 * 3600_000, { message: 'Durasi maksimal 12 jam', path: ['endAt'] });

export const patchSlotSchema = z
  .object({ status: z.enum(['OPEN', 'BLOCKED']).optional(), price: price.optional() })
  .refine((b) => b.status !== undefined || b.price !== undefined, { message: 'Isi status atau price' });
