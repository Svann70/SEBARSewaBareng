// Patungan v2 money rules (backend/PATUNGAN_V2.md, business rules in revisi/aturan-patungan-v2.md).
// Every function takes a client inside an open transaction and moves money only through the DB
// primitives wallet_hold / wallet_release / wallet_capture / wallet_credit (one ledger row each).
//
// Seats = members with status ACTIVE, VACANT (left after the free period, waiting for a replacement)
// or ABSENT (paid, not playing). n = number of seats, share = floor(P / n); the creator's seat pays
// the remainder. The creator holds the full price P until join closes (guarantee), then pays whatever
// the other seats did not cover.
import { AppError } from '../../lib/errors.js';

export const JOIN_CLOSE_MINUTES = 30;
export const FINE = 10_000;
const SEAT = `status IN ('ACTIVE', 'VACANT', 'ABSENT')`;
const MATCH_DAY_SQL = `now() >= ((s.start_at AT TIME ZONE 'Asia/Jakarta')::date::timestamp AT TIME ZONE 'Asia/Jakarta')`;

export const shareOf = (price, seats) => Math.floor(price / Math.max(seats, 1));

// ── Wallet primitives ────────────────────────────────────────────────────────

const hold = (c, userId, amount, lobbyId) =>
  c.query(`SELECT wallet_hold($1, $2, 'LOBBY', $3)`, [userId, amount, lobbyId]);
const release = (c, userId, amount, lobbyId) =>
  amount > 0 && c.query(`SELECT wallet_release($1, $2, 'LOBBY', $3)`, [userId, amount, lobbyId]);
const capture = (c, userId, amount, lobbyId, type = 'CAPTURE') =>
  amount > 0 && c.query(`SELECT wallet_capture($1, $2, 'LOBBY', $3, $4)`, [userId, amount, lobbyId, type]);
const credit = (c, userId, amount, lobbyId) =>
  amount > 0 && c.query(`SELECT wallet_credit($1, $2, 'LOBBY', $3)`, [userId, amount, lobbyId]);

// Wallet functions lock rows one by one; locking every wallet involved first, in id order, avoids
// deadlocks between two transactions that touch the same people in a different order.
async function lockWallets(c, userIds) {
  await c.query('SELECT 1 FROM wallets WHERE user_id = ANY($1::uuid[]) ORDER BY id FOR UPDATE', [[...new Set(userIds)]]);
}

async function notify(c, userIds, type, payload) {
  const ids = [...new Set(userIds)];
  if (!ids.length) return;
  await c.query(
    `INSERT INTO notifications (user_id, type, payload) SELECT unnest($1::uuid[]), $2, $3`,
    [ids, type, JSON.stringify(payload)],
  );
}

const isInsufficient = (err) => err.code === 'P0001' && err.message === 'SEBAR::INSUFFICIENT_AVAILABLE_BALANCE';

// ── Reads ────────────────────────────────────────────────────────────────────

// Lobby row lock plus the clock facts every rule needs, all from the DB clock.
async function lockLobbyRow(c, lobbyId) {
  const { rows } = await c.query(
    `SELECT l.*, s.start_at, s.end_at,
            l.join_deadline <= now() AS closed,
            ${MATCH_DAY_SQL} AS match_day,
            now() < l.created_at + interval '2 hours' AS host_free,
            s.end_at <= now() AS finished
       FROM lobbies l JOIN court_slots s ON s.id = l.slot_id
      WHERE l.id = $1 FOR UPDATE OF l`,
    [lobbyId],
  );
  const lobby = rows[0];
  if (!lobby) throw new AppError(404, 'NOT_FOUND', 'Room tidak ditemukan.');
  lobby.price = Number(lobby.price_total);
  return lobby;
}

async function lockSeats(c, lobbyId) {
  const { rows } = await c.query(
    `SELECT *, hold_amount::float8 AS held, share_at_join::float8 AS joined_share,
            free_until > now() AS in_free, protect_until > now() AS protected
       FROM lobby_members WHERE lobby_id = $1 AND ${SEAT}
      ORDER BY joined_at, id FOR UPDATE`,
    [lobbyId],
  );
  return rows;
}

