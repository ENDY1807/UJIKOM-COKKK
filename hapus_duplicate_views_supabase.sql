-- ============================================================
-- SQL BERSIHKAN VIEW DUPLIKAT SUPABASE (RASANTARA)
-- Jalankan skrip ini di menu SQL Editor pada Supabase Dashboard Anda.
-- Perintah ini akan menghapus semua View yang membuat daftar tabel menjadi dobel
-- dan menghilangkan tanda merah (UNRESTRICTED) pada Supabase Table Editor.
-- ============================================================

DROP VIEW IF EXISTS "user_address" CASCADE;
DROP VIEW IF EXISTS "event" CASCADE;
DROP VIEW IF EXISTS "transaksi" CASCADE;
DROP VIEW IF EXISTS "detail_order" CASCADE;
DROP VIEW IF EXISTS "order" CASCADE;
DROP VIEW IF EXISTS "masakan" CASCADE;
DROP VIEW IF EXISTS "meja" CASCADE;
DROP VIEW IF EXISTS "user" CASCADE;
DROP VIEW IF EXISTS "level" CASCADE;

-- Refresh schema cache Supabase
NOTIFY pgrst, 'reload schema';

