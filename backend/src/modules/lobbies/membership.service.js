// Lobby membership. The money rules live in the Supabase DB, not here:
//   INSERT lobby_members        -> trg_member_hold: score/deadline checks, wallet_hold, confirm_lobby when full
//   UPDATE status = 'CANCELLED' -> trg_member_cancel: release (>= 6h) or 50% penalty (< 6h)
//   cancel_lobby_by_host()      -> release everyone, host -15
//   expire_stale_lobbies()      -> release holds of lobbies past their deadline
// This layer adds the checks the DB does not do and turns the results into API responses.
import { AppError } from '../../lib/errors.js';

export const JOIN_CUTOFF_HOURS = 6;
const ACTIVE_MEMBER = `status IN ('HOLDING', 'CONFIRMED')`;

// All functions take a client inside an open transaction.

async function lockLobby(c, lobbyId) {
  // Deadline is compared with the DB clock, same as the triggers and the expiry job.
  const { rows } = await c.query('SELECT *, join_deadline <= now() AS deadline_passed FROM lobbies WHERE id = $1 FOR UPDATE', [lobbyId]);
  if (!rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lobby tidak ditemukan.');
  return rows[0];
}

// confirm_lobby and cancel_lobby_by_host lock member wallets in table order, which can deadlock
// against another lobby doing the same. Locking them here first, in id order, prevents that.
async function lockWallets(c, userIds) {
  await c.query('SELECT 1 FROM wallets WHERE user_id = ANY($1::uuid[]) ORDER BY id FOR UPDATE', [userIds]);
}

async function holdingUserIds(c, lobbyId) {
  const { rows } = await c.query(`SELECT user_id FROM lobby_members WHERE lobby_id = $1 AND status = 'HOLDING'`, [lobbyId]);
  return rows.map((r) => r.user_id);
}

async function bookingOf(c, lobbyId) {
  const { rows } = await c.query('SELECT * FROM bookings WHERE lobby_id = $1', [lobbyId]);
  return rows[0] ?? null;
}

// Join = insert a member row; the DB trigger holds the money and books the slot when the quota fills.
// The lobby row lock makes concurrent joins queue, so the quota can never be overshot.
export async function joinLobby(c, lobbyId, userId, role = 'PLAYER') {
  const lobby = await lockLobby(c, lobbyId);

  const existing = await c.query('SELECT * FROM lobby_members WHERE lobby_id = $1 AND user_id = $2', [lobbyId, userId]);
  const member = existing.rows[0];
  // Retrying a successful join returns the same membership (BR-2.3).
  if (member && ['HOLDING', 'CONFIRMED'].includes(member.status)) {
    return { member, created: false, booking: member.status === 'CONFIRMED' ? await bookingOf(c, lobbyId) : null };
  }
  if (lobby.status !== 'OPEN') throw new AppError(409, 'LOBBY_FULL', 'Lobby sudah penuh atau tidak aktif.');
  if (lobby.deadline_passed) throw new AppError(410, 'DEADLINE_PASSED', 'Batas waktu join sudah lewat.');
  // One row per (lobby, user) and the hold trigger only fires on INSERT, so leaving is final.
  if (member) throw new AppError(409, 'ALREADY_JOINED', 'Kamu sudah pernah keluar dari lobby ini dan tidak bisa join lagi.');
  const count = await c.query(`SELECT count(*)::int AS n FROM lobby_members WHERE lobby_id = $1 AND ${ACTIVE_MEMBER}`, [lobbyId]);
  if (count.rows[0].n >= lobby.quota) throw new AppError(409, 'LOBBY_FULL', 'Lobby sudah penuh.');

  const filling = count.rows[0].n + 1 === lobby.quota;
  await lockWallets(c, filling ? [userId, ...(await holdingUserIds(c, lobbyId))] : [userId]);

  const { rows } = await c.query(
    `INSERT INTO lobby_members (lobby_id, user_id, role_in_lobby, hold_amount) VALUES ($1, $2, $3, $4) RETURNING id`,
    [lobbyId, userId, role, lobby.price_per_person],
  );
  // Re-read: the trigger set hold_ledger_id and, on a filling join, CONFIRMED.
  const saved = await c.query('SELECT * FROM lobby_members WHERE id = $1', [rows[0].id]);
  return { member: saved.rows[0], created: true, booking: filling ? await bookingOf(c, lobbyId) : null };
}

// Leaving is only allowed while the lobby is open and before the deadline (>= 6h before start),
// so trg_member_cancel always takes the full-release path. Cancelling a confirmed booking is v2.
export async function leaveLobby(c, lobbyId, userId) {
  const lobby = await lockLobby(c, lobbyId);
  const { rows } = await c.query(
    `SELECT * FROM lobby_members WHERE lobby_id = $1 AND user_id = $2 AND ${ACTIVE_MEMBER}`,
    [lobbyId, userId],
  );
  const member = rows[0];
  if (!member) throw new AppError(404, 'NOT_FOUND', 'Kamu bukan peserta lobby ini.');
  if (member.status === 'CONFIRMED' || lobby.status !== 'OPEN') {
    throw new AppError(409, 'CONFLICT', 'Lobby sudah terkonfirmasi; pembatalan belum didukung di v1.');
  }
  if (lobby.host_id === userId) throw new AppError(409, 'CONFLICT', 'Host tidak bisa keluar; batalkan lobby.');
  // Past the deadline the expiry job refunds everyone; a late leave would fall inside the 6-hour penalty zone.
  if (lobby.deadline_passed) throw new AppError(410, 'DEADLINE_PASSED', 'Batas waktu sudah lewat.');
  await c.query(`UPDATE lobby_members SET status = 'CANCELLED' WHERE id = $1`, [member.id]);
  return { released: member.hold_amount };
}

// US-16: host cancels; cancel_lobby_by_host refunds everyone 100% and costs the host 15 points.
export async function cancelLobby(c, lobbyId, userId) {
  const lobby = await lockLobby(c, lobbyId);
  if (lobby.host_id !== userId) throw new AppError(403, 'FORBIDDEN', 'Hanya host yang bisa membatalkan lobby.');
  if (lobby.status !== 'OPEN') throw new AppError(409, 'CONFLICT', 'Lobby sudah tidak bisa dibatalkan.');
  // Past the deadline the expiry job refunds everyone without a penalty; do not charge the host for it.
  if (lobby.deadline_passed) throw new AppError(410, 'DEADLINE_PASSED', 'Lobby sudah lewat batas waktu dan akan kedaluwarsa.');
  const holders = await holdingUserIds(c, lobbyId);
  await lockWallets(c, holders);
  await c.query('SELECT cancel_lobby_by_host($1, $2)', [lobbyId, userId]);
  return { refundedMembers: holders.length };
}

// BR-3.4: returns how many lobbies the DB function expired (or confirmed, when they were full).
// The function walks wallets in member order across many lobbies, so lock them all in id order first.
export async function expireStaleLobbies(c) {
  await c.query(
    `SELECT 1 FROM wallets WHERE user_id IN (
       SELECT m.user_id FROM lobby_members m JOIN lobbies l ON l.id = m.lobby_id
        WHERE l.status = 'OPEN' AND l.join_deadline < now() AND m.status = 'HOLDING')
     ORDER BY id FOR UPDATE`,
  );
  const { rows } = await c.query('SELECT expire_stale_lobbies() AS n');
  return rows[0].n;
}