async function myRow(c, lobbyId, userId) {
  const { rows } = await c.query(
    `SELECT *, hold_amount::float8 AS held, free_until > now() AS in_free, protect_until > now() AS protected
       FROM lobby_members WHERE lobby_id = $1 AND user_id = $2 AND status = 'ACTIVE' FOR UPDATE`,
    [lobbyId, userId],
  );
  return rows[0];
}

const setHeld = (c, memberId, amount) =>
  c.query('UPDATE lobby_members SET hold_amount = $2 WHERE id = $1', [memberId, amount]);

// ── Share changes ────────────────────────────────────────────────────────────

// After the number of seats changed. A lower share refunds nothing yet: every seat keeps holding at
// least what it agreed to at join, and the difference comes back when join closes (closeLobby), so it
// cannot be withdrawn and then left uncovered. A share above that needs more money: if the wallet
// cannot cover it, the member is taken out with a full refund (they may leave for free anyway), which
// can raise the share again, hence the loop. The host guarantee never pays for a member.
async function rebalance(c, lobby, { protect = false } = {}) {
  for (;;) {
    const seats = await lockSeats(c, lobby.id);
    const share = shareOf(lobby.price, seats.length);
    await lockWallets(c, seats.filter((m) => m.user_id !== lobby.creator_id).map((m) => m.user_id));
    let removed = false;
    for (const m of seats) {
      if (m.user_id === lobby.creator_id || m.status !== 'ACTIVE') continue;
      if (m.held < share) {
        await c.query('SAVEPOINT topup');
        try {
          await hold(c, m.user_id, share - m.held, lobby.id);
          await c.query('RELEASE SAVEPOINT topup');
          await setHeld(c, m.id, share);
        } catch (err) {
          if (!isInsufficient(err)) throw err;
          await c.query('ROLLBACK TO SAVEPOINT topup');
          await release(c, m.user_id, m.held, lobby.id);
          await c.query(`UPDATE lobby_members SET status = 'LEFT', hold_amount = 0, cancelled_at = now() WHERE id = $1`, [m.id]);
          await notify(c, [m.user_id], 'AUTO_LEFT', { lobbyId: lobby.id, share, refund: m.held });
          removed = true;
          continue;
        }
      }
    }
    if (removed) {
      protect = true;
      continue;
    }
    // Final share known: protection windows and notifications are set once, at this share.
    for (const m of seats) {
      if (m.user_id === lobby.creator_id || m.status !== 'ACTIVE') continue;
      // A protection window only lasts while the share stays above what the member agreed to at join.
      if (m.protected && share <= m.joined_share) {
        await c.query('UPDATE lobby_members SET protect_until = NULL WHERE id = $1', [m.id]);
      }
      // Share above what this member agreed to at join: 30 minutes (or until join closes) to leave for free.
      if (protect && m.user_id !== lobby.host_id && !m.in_free && share > m.joined_share) {
        const { rows } = await c.query(
          `UPDATE lobby_members SET protect_until = LEAST(now() + interval '30 minutes', $2) WHERE id = $1 RETURNING protect_until`,
          [m.id, lobby.join_deadline],
        );
        await notify(c, [m.user_id], 'SHARE_PROTECTION', { lobbyId: lobby.id, share, until: rows[0].protect_until });
      }
    }
    const active = seats.filter((m) => m.status === 'ACTIVE').map((m) => m.user_id);
    await notify(c, active, 'SHARE_CHANGED', { lobbyId: lobby.id, share, seats: seats.length });
    // A handed-over host may have been taken out above.
    await handOverHost(c, lobby);
    return { seats: seats.length, share };
  }
}

// ── Create ───────────────────────────────────────────────────────────────────

// Host seat of a new room: the creator holds the full price as the guarantee.
export async function addHost(c, lobby, userId) {
  const price = Number(lobby.price_total);
  await hold(c, userId, price, lobby.id);
  await c.query(
    `INSERT INTO lobby_members (lobby_id, user_id, role_in_lobby, status, hold_amount, share_at_join)
     VALUES ($1, $2, 'HOST', 'ACTIVE', $3, $3)`,
    [lobby.id, userId, price],
  );
}

