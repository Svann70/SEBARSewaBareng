import { z } from 'zod';

const accountRole = z.enum(['PLAYER', 'VENUE_ADMIN']);

const venueSchema = z.object({
  name: z.string().trim().min(3).max(120),
  address: z.string().trim().min(5).max(300),
  city: z.string().trim().min(2).max(60),
  description: z.string().trim().max(1000).optional(),
});

// A venue account registers its GOR in the same request, so it has a venue from the first login.
export const registerSchema = z
  .object({
    email: z.email().max(254),
    password: z.string().min(8).max(128),
    fullName: z.string().trim().min(1).max(80),
    phone: z.string().trim().regex(/^\+?[0-9]{8,15}$/).optional(),
    role: accountRole.default('PLAYER'),
    venue: venueSchema.optional(),
  })
  .refine((b) => (b.role === 'VENUE_ADMIN') === (b.venue !== undefined), {
    message: 'venue wajib diisi untuk akun VENUE_ADMIN dan tidak boleh diisi untuk PLAYER',
    path: ['venue'],
  });

// `role` is the tab the user picked in the app (Pemain / Venue); omitted = any role.
export const loginSchema = z.object({
  email: z.email(),
  password: z.string().min(1).max(128),
  role: accountRole.optional(),
});

export const refreshSchema = z.object({ refreshToken: z.string().min(20).max(200) });
