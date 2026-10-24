-- Harga akhir pekan per lapangan. NULL = sama dengan tariff hari biasa.
alter table public.courts
  add column if not exists price_weekend numeric(12, 2);