// ── Join ─────────────────────────────────────────────────────────────────────

// What joining costs right now: the share of a vacant seat, or the share with one more seat.
export function joinCost(price, seats, vacant, quota) {
  if (vacant > 0) return shareOf(price, seats);
  return seats < quota ? shareOf(price, seats + 1) : null;
}

export async function joinLobby(c, lobbyId, userId) {
  const lobby = await lockLobbyRow(c, lobbyId);
  const { rows: mine } = await c.query(
    `SELECT *, cancelled_at > now() - interval '10 minutes' AS cooling
       FROM lobby_members WHERE lobby_id = $1 AND user_id = $2 ORDER BY joined_at DESC`,
    [lobbyId, userId],
  );
  const current = mine.find((m) => m.status === 'ACTIVE');
  // Retrying a successful join returns the same seat (BR-2.3), even when that join filled and locked the room.
  if (current) return { member: current, created: false };
  if (lobby.status !== 'OPEN') throw new AppError(409, 'LOBBY_FULL', 'Room sudah tidak menerima anggota.');
  if (lobby.closed) throw new AppError(410, 'DEADLINE_PASSED', 'Join sudah ditutup.');
  if (mine.some((m) => m.status === 'VACANT' || m.status === 'ABSENT')) {
    throw new AppError(409, 'ALREADY_JOINED', 'Kamu sudah keluar dari room ini; kursimu menunggu pengganti.');
  }
  if (mine.some((m) => m.cooling)) {
    throw new AppError(409, 'COOLDOWN', 'Kamu baru keluar dari room ini. Coba lagi setelah 10 menit.');
  }
  const user = await c.query('SELECT reliability_score FROM users WHERE id = $1', [userId]);
  if (Number(user.rows[0].reliability_score) < Number(lobby.min_reliability)) {
    throw new AppError(403, 'SCORE_TOO_LOW', 'Skor keandalanmu di bawah syarat room ini.');
  }

  const seats = await lockSeats(c, lobbyId);
  // Oldest vacant seat first: the joiner replaces it and nobody else's share changes.
  const vacant = seats
    .filter((m) => m.status === 'VACANT')
    .sort((a, b) => a.cancelled_at - b.cancelled_at)[0];
  if (!vacant && seats.length >= lobby.quota) throw new AppError(409, 'LOBBY_FULL', 'Room sudah penuh.');

  const share = shareOf(lobby.price, vacant ? seats.length : seats.length + 1);
  // Every seat, creator included: a join that fills the room closes it in this transaction.
  await lockWallets(c, [userId, ...seats.map((m) => m.user_id)]);
  await hold(c, userId, share, lobbyId);
  // A replacement takes a seat that is already locked, so it gets no free period.
  const { rows } = await c.query(
    `INSERT INTO lobby_members (lobby_id, user_id, role_in_lobby, status, hold_amount, share_at_join, free_until)
     VALUES ($1, $2, 'PLAYER', 'ACTIVE', $3, $3, CASE WHEN $5 THEN now() ELSE LEAST(now() + interval '2 hours', $4) END)
     RETURNING *`,
    [lobbyId, userId, share, lobby.join_deadline, Boolean(vacant)],
  );

  // Joined again after being kicked: the old kick no longer counts for the disband fine.
  await c.query('UPDATE lobby_members SET kicked = false WHERE lobby_id = $1 AND user_id = $2 AND kicked', [lobbyId, userId]);
  if (vacant) {
    // Replaced: refund minus the fine; the fine stays held until the room finishes.
    const fine = Math.min(FINE, vacant.held);
    await release(c, vacant.user_id, vacant.held - fine, lobbyId);
    await c.query(
      `UPDATE lobby_members SET status = 'REPLACED', hold_amount = $2, fine_amount = $2 WHERE id = $1`,
      [vacant.id, fine],
    );
    await notify(c, [vacant.user_id], 'REPLACED', { lobbyId, refund: vacant.held - fine, fine });
  } else {
    await rebalance(c, lobby);
  }
  // The host left on match day while alone: the first one to join takes over.
  await handOverHost(c, lobby);
  return { member: rows[0], created: true };
}

