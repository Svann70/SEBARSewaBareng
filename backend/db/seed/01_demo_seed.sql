-- =============================================================================
-- SEBAR — DEMO SEED (SDD §17.3) — idempotent
-- =============================================================================
-- Run order : 7 — terakhir setelah tables/, functions/, triggers/, views/
-- Akun seed: super admin, venue admin, 12 pemain (skor 40–100).
-- Password seed = placeholder Argon2id "SEBAR_SEED_ONLY"; untuk login nyata,
-- register lewat API (/auth/register w/ Argon2id — SDD §10) atau replace hash.
-- Slot: 60 masa depan + 60 lampau; 40 booking historis; 10 lobby live.
-- catatan: waktu dihitung di zona Asia/Jakarta; DB menyimpan timestamptz (SDD §17.2).
-- =============================================================================
DO $sebar_seed$
DECLARE
  sa_id            uuid := '00000000-0000-0000-0000-0000000000a1';
  va_id            uuid := '00000000-0000-0000-0000-0000000000a2';
  p_id             uuid;
  v_id             uuid;
  c_id             uuid;
  s_id             uuid;
  v_r              int;
  c_r              int;
  i_r              int;
  names            text[] := ARRAY['Raka','Dinda','Bagus','Sari','Fajar','Nadia','Yoga','Putri','Rendra','Ayu','Dimas','Lala'];
  scores           numeric[] := ARRAY[100,95,90,88,85,82,80,75,70,65,55,40];
  placeholder_hash text := '$argon2id$v=19$m=65536,t=3,p=1$SEBAR_SEED$AAAAAA';
  court_names      text[] := ARRAY['Lapangan A','Lapangan B','Lapangan C','Lapangan D'];
