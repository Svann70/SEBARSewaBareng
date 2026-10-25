import { z } from 'zod';

export const topupSchema = z.object({ amount: z.number().int().min(10_000).max(10_000_000) });
export const withdrawalSchema = z.object({
  amount: z.number().int().min(10_000).max(10_000_000),
  bankCode: z.string().trim().toUpperCase().regex(/^[A-Z0-9]{2,20}$/),
  accountNumber: z.string().trim().regex(/^[0-9]{6,25}$/),
  accountName: z.string().trim().min(2).max(80),
});
export const idempotencyKeySchema = z.string().min(8).max(100);
export const pageSchema = z.object({ page: z.coerce.number().int().min(1).max(1000).default(1) });