// Host locks the room before the deadline (rule 4.3): join closes now and tickets are issued.
export async function lockLobby(c, lobbyId, hostId) {
  const lobby = await lockLobbyRow(c, lobbyId);
  if (lobby.host_id !== hostId || !(await myRow(c, lobbyId, hostId))) {
    throw new AppError(403, 'FORBIDDEN', 'Hanya host yang bisa mengunci room.');
  }
  if (lobby.status !== 'OPEN' || lobby.closed) throw new AppError(410, 'DEADLINE_PASSED', 'Join sudah ditutup.');
  await closeLobby(c, lobbyId, { early: true });
  return { locked: true };
}

// Host rights go to the earliest-joined ACTIVE member when the host's own seat is no longer active
// (left on match day, or a handed-over host taken out by rebalance). Reads host_id fresh: an earlier
// hand-over in the same transaction may have changed it.
async function handOverHost(c, lobby) {
  const current = await c.query('SELECT host_id FROM lobbies WHERE id = $1', [lobby.id]);
  const hostId = current.rows[0].host_id;
  const { rows } = await c.query(
    `SELECT h.id AS host_row, n.id AS next_row, n.user_id AS next_user
       FROM lobby_members h
       JOIN LATERAL (SELECT id, user_id FROM lobby_members WHERE lobby_id = $1 AND status = 'ACTIVE'
                      ORDER BY joined_at, id LIMIT 1) n ON true
      WHERE h.lobby_id = $1 AND h.user_id = $2 AND h.status IN ('ABSENT', 'LEFT') AND h.role_in_lobby = 'HOST'
      ORDER BY h.joined_at DESC LIMIT 1`,
    [lobby.id, hostId],
  );
  const next = rows[0];
  if (!next) return;
  await c.query(`UPDATE lobby_members SET role_in_lobby = 'PLAYER' WHERE id = $1`, [next.host_row]);
  await c.query(`UPDATE lobby_members SET role_in_lobby = 'HOST' WHERE id = $1`, [next.next_row]);
  await c.query('UPDATE lobbies SET host_id = $2 WHERE id = $1', [lobby.id, next.next_user]);
  lobby.host_id = next.next_user;
  await notify(c, [next.next_user], 'HOST_TRANSFERRED', { lobbyId: lobby.id });
}

// ── Leave / kick ─────────────────────────────────────────────────────────────

// Leaving depends on the member's phase: free (or protected) = full refund; locked = vacant seat;
// after join closed = no refund. The host can only leave on match day (otherwise: disband).
export async function leaveLobby(c, lobbyId, userId) {
  const lobby = await lockLobbyRow(c, lobbyId);
  if (!['OPEN', 'CONFIRMED'].includes(lobby.status) || lobby.finished) {
    throw new AppError(409, 'CONFLICT', 'Room sudah selesai atau dibatalkan.');
  }
  const m = await myRow(c, lobbyId, userId);
  if (!m) throw new AppError(404, 'NOT_FOUND', 'Kamu bukan anggota room ini.');

  const absent = () => c.query(`UPDATE lobby_members SET status = 'ABSENT', cancelled_at = now() WHERE id = $1`, [m.id]);

  if (userId === lobby.host_id) {
    if (!lobby.match_day && lobby.status === 'OPEN' && !lobby.closed) {
      throw new AppError(409, 'HOST_MUST_DISBAND', 'Host tidak bisa keluar sebelum hari H. Bubarkan room bila perlu.');
    }
    await absent();
    await handOverHost(c, lobby);
    return { phase: 'HOST_MATCH_DAY', refund: 0 };
  }

  if (lobby.status === 'CONFIRMED' || lobby.closed) {
    await absent();
    return { phase: 'FINAL', refund: 0 };
  }
  const seatCount = (await lockSeats(c, lobbyId)).length;
  const stillProtected = m.protected && shareOf(lobby.price, seatCount) > Number(m.share_at_join);
  if (m.in_free || stillProtected) {
    // Every wallet rebalance may touch, in one id-ordered lock, before the first wallet call.
    await lockWallets(c, (await lockSeats(c, lobbyId)).map((s) => s.user_id));
    await release(c, userId, m.held, lobbyId);
    await c.query(`UPDATE lobby_members SET status = 'LEFT', hold_amount = 0, cancelled_at = now() WHERE id = $1`, [m.id]);
    await rebalance(c, lobby, { protect: true });
    return { phase: m.in_free ? 'FREE' : 'PROTECTED', refund: m.held };
  }
  await c.query(`UPDATE lobby_members SET status = 'VACANT', cancelled_at = now() WHERE id = $1`, [m.id]);
  return { phase: 'LOCKED', refund: 0, fineIfReplaced: Math.min(FINE, m.held) };
}

