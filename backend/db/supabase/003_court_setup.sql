-- 003_court_setup.sql — setup lapangan sekali di awal (jalankan sekali di Supabase SQL Editor,
-- setelah 002_court_price_weekend.sql).
-- Pemilik mengisi jam buka–tutup dan olahraga + kapasitas per lapangan (harga weekend = 002);
-- jam di dalam jam buka otomatis bisa disewa (slot dibuat saat pemain membuat room).
-- Aditif dan aman diulang: tidak ada kolom/data yang dihapus.

-- Olahraga baru. ADD VALUE boleh di dalam transaksi selama nilai baru tidak dipakai di transaksi yang sama.
ALTER TYPE public.sport_type ADD VALUE IF NOT EXISTS 'BASKETBALL';
ALTER TYPE public.sport_type ADD VALUE IF NOT EXISTS 'TENNIS';
ALTER TYPE public.sport_type ADD VALUE IF NOT EXISTS 'PADEL';

-- Jam buka–tutup harian. Lapangan lama otomatis 06:00–22:00. close_time boleh '24:00' (tutup tengah malam).
ALTER TABLE public.courts
  ADD COLUMN IF NOT EXISTS open_time  time NOT NULL DEFAULT '06:00',
  ADD COLUMN IF NOT EXISTS close_time time NOT NULL DEFAULT '22:00';
ALTER TABLE public.courts DROP CONSTRAINT IF EXISTS courts_hours_check;
ALTER TABLE public.courts ADD CONSTRAINT courts_hours_check CHECK (close_time > open_time);

-- Lapangan serbaguna: satu lapangan fisik, beberapa olahraga, kapasitas per olahraga.
-- Satu jam tetap satu booking (anti tumpang tindih tetap di court_slots per court_id).
-- courts.sport_type/capacity tetap ada sebagai olahraga utama untuk view dan klien lama.
CREATE TABLE IF NOT EXISTS public.court_sports (
  court_id   uuid              NOT NULL REFERENCES public.courts(id) ON DELETE CASCADE,
  sport_type public.sport_type NOT NULL,
  capacity   smallint          NOT NULL CHECK (capacity BETWEEN 2 AND 30),
  PRIMARY KEY (court_id, sport_type)
);
-- Backend memakai koneksi owner; Data API/anon tidak boleh membaca langsung.
ALTER TABLE public.court_sports ENABLE ROW LEVEL SECURITY;

INSERT INTO public.court_sports (court_id, sport_type, capacity)
SELECT id, sport_type, capacity FROM public.courts
ON CONFLICT DO NOTHING;

-- Olahraga yang dimainkan di room (lapangan serbaguna). NULL = olahraga utama lapangan.
ALTER TABLE public.lobbies ADD COLUMN IF NOT EXISTS sport_type public.sport_type;

-- Akses hanya lewat backend (koneksi owner): tutup Data API untuk anon/authenticated.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON public.court_sports FROM anon, authenticated;
  END IF;
END $$;

-- Lapangan yang dibuat di luar API (seed, SQL manual) tetap punya baris court_sports.
CREATE OR REPLACE FUNCTION public.trg_court_main_sport() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.court_sports (court_id, sport_type, capacity)
  VALUES (NEW.id, NEW.sport_type, NEW.capacity)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS trg_court_main_sport ON public.courts;
CREATE TRIGGER trg_court_main_sport AFTER INSERT ON public.courts
  FOR EACH ROW EXECUTE FUNCTION public.trg_court_main_sport();

-- Room lama tanpa olahraga: simpan olahraga utama lapangannya sekarang, supaya mengubah
-- daftar olahraga lapangan nanti tidak mengubah label room/booking yang sudah ada.
UPDATE public.lobbies l SET sport_type = c.sport_type
  FROM public.court_slots s JOIN public.courts c ON c.id = s.court_id
 WHERE s.id = l.slot_id AND l.sport_type IS NULL;

-- Slot yang ditinggal room batal/kedaluwarsa tidak bisa dihapus (lobbies.slot_id ON DELETE RESTRICT).
-- Slot itu dilepas (released) saat jamnya dipesan lagi: barisnya tetap untuk riwayat, tetapi tidak
-- lagi ikut aturan anti tumpang tindih dan tidak tampil di jadwal.
ALTER TABLE public.court_slots ADD COLUMN IF NOT EXISTS released boolean NOT NULL DEFAULT false;
ALTER TABLE public.court_slots DROP CONSTRAINT IF EXISTS court_slots_court_id_tstzrange_excl;
ALTER TABLE public.court_slots ADD CONSTRAINT court_slots_court_id_tstzrange_excl
  EXCLUDE USING gist (court_id WITH =, tstzrange(start_at, end_at) WITH &&) WHERE (NOT released);
ALTER TABLE public.court_slots DROP CONSTRAINT IF EXISTS court_slots_court_id_start_at_key;
CREATE UNIQUE INDEX IF NOT EXISTS court_slots_court_id_start_at_key
  ON public.court_slots (court_id, start_at) WHERE NOT released;

-- Slot released tidak boleh dipakai room baru (jalur lama slotId), supaya satu jam tidak punya dua room.
-- Sama dengan db/triggers/02_lobbies.sql.
CREATE OR REPLACE FUNCTION public.trg_lobby_validate() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_slot public.court_slots%ROWTYPE;
BEGIN
  SELECT * INTO v_slot FROM public.court_slots WHERE id = NEW.slot_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::SLOT_NOT_FOUND'; END IF;

  IF TG_OP = 'INSERT' AND (v_slot.status <> 'OPEN' OR v_slot.released) THEN
    RAISE EXCEPTION 'SEBAR::SLOT_NOT_OPEN';   -- released = jamnya sudah dipakai slot lain
  END IF;

  IF NEW.price_total <> v_slot.price THEN
    RAISE EXCEPTION 'SEBAR::PRICE_MISMATCH';
  END IF;

  IF NEW.join_deadline > v_slot.start_at - interval '6 hours' THEN
    RAISE EXCEPTION 'SEBAR::DEADLINE_TOO_LATE';   -- BR-1.5 / SDD §4.4
  END IF;

  -- perman: BR-1.4 — min_reliability tidak bisa diubah setelah ada member pertama
  IF TG_OP = 'UPDATE'
     AND EXISTS (SELECT 1 FROM public.lobby_members WHERE lobby_id = OLD.id)
     AND (NEW.min_reliability <> OLD.min_reliability OR NEW.quota <> OLD.quota) THEN
    RAISE EXCEPTION 'SEBAR::LOBBY_LOCKED';
  END IF;

  RETURN NEW;
END $$;
