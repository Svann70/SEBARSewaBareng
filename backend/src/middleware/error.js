import { ZodError } from 'zod';
import { AppError } from '../lib/errors.js';

export function notFound(_req, _res, next) {
  next(new AppError(404, 'NOT_FOUND', 'Endpoint tidak ditemukan.'));
}

// RAISE EXCEPTION 'SEBAR::<CODE>' from the Supabase functions/triggers -> HTTP status.
const DB_ERRORS = {
  LOBBY_NOT_FOUND: [404, 'Lobby tidak ditemukan.'],
  SLOT_NOT_FOUND: [404, 'Slot tidak ditemukan.'],
  FORBIDDEN: [403, 'Akses ditolak.'],
  SCORE_TOO_LOW: [403, 'Skor reputasi di bawah syarat lobby.'],
  LOBBY_FULL: [409, 'Lobby sudah penuh.'],
  INSUFFICIENT_AVAILABLE_BALANCE: [409, 'Saldo tersedia tidak cukup.'],
  SLOT_NOT_OPEN: [409, 'Slot tidak tersedia.'],
  LOBBY_NOT_CANCELLABLE: [409, 'Lobby sudah tidak bisa dibatalkan.'],
  LOBBY_LOCKED: [409, 'Lobby sudah punya peserta dan tidak bisa diubah.'],
  PRICE_MISMATCH: [409, 'Harga lobby tidak sama dengan harga slot.'],
  DEADLINE_PASSED: [410, 'Batas waktu join sudah lewat.'],
  DEADLINE_TOO_LATE: [422, 'Batas join harus paling lambat 6 jam sebelum main.'],
};

function fromDbError(err) {
  const match = err.code === 'P0001' && /^SEBAR::([A-Z_]+)$/.exec(err.message);
  const known = match && DB_ERRORS[match[1]];
  return known ? new AppError(known[0], match[1], known[1]) : null;
}

// Error format: SDD §9.3.
// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, _next) {
  let e = err;
  const dbError = fromDbError(err);
  if (dbError) {
    e = dbError;
  } else if (err instanceof ZodError) {
    e = new AppError(422, 'VALIDATION_ERROR', 'Input tidak valid.', err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })));
  } else if (err.expose && err.status >= 400 && err.status < 500) {
    // body-parser errors (bad JSON, too large, unsupported encoding).
    e = new AppError(err.status, 'VALIDATION_ERROR', 'Body tidak valid.');
  } else if (err.code === '40P01' || err.code === '40001') {
    e = new AppError(409, 'CONFLICT', 'Transaksi bentrok, coba lagi.');
  } else if (!(err instanceof AppError)) {
    console.error(JSON.stringify({ level: 'error', requestId: req.id, msg: err.message, stack: err.stack }));
    e = new AppError(500, 'INTERNAL', 'Terjadi kesalahan pada server.');
  }
  res.status(e.status).json({ error: { code: e.code, message: e.message, details: e.details, requestId: req.id } });
}