export async function kickMember(c, lobbyId, hostId, targetId) {
  const lobby = await lockLobbyRow(c, lobbyId);
  if (lobby.host_id !== hostId || !(await myRow(c, lobbyId, hostId))) {
    throw new AppError(403, 'FORBIDDEN', 'Hanya host yang bisa mengeluarkan anggota.');
  }
  if (lobby.status !== 'OPEN' || lobby.closed) throw new AppError(410, 'DEADLINE_PASSED', 'Join sudah ditutup.');
  if (targetId === hostId) throw new AppError(409, 'CONFLICT', 'Host tidak bisa mengeluarkan dirinya sendiri.');
  const m = await myRow(c, lobbyId, targetId);
  if (!m) throw new AppError(404, 'NOT_FOUND', 'Anggota tidak ditemukan.');

  await lockWallets(c, (await lockSeats(c, lobbyId)).map((s) => s.user_id));
  await release(c, targetId, m.held, lobbyId);
  await c.query(`UPDATE lobby_members SET status = 'LEFT', hold_amount = 0, cancelled_at = now(), kicked = true WHERE id = $1`, [m.id]);
  await notify(c, [targetId], 'KICKED', { lobbyId, refund: m.held });
  await rebalance(c, lobby, { protect: true });
  return { refund: m.held };
}

// ── Disband ──────────────────────────────────────────────────────────────────

// Host disbands until H-1 23:59 WIB. Free in the first 2 hours or when no other member is left;
// otherwise the fine = host's share: half to the venue owner's wallet, half split over the members
// (remainder to the venue). Everyone else, vacant seats and held fines get their money back.
export async function disbandLobby(c, lobbyId, hostId) {
  const lobby = await lockLobbyRow(c, lobbyId);
  if (lobby.host_id !== hostId) throw new AppError(403, 'FORBIDDEN', 'Hanya host yang bisa membubarkan room.');
  if (lobby.status !== 'OPEN') throw new AppError(409, 'CONFLICT', 'Room sudah tidak bisa dibubarkan.');
  if (lobby.match_day) throw new AppError(409, 'MATCH_DAY', 'Di hari H room tidak bisa dibubarkan.');

  const seats = await lockSeats(c, lobbyId);
  const { rows: fined } = await c.query(
    `SELECT *, hold_amount::float8 AS held FROM lobby_members WHERE lobby_id = $1 AND status = 'REPLACED' AND hold_amount > 0 FOR UPDATE`,
    [lobbyId],
  );
  // Kicked members count too, so kicking everyone first does not make disbanding free.
  const { rows: kicked } = await c.query(
    `SELECT user_id FROM lobby_members WHERE lobby_id = $1 AND kicked AND user_id <> ALL($2::uuid[])`,
    [lobbyId, seats.map((m) => m.user_id)],
  );
  const members = [
    ...seats.filter((m) => m.status === 'ACTIVE' && m.user_id !== lobby.creator_id).map((m) => m.user_id),
    ...new Set(kicked.map((k) => k.user_id)),
  ];
  const fine = lobby.host_free || !members.length ? 0 : lobby.price - shareOf(lobby.price, seats.length) * (seats.length - 1);
  const venue = await c.query(
    `SELECT v.owner_id FROM court_slots s JOIN courts ct ON ct.id = s.court_id JOIN venues v ON v.id = ct.venue_id WHERE s.id = $1`,
    [lobby.slot_id],
  );
  const owner = venue.rows[0].owner_id;
  await lockWallets(c, [...seats.map((m) => m.user_id), ...fined.map((m) => m.user_id), ...members, owner]);

  for (const m of [...seats, ...fined]) {
    if (m.user_id === lobby.creator_id) continue;
    await release(c, m.user_id, m.held, lobbyId);
    await c.query(
      `UPDATE lobby_members SET status = 'REFUNDED', hold_amount = 0, cancelled_at = COALESCE(cancelled_at, now()) WHERE id = $1`,
      [m.id],
    );
  }
  const creator = seats.find((m) => m.user_id === lobby.creator_id);
  await capture(c, creator.user_id, fine, lobbyId, 'PENALTY');
  await release(c, creator.user_id, creator.held - fine, lobbyId);
  await c.query(`UPDATE lobby_members SET status = 'REFUNDED', hold_amount = 0, cancelled_at = now() WHERE id = $1`, [creator.id]);

  let each = 0;
  if (fine > 0) {
    each = Math.floor(Math.floor(fine / 2) / members.length);
    for (const id of members) await credit(c, id, each, lobbyId);
    await credit(c, owner, fine - each * members.length, lobbyId);
  }
  await c.query(`UPDATE lobbies SET status = 'CANCELLED' WHERE id = $1`, [lobbyId]);
  const told = [...seats, ...fined].map((m) => m.user_id).filter((id) => id !== hostId && !members.includes(id));
  await notify(c, told, 'LOBBY_CANCELLED', { lobbyId, title: lobby.title, compensation: 0 });
  await notify(c, members, 'LOBBY_CANCELLED', { lobbyId, title: lobby.title, compensation: each });
  return { fine, compensationEach: each, refundedMembers: seats.length - 1 + fined.length };
}

