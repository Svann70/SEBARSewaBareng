import { z } from 'zod';
import { SPORTS } from '../../lib/sql.js';

export const listSchema = z.object({ city: z.string().trim().min(1).max(60).optional(), sport: z.enum(SPORTS).optional() });
export const idSchema = z.object({ id: z.uuid() });
export const dateSchema = z.object({ date: z.iso.date() });
