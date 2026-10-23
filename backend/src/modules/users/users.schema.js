import { z } from 'zod';

// PATCH /me: both fields optional — absent = unchanged, phone: null = clear it.
export const updateMeSchema = z
  .object({
    fullName: z.string().trim().min(1).max(80).optional(),
    phone: z
      .string()
      .trim()
      .regex(/^\+?[0-9]{8,15}$/, 'Format nomor telepon tidak sesuai.')
      .nullable()
      .optional(),
  })
  .refine((b) => b.fullName !== undefined || b.phone !== undefined, {
    message: 'Tidak ada perubahan yang dikirim.',
  });

// POST /me/password: verifikasinya memakai scrypt (dua kali), jadi di-rate-limit di routes.
export const changePasswordSchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
    newPassword: z.string().min(8).max(128),
  })
  .refine((b) => b.newPassword !== b.currentPassword, {
    message: 'Password baru harus berbeda dari password saat ini.',
    path: ['newPassword'],
  });