// ── Scheduled jobs ───────────────────────────────────────────────────────────

// Join closed (deadline passed, or `early` when the host locks the room): vacant seats are forfeited,
// every seat pays its share (capped by what it holds), the creator pays the rest of P, and the
// booking + venue payout are created.
export async function closeLobby(c, lobbyId, { early = false } = {}) {
  const lobby = await lockLobbyRow(c, lobbyId);
  if (lobby.status !== 'OPEN' || (!lobby.closed && !early)) return false;
  // Locked before the deadline: join is closed now, so free periods and protection end here too.
  if (!lobby.closed) await c.query('UPDATE lobbies SET join_deadline = now() WHERE id = $1', [lobbyId]);
  const seats = await lockSeats(c, lobbyId);
  const share = shareOf(lobby.price, seats.length);
  await lockWallets(c, seats.map((m) => m.user_id));

  let paid = 0;
  for (const m of seats) {
    if (m.user_id === lobby.creator_id) continue;
    const pay = Math.min(share, m.held);
    await capture(c, m.user_id, pay, lobbyId);
    await release(c, m.user_id, m.held - pay, lobbyId);
    await c.query(
      `UPDATE lobby_members SET hold_amount = $2, status = CASE WHEN status = 'VACANT' THEN 'ABSENT'::member_status ELSE status END WHERE id = $1`,
      [m.id, pay],
    );
    paid += pay;
  }
  const creator = seats.find((m) => m.user_id === lobby.creator_id);
  const rest = lobby.price - paid;
  await capture(c, creator.user_id, rest, lobbyId);
  await release(c, creator.user_id, creator.held - rest, lobbyId);
  await setHeld(c, creator.id, rest);

  const { rows } = await c.query(
    `INSERT INTO bookings (lobby_id, slot_id, booking_code, gross_amount, platform_fee, rounding_surplus, venue_payout)
     VALUES ($1, $2, substr('SEB' || upper(replace(gen_random_uuid()::text, '-', '')), 1, 12),
             $3::numeric, round($3::numeric * 0.05, 2), 0, $3::numeric - round($3::numeric * 0.05, 2))
     RETURNING *`,
    [lobbyId, lobby.slot_id, lobby.price],
  );
  const booking = rows[0];
  await c.query(`UPDATE court_slots SET status = 'BOOKED' WHERE id = $1`, [lobby.slot_id]);
  await c.query(
    `INSERT INTO venue_payouts (booking_id, venue_id, amount)
     SELECT $1, ct.venue_id, $2 FROM court_slots s JOIN courts ct ON ct.id = s.court_id WHERE s.id = $3`,
    [booking.id, booking.venue_payout, lobby.slot_id],
  );
  const players = seats.filter((m) => m.status === 'ACTIVE').map((m) => m.user_id);
  await c.query(
    `INSERT INTO checkins (booking_id, user_id, token_hash, token_expires_at, code)
     SELECT $1::uuid, u, encode(digest($1::uuid::text || ':' || u::text || ':' || clock_timestamp()::text, 'sha256'), 'hex'),
            $3::timestamptz + interval '2 hours', upper(substr(md5(gen_random_uuid()::text), 1, 10))
       FROM unnest($2::uuid[]) AS u`,
    [booking.id, players, lobby.start_at],
  );
  await c.query(`UPDATE lobbies SET status = 'CONFIRMED' WHERE id = $1`, [lobbyId]);
  await notify(c, seats.map((m) => m.user_id), 'BOOKING_CONFIRMED', {
    lobbyId, bookingId: booking.id, bookingCode: booking.booking_code, startAt: lobby.start_at, share,
  });
  return true;
}