BEGIN
  ---------------------------------------------------------------------------
  -- 8.a Accounts — fixed UUIDs agar idempoten
  ---------------------------------------------------------------------------
  INSERT INTO public.users (id, email, phone, full_name, password_hash, role, reliability_score)
  VALUES
    (sa_id, 'admin@sebar.demo', '+628111111111', 'SEBAR Super Admin', placeholder_hash, 'SUPER_ADMIN', 100),
    (va_id, 'venue@sebar.demo', '+628111111112', 'Pengelola GOR', placeholder_hash, 'VENUE_ADMIN', 100)
  ON CONFLICT (id) DO NOTHING;

  FOR i_r IN 1..12 LOOP
    p_id := (md5('player-' || i_r)::uuid);
    INSERT INTO public.users (id, email, phone, full_name, password_hash, role, reliability_score)
    VALUES (p_id,
            'player' || lpad(i_r::text, 2, '0') || '@sebar.demo',
            '+62811100000' || lpad(i_r::text, 2, '0'),
            names[i_r], placeholder_hash, 'PLAYER', scores[i_r])
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  -- Wallets + TOPUP ledger (G2: setiap saldo punya baris ledger)
  INSERT INTO public.wallets (user_id, balance)
  SELECT id, 2000000::numeric FROM public.users
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.wallet_ledger
    (wallet_id, entry_type, amount, balance_after, held_after, ref_type, idempotency_key)
  SELECT w.id, 'TOPUP', 2000000, 2000000, 0, 'SEED', 'SEED-TOPUP:' || w.user_id::text
  FROM public.wallets w
  ON CONFLICT (idempotency_key) DO NOTHING;

  ---------------------------------------------------------------------------
  -- 8.b Venues & courts — 3 venue, 12 lapangan
  ---------------------------------------------------------------------------
  INSERT INTO public.venues (id, owner_id, name, address, city, status)
  VALUES
    ((md5('venue-1')::uuid), va_id, 'GOR C-Tra',           'Jl. Cicitra 12',        'Bandung',  'ACTIVE'),
    ((md5('venue-2')::uuid), va_id, 'Senayan Arena',       'Jl. Gelora Bung Karno', 'Jakarta',  'ACTIVE'),
    ((md5('venue-3')::uuid), va_id, 'Surabaya Futsal Hub', 'Jl. Kalijudan 42',      'Surabaya', 'ACTIVE')
  ON CONFLICT (id) DO NOTHING;

  FOR c_r IN 1..12 LOOP
    v_r := ceil(c_r::numeric / 4)::int;
    INSERT INTO public.courts (id, venue_id, name, sport_type, price_per_hour, capacity, status)
    VALUES
      ((md5('court-' || c_r)::uuid),
       (md5('venue-' || v_r)::uuid),
       court_names[c_r - ((v_r - 1) * 4)],
       (ARRAY['BADMINTON','BADMINTON','FUTSAL','VOLLEY',          -- venue 1
              'BADMINTON','FUTSAL','MINISOCCER','VOLLEY',         -- venue 2
              'FUTSAL','MINISOCCER','BADMINTON','VOLLEY'])[c_r]::public.sport_type,  -- venue 3
       (ARRAY[140000,120000,300000,180000, 160000,320000,280000,150000,
              300000,250000,130000,200000])[c_r],
       (ARRAY[8,8,14,10, 8,14,12,10, 14,12,8,10])[c_r],
       'ACTIVE')
    ON CONFLICT (venue_id, name) DO NOTHING;
  END LOOP;

  ---------------------------------------------------------------------------
  -- 8.c Future slots — 5 per court, jam peak sore/malam (60 slot)
  -- Ubah d/h sesuai perlu; durasi slot 1 jam.
  ---------------------------------------------------------------------------
  INSERT INTO public.court_slots (id, court_id, start_at, end_at, price, status)
  SELECT (md5('fslot-' || c.id || '-' || g.d || ':' || g.h)::uuid),
         c.id,
         ((date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') +
           make_interval(days => g.d, hours => g.h)) AT TIME ZONE 'Asia/Jakarta'),
         ((date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') +
           make_interval(days => g.d, hours => g.h + 1)) AT TIME ZONE 'Asia/Jakarta'),
         c.price_per_hour,
         'OPEN'
  FROM public.courts c
  CROSS JOIN (VALUES (1,9),(2,20),(3,19),(4,8),(5,16)) AS g(d, h)
  ON CONFLICT (court_id, start_at) WHERE NOT released DO NOTHING;

  ---------------------------------------------------------------------------
  -- 8.d Past slots — 5 per court untuk booking historis (60 slot)
  ---------------------------------------------------------------------------
  INSERT INTO public.court_slots (id, court_id, start_at, end_at, price, status)
  SELECT (md5('pslot-' || c.id || '-' || g.d || ':' || g.h)::uuid),
         c.id,
         ((date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') -
           make_interval(days => g.d, hours => g.h)) AT TIME ZONE 'Asia/Jakarta'),
         ((date_trunc('day', now() AT TIME ZONE 'Asia/Jakarta') -
           make_interval(days => g.d, hours => g.h)) AT TIME ZONE 'Asia/Jakarta') + interval '1 hour',
         c.price_per_hour,
         'PAST'
  FROM public.courts c
  CROSS JOIN (VALUES (3,9),(5,16),(8,19),(10,20),(12,20)) AS g(d, h)
  ON CONFLICT (court_id, start_at) WHERE NOT released DO NOTHING;

  ---------------------------------------------------------------------------
  -- 8.e 40 booking historis (analytics: omzet, fee, peak hours, no-show)
  -- Trigger dinonaktifkan sementara agar data masa lalu bisa "direkonstruksi".
  ---------------------------------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM public.audit_log WHERE action = 'SEED_HISTORICAL') THEN
    PERFORM public.log_audit('SEED_HISTORICAL', 'system', NULL, NULL, NULL, jsonb_build_object('note', 'seed start'));

    ALTER TABLE public.lobbies        DISABLE TRIGGER trg_lobby_validate;
    ALTER TABLE public.lobby_members  DISABLE TRIGGER trg_member_hold;
    ALTER TABLE public.checkins       DISABLE TRIGGER trg_checkin_scanned;

    -- Lobby CONFIRMED + booking + payout + checkins per slot PAST pertama (40 slot)
    WITH past_slots AS (
      SELECT row_number() OVER (ORDER BY s.start_at, s.court_id) AS rn,
             s.id AS slot_id, s.price, s.start_at, s.court_id
      FROM public.court_slots s
      WHERE s.status = 'PAST'
      ORDER BY 1
      LIMIT 40
    ),
    ins_lobbies AS (
      INSERT INTO public.lobbies (id, slot_id, host_id, title, min_reliability, quota,
                                  price_total, join_deadline, status, created_at)
      SELECT (md5('hlobby-' || rn)::uuid),
             slot_id,
             (md5('player-' || ((rn % 12) + 1))::uuid),
             'Riwayat: ' || COALESCE(c.sport_type::text, 'Main'),
             0, 4, price,
             start_at - interval '12 hours',
             'CONFIRMED',
             start_at - interval '3 days'
      FROM past_slots ps
      JOIN public.courts c ON c.id = ps.court_id
    ),
    ins_bookings AS (
      INSERT INTO public.bookings (id, lobby_id, slot_id, booking_code, gross_amount,
                                   platform_fee, rounding_surplus, venue_payout,
                                   status, booked_at)
      SELECT (md5('hbook-' || rn)::uuid),
             (md5('hlobby-' || rn)::uuid),
             slot_id,
             'SEBH' || lpad(rn::text, 8, '0'),   -- 12 char, UNIQUE
             price,
             round(price * 0.05, 2),
             0,
             price - round(price * 0.05, 2),
             'COMPLETED',
             start_at - interval '2 days'
      FROM past_slots
    )
    INSERT INTO public.venue_payouts (id, booking_id, venue_id, amount, status, disbursed_at, created_at)
    SELECT (md5('hpayout-' || rn)::uuid),
           (md5('hbook-' || rn)::uuid),
           c.venue_id,
           ps.price - round(ps.price * 0.05, 2),
           'PAID',
           ps.start_at + interval '1 hour',
           ps.start_at - interval '2 days'
    FROM past_slots ps
    JOIN public.courts c ON c.id = ps.court_id;

    -- Members + checkins riwayat: host + 3 pemain per booking; ±1 dari 7 no-show
    FOR v_r IN 1..40 LOOP
      -- host member
      INSERT INTO public.lobby_members (id, lobby_id, user_id, role_in_lobby, status, hold_amount, hold_ledger_id, joined_at)
      VALUES ((md5('hmember-' || v_r || '-' || 0)::uuid),
              (md5('hlobby-' || v_r)::uuid),
              (md5('player-' || ((v_r % 12) + 1))::uuid),
              'HOST', 'CONFIRMED',
              (SELECT ceil(bs.gross_amount / 4.0) FROM public.bookings bs WHERE bs.lobby_id = (md5('hlobby-' || v_r)::uuid)),
              NULL,
              (SELECT s.start_at - interval '2 days'
                 FROM public.bookings b JOIN public.court_slots s ON s.id = b.slot_id
                WHERE b.lobby_id = (md5('hlobby-' || v_r)::uuid)))
      ON CONFLICT (lobby_id, user_id) DO NOTHING;

      -- 3 pemain member
      FOR c_r IN 1..3 LOOP
        i_r := ((v_r + c_r) % 12) + 1;
        IF i_r = ((v_r % 12) + 1) THEN i_r := ((i_r % 12) + 1); END IF;  -- hindari = host

        IF (v_r * 3 + c_r) % 28 = 0 THEN
          -- kasus NO_SHOW (analytics butuh data no-show — BR-4.2 / US-10)
          INSERT INTO public.lobby_members (id, lobby_id, user_id, role_in_lobby, status, hold_amount, hold_ledger_id, joined_at)
          VALUES ((md5('hmember-' || v_r || '-' || c_r)::uuid),
                  (md5('hlobby-' || v_r)::uuid),
                  (md5('player-' || i_r)::uuid),
                  'PLAYER', 'NO_SHOW',
                  0.01, NULL,
                  (SELECT s.start_at - interval '2 days'
                     FROM public.bookings b JOIN public.court_slots s ON s.id = b.slot_id
                    WHERE b.lobby_id = (md5('hlobby-' || v_r)::uuid)))
          ON CONFLICT (lobby_id, user_id) DO NOTHING;

          INSERT INTO public.checkins (id, booking_id, user_id, token_hash, token_expires_at, status)
          VALUES ((md5('hcheckin-' || v_r || '-' || c_r)::uuid),
                  (md5('hbook-' || v_r)::uuid),
                  (md5('player-' || i_r)::uuid),
                  encode(digest('noshow:' || v_r || ':' || c_r, 'sha256'), 'hex'),
                  (SELECT s.start_at + interval '2 hours'
                     FROM public.bookings b JOIN public.court_slots s ON s.id = b.slot_id
                    WHERE b.lobby_id = (md5('hlobby-' || v_r)::uuid)),
                  'NO_SHOW')
          ON CONFLICT (booking_id, user_id) DO NOTHING;
        ELSE
          -- hadir: checkin SCANNED oleh venue admin
          INSERT INTO public.lobby_members (id, lobby_id, user_id, role_in_lobby, status, hold_amount, hold_ledger_id, joined_at)
          VALUES ((md5('hmember-' || v_r || '-' || c_r)::uuid),
                  (md5('hlobby-' || v_r)::uuid),
                  (md5('player-' || i_r)::uuid),
                  'PLAYER', 'CONFIRMED',
                  0.01, NULL,
                  (SELECT s.start_at - interval '2 days'
                     FROM public.bookings b JOIN public.court_slots s ON s.id = b.slot_id
                    WHERE b.lobby_id = (md5('hlobby-' || v_r)::uuid)))
          ON CONFLICT (lobby_id, user_id) DO NOTHING;

          INSERT INTO public.checkins (id, booking_id, user_id, token_hash, token_expires_at, status,
                                       scanned_by, scanned_at)
          VALUES ((md5('hcheckin-' || v_r || '-' || c_r)::uuid),
                  (md5('hbook-' || v_r)::uuid),
                  (md5('player-' || i_r)::uuid),
                  encode(digest('ok:' || v_r || ':' || c_r, 'sha256'), 'hex'),
                  (SELECT s.start_at + interval '2 hours'
                     FROM public.bookings b JOIN public.court_slots s ON s.id = b.slot_id
                    WHERE b.lobby_id = (md5('hlobby-' || v_r)::uuid)),
                  'SCANNED',
                  va_id,
                  (SELECT s.start_at + interval '10 minutes'
                     FROM public.bookings b JOIN public.court_slots s ON s.id = b.slot_id
                    WHERE b.lobby_id = (md5('hlobby-' || v_r)::uuid)))
          ON CONFLICT (booking_id, user_id) DO NOTHING;
        END IF;
      END LOOP;
    END LOOP;

    ALTER TABLE public.lobbies        ENABLE TRIGGER trg_lobby_validate;
    ALTER TABLE public.lobby_members  ENABLE TRIGGER trg_member_hold;
    ALTER TABLE public.checkins       ENABLE TRIGGER trg_checkin_scanned;
  END IF;

  ---------------------------------------------------------------------------
  -- 8.f Lobby live — 10 lobby (2 penuh→auto-booking, 5 berjalan, 3 deadline)
  ---------------------------------------------------------------------------
  IF (SELECT count(*) FROM public.lobbies WHERE status = 'OPEN') = 0 THEN
    -- Near deadline: slot terdekat (start > now + 7 jam) → deadline 1–3 jam lagi
    WITH near_slots AS (
      SELECT row_number() OVER (ORDER BY s.start_at) AS rn,
             s.id AS slot_id, s.start_at, s.price, c.sport_type, v.city
      FROM public.court_slots s
      JOIN public.courts c ON c.id = s.court_id
      JOIN public.venues v ON v.id = c.venue_id
      WHERE s.status = 'OPEN'
        AND s.start_at > now() + interval '7 hours'
      ORDER BY s.start_at
      LIMIT 3
    )
    INSERT INTO public.lobbies (id, slot_id, host_id, title, min_reliability, quota,
                                price_total, join_deadline, status)
    SELECT (md5('nlobby-' || rn)::uuid),
           slot_id,
           (md5('player-' || ((rn % 6) + 1))::uuid),
           CASE sport_type WHEN 'BADMINTON' THEN 'Badminton Pagi ' || city
                           WHEN 'FUTSAL'    THEN 'Futsal Seru ' || city
                           ELSE 'Voli Asik ' || city END,
           0, 4, price, start_at - interval '6 hours', 'OPEN'
    FROM near_slots
    ON CONFLICT DO NOTHING;

    -- add 1 extra member each pada lobby near deadline
    INSERT INTO public.lobby_members (lobby_id, user_id, role_in_lobby, status, hold_amount)
    SELECT l.id, (md5('player-' || ((row_number() OVER ()) + 6))::uuid), 'PLAYER', 'HOLDING', l.price_per_person
    FROM public.lobbies l
    WHERE l.id IN (SELECT (md5('nlobby-' || rn)::uuid) FROM generate_series(1, 3) rn)
    ON CONFLICT (lobby_id, user_id) DO NOTHING;

    -- Far lobbies: pilih 7 slot OPEN > 36 jam
    INSERT INTO public.lobbies (id, slot_id, host_id, title, min_reliability, quota,
                                price_total, join_deadline, status)
    SELECT (md5('lobby-' || rn)::uuid),
           slot_id,
           (md5('player-' || ((rn % 4) + 1))::uuid),
           'Main Bareng Slot ' || rn,
           CASE WHEN rn % 3 = 0 THEN 60 ELSE 0 END,
           CASE WHEN rn <= 2 THEN 4 ELSE 6 END,
           price, start_at - interval '6 hours', 'OPEN'
    FROM (
      SELECT row_number() OVER (ORDER BY s.start_at) AS rn,
             s.id AS slot_id, s.start_at, s.price
      FROM public.court_slots s
      WHERE s.status = 'OPEN' AND s.start_at > now() + interval '36 hours'
      ORDER BY s.start_at
      LIMIT 7
    ) far_slots
    ON CONFLICT DO NOTHING;

    INSERT INTO public.lobby_members (lobby_id, user_id, role_in_lobby, status, hold_amount)
    SELECT l.id, l.host_id, 'HOST', 'HOLDING', l.price_per_person
    FROM public.lobbies l
    WHERE l.id IN (SELECT (md5('lobby-' || rn)::uuid) FROM generate_series(1, 7) rn)
    ON CONFLICT (lobby_id, user_id) DO NOTHING;

    -- 2 lobby "penuh": quota 4 → host + 3 member (join ke-4 memicu auto-booking)
    FOR v_r IN 1..2 LOOP
      FOR c_r IN 1..3 LOOP
        i_r := ((v_r * 3 + c_r) % 12) + 1;
        INSERT INTO public.lobby_members (lobby_id, user_id, role_in_lobby, status, hold_amount)
        SELECT l.id, (md5('player-' || i_r)::uuid), 'PLAYER', 'HOLDING', l.price_per_person
        FROM public.lobbies l
        WHERE l.id = (md5('lobby-' || v_r)::uuid)
        ON CONFLICT (lobby_id, user_id) DO NOTHING;
      END LOOP;
    END LOOP;

    -- 5 lobby "berjalan": 5 slot sisanya → 2 member tambahan (total 3 dari kunota 6)
    FOR v_r IN 3..7 LOOP
      FOR c_r IN 1..2 LOOP
        i_r := ((v_r * 4 + c_r) % 12) + 1;
        INSERT INTO public.lobby_members (lobby_id, user_id, role_in_lobby, status, hold_amount)
        SELECT l.id, (md5('player-' || i_r)::uuid), 'PLAYER', 'HOLDING', l.price_per_person
        FROM public.lobbies l
        WHERE l.id = (md5('lobby-' || v_r)::uuid)
        ON CONFLICT (lobby_id, user_id) DO NOTHING;
      END LOOP;
    END LOOP;
  END IF;

  PERFORM public.log_audit('SEED_COMPLETE', 'system', NULL, NULL, NULL,
    jsonb_build_object('note', 'SDD §17.3 seed selesai'));
END
$sebar_seed$;
