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

export const createSchema = z.object({
  slotId: z.uuid(),
  title: z.string().trim().min(3).max(100),
  quota: z.number().int().min(2).max(30),
  minReliability: z.number().min(0).max(100).default(0),
});