// Room finished: fines of replaced members go to the members still in the room (remainder to the host).
export async function settleLobby(c, lobbyId) {
  const lobby = await lockLobbyRow(c, lobbyId);
  if (lobby.status !== 'CONFIRMED' || !lobby.finished || lobby.settled_at) return false;
  const { rows: fined } = await c.query(
    `SELECT *, hold_amount::float8 AS held FROM lobby_members WHERE lobby_id = $1 AND status = 'REPLACED' AND hold_amount > 0 FOR UPDATE`,
    [lobbyId],
  );
  const { rows: active } = await c.query(
    `SELECT user_id FROM lobby_members WHERE lobby_id = $1 AND status = 'ACTIVE' ORDER BY joined_at, id`,
    [lobbyId],
  );
  const total = fined.reduce((sum, m) => sum + m.held, 0);
  if (total > 0) {
    const receivers = active.map((r) => r.user_id);
    await lockWallets(c, [...fined.map((m) => m.user_id), ...receivers, lobby.host_id]);
    for (const m of fined) {
      await capture(c, m.user_id, m.held, lobbyId, 'PENALTY');
      await c.query('UPDATE lobby_members SET hold_amount = 0 WHERE id = $1', [m.id]);
    }
    const each = receivers.length ? Math.floor(total / receivers.length) : 0;
    for (const id of receivers) await credit(c, id, each, lobbyId);
    await credit(c, lobby.host_id, total - each * receivers.length, lobbyId);
    await notify(c, receivers, 'FINE_RECEIVED', { lobbyId, amount: each });
  }
  await c.query('UPDATE lobbies SET settled_at = now() WHERE id = $1', [lobbyId]);
  return true;
}

// Free period ends in 15 minutes: remind once.
export async function remindFreePeriod(c) {
  const { rows } = await c.query(
    `UPDATE lobby_members m SET reminded_at = now()
       FROM lobbies l
      WHERE l.id = m.lobby_id AND l.status = 'OPEN' AND m.status = 'ACTIVE' AND m.reminded_at IS NULL
        AND m.free_until > now() AND m.free_until <= now() + interval '15 minutes'
     RETURNING m.user_id, m.lobby_id, m.free_until`,
  );
  for (const r of rows) await notify(c, [r.user_id], 'FREE_PERIOD_ENDING', { lobbyId: r.lobby_id, until: r.free_until });
  return rows.length;
}

// Lobby ids due for a job; each one is then handled in its own transaction.
export async function dueLobbies(query) {
  const close = await query(`SELECT id FROM lobbies WHERE status = 'OPEN' AND join_deadline <= now() ORDER BY join_deadline LIMIT 100`);
  const settle = await query(
    `SELECT l.id FROM lobbies l JOIN court_slots s ON s.id = l.slot_id
      WHERE l.status = 'CONFIRMED' AND l.settled_at IS NULL AND s.end_at <= now() ORDER BY s.end_at LIMIT 100`,
  );
  return { close: close.rows.map((r) => r.id), settle: settle.rows.map((r) => r.id) };
}
