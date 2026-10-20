import { z } from 'zod';

const price = z.number().int().min(1_000).max(100_000_000);

export const idSchema = z.object({ id: z.uuid() });
export const dateSchema = z.object({ date: z.iso.date() });

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
