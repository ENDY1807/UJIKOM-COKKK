-- ============================================================
-- DATABASE RESTORAN NUSANTARA "RASANTARA"
-- UJI KOMPETENSI KEAHLIAN (UKK) REKAYASA PERANGKAT LUNAK 2026/2027
-- Paket 1 - Aplikasi Kasir & Pemesanan Meja Restoran (Table Service)
-- DIALECT: PostgreSQL 12+ / Supabase / Neon / pgAdmin 4
-- ============================================================

-- Bersihkan view & tabel jika sudah ada sebelumnya (clean install)
DROP VIEW IF EXISTS "transaksi" CASCADE;
DROP VIEW IF EXISTS "detail_order" CASCADE;
DROP VIEW IF EXISTS "order" CASCADE;
DROP VIEW IF EXISTS "masakan" CASCADE;
DROP VIEW IF EXISTS "meja" CASCADE;
DROP VIEW IF EXISTS "user" CASCADE;
DROP VIEW IF EXISTS "level" CASCADE;

DROP TABLE IF EXISTS tb_payment_mutasi CASCADE;
DROP TABLE IF EXISTS tb_user_payment_methods CASCADE;
DROP TABLE IF EXISTS tb_log_aktivitas CASCADE;
DROP TABLE IF EXISTS tb_transaksi CASCADE;
DROP TABLE IF EXISTS tb_detail_order CASCADE;
DROP TABLE IF EXISTS tb_order CASCADE;
DROP TABLE IF EXISTS tb_masakan CASCADE;
DROP TABLE IF EXISTS tb_meja CASCADE;
DROP TABLE IF EXISTS tb_user CASCADE;
DROP TABLE IF EXISTS tb_level CASCADE;

DROP TYPE IF EXISTS auth_provider_type CASCADE;
DROP TYPE IF EXISTS status_meja_type CASCADE;
DROP TYPE IF EXISTS kategori_masakan_type CASCADE;
DROP TYPE IF EXISTS status_masakan_type CASCADE;
DROP TYPE IF EXISTS status_order_type CASCADE;
DROP TYPE IF EXISTS status_detail_type CASCADE;
DROP TYPE IF EXISTS metode_bayar_type CASCADE;

-- ENUM Types
CREATE TYPE auth_provider_type AS ENUM ('local', 'google', 'both');
CREATE TYPE status_meja_type AS ENUM ('Kosong', 'Terisi', 'Reservasi');
CREATE TYPE kategori_masakan_type AS ENUM ('Makanan', 'Minuman', 'Paket');
CREATE TYPE status_masakan_type AS ENUM ('Tersedia', 'Habis');
CREATE TYPE status_order_type AS ENUM ('Menunggu', 'Diproses', 'Selesai', 'Dibatalkan');
CREATE TYPE status_detail_type AS ENUM ('Menunggu', 'Dimasak', 'Disajikan');
CREATE TYPE metode_bayar_type AS ENUM ('Tunai', 'QRIS', 'Kartu Debit', 'Kartu Kredit', 'Transfer Bank', 'GoPay / E-Wallet');

-- ============================================================
-- 1. TABEL LEVEL HAK AKSES
-- ============================================================
CREATE TABLE tb_level (
    id_level SERIAL PRIMARY KEY,
    nama_level VARCHAR(30) NOT NULL UNIQUE
);

INSERT INTO tb_level (id_level, nama_level) VALUES
(1, 'Administrator'),
(2, 'Waiter'),
(3, 'Kasir'),
(4, 'Owner'),
(5, 'Pelanggan');

SELECT setval(pg_get_serial_sequence('tb_level', 'id_level'), COALESCE(MAX(id_level), 1)) FROM tb_level;

-- ============================================================
-- 2. TABEL USER / PENGGUNA (DUKUNGAN GOOGLE OAUTH & LOKAL)
-- ============================================================
CREATE TABLE tb_user (
    id_user SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    password VARCHAR(255) DEFAULT '',
    nama_user VARCHAR(100) NOT NULL,
    id_level INT NOT NULL DEFAULT 5 REFERENCES tb_level(id_level) ON DELETE RESTRICT ON UPDATE CASCADE,
    foto_profil VARCHAR(500) DEFAULT NULL,
    auth_provider auth_provider_type NOT NULL DEFAULT 'local',
    google_uid VARCHAR(128) UNIQUE DEFAULT NULL,
    google_email VARCHAR(150) UNIQUE DEFAULT NULL,
    google_photo VARCHAR(500) DEFAULT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO tb_user (id_user, username, password, nama_user, id_level, auth_provider) VALUES
(1, 'admin', 'admin123', 'Bagas Administrator', 1, 'local'),
(2, 'waiter', 'waiter123', 'Dewi Waiter Nusantara', 2, 'local'),
(3, 'kasir', 'kasir123', 'Rian Kasir Rasantara', 3, 'local'),
(4, 'owner', 'owner123', 'Pak Hendra (Owner)', 4, 'local'),
(5, 'pelanggan', 'pelanggan123', 'Pelanggan Rasantara', 5, 'local'),
(6, 'budi', 'budi123', 'Budi Santoso', 5, 'local'),
(7, 'siti', 'siti123', 'Siti Rahmawati', 5, 'local');

SELECT setval(pg_get_serial_sequence('tb_user', 'id_user'), COALESCE(MAX(id_user), 1)) FROM tb_user;

-- ============================================================
-- 3. TABEL MEJA RESTORAN (DILENGKAPI QR CODE PAYLOAD)
-- ============================================================
CREATE TABLE tb_meja (
    id_meja SERIAL PRIMARY KEY,
    nomor_meja VARCHAR(20) NOT NULL UNIQUE,
    kapasitas INT NOT NULL DEFAULT 2 CHECK (kapasitas > 0),
    status status_meja_type NOT NULL DEFAULT 'Kosong',
    qr_payload VARCHAR(100) DEFAULT NULL
);

INSERT INTO tb_meja (id_meja, nomor_meja, kapasitas, status, qr_payload) VALUES
(1, 'Meja 01', 2, 'Kosong', 'RASANTARA-MEJA-01'),
(2, 'Meja 02', 2, 'Kosong', 'RASANTARA-MEJA-02'),
(3, 'Meja 03', 4, 'Kosong', 'RASANTARA-MEJA-03'),
(4, 'Meja 04', 4, 'Kosong', 'RASANTARA-MEJA-04'),
(5, 'Meja 05', 4, 'Kosong', 'RASANTARA-MEJA-05'),
(6, 'Meja 06', 6, 'Kosong', 'RASANTARA-MEJA-06'),
(7, 'Meja 07', 6, 'Kosong', 'RASANTARA-MEJA-07'),
(8, 'Meja 08', 8, 'Kosong', 'RASANTARA-MEJA-08'),
(9, 'Meja 09', 4, 'Kosong', 'RASANTARA-MEJA-09'),
(10, 'Meja 10', 4, 'Kosong', 'RASANTARA-MEJA-10'),
(11, 'Meja 11', 2, 'Kosong', 'RASANTARA-MEJA-11'),
(12, 'Meja 12', 6, 'Kosong', 'RASANTARA-MEJA-12');

SELECT setval(pg_get_serial_sequence('tb_meja', 'id_meja'), COALESCE(MAX(id_meja), 1)) FROM tb_meja;

-- ============================================================
-- 4. TABEL MASAKAN / MENU NUSANTARA
-- ============================================================
CREATE TABLE tb_masakan (
    id_masakan SERIAL PRIMARY KEY,
    nama_masakan VARCHAR(100) NOT NULL,
    harga INT NOT NULL CHECK (harga >= 0),
    status_masakan status_masakan_type NOT NULL DEFAULT 'Tersedia',
    kategori kategori_masakan_type NOT NULL DEFAULT 'Makanan',
    deskripsi TEXT DEFAULT '',
    gambar_url VARCHAR(500) DEFAULT ''
);

INSERT INTO tb_masakan (id_masakan, nama_masakan, harga, status_masakan, kategori, deskripsi, gambar_url) VALUES
(1, 'Rendang Daging Sapi Minang', 45000, 'Tersedia', 'Makanan', 'Daging sapi pilihan dimasak perlahan dengan santan dan rempah khas Minangkabau selama 8 jam.', 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80'),
(2, 'Ayam Betutu Gilimanuk Bali', 42000, 'Tersedia', 'Makanan', 'Ayam utuh dibumbui base genep khas Bali dibungkus daun pisang lalu dipanggang dengan aroma rempah harum.', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&auto=format&fit=crop&q=80'),
(3, 'Nasi Liwet Komplit Solo', 35000, 'Tersedia', 'Makanan', 'Nasi gurih masak santan disajikan dengan suwiran ayam opor, sayur labu siam pedas, areh santan kental, dan telur pindang.', 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop&q=80'),
(4, 'Rawon Daging Sapi Surabaya', 38000, 'Tersedia', 'Makanan', 'Sup daging sapi berkuah hitam pekat dari kluwek istimewa Jawa Timur, disajikan bersama sambal terasi dan kecambah pendek.', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80'),
(5, 'Gudeg Komplit Wijilan Jogja', 36000, 'Tersedia', 'Makanan', 'Nangka muda manis gurih khas Jogja dengan krecek pedas, ayam kampung bacem lembut, dan sambal goreng tempe.', 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80'),
(6, 'Sate Ayam Madura Saus Kacang', 32000, 'Tersedia', 'Makanan', '10 tusuk sate ayam empuk dipanggang arang batok, dilumuri bumbu kacang gurih pekat dan irisan bawang merah.', 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80'),
(7, 'Soto Banjar Khas Kalsel', 34000, 'Tersedia', 'Makanan', 'Soto ayam berkuah rempah harum kayu manis dan pala, disajikan bersama perkedel kentang renyah dan ketupat.', 'https://images.unsplash.com/photo-1547592180-85f173990554?w=600&auto=format&fit=crop&q=80'),
(8, 'Pempek Palembang Kapal Selam', 30000, 'Tersedia', 'Makanan', 'Olahan ikan tenggiri segar dengan isian telur utuh, digoreng garing di luar lembut di dalam, disiram kuah cuko pedas asam manis.', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80'),
(9, 'Ayam Taliwang Bakar Lombok', 40000, 'Tersedia', 'Makanan', 'Ayam muda bakar bumbu pedas meresap khas Sasak Lombok dengan aroma terasi bakar dan jeruk limau segar.', 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=600&auto=format&fit=crop&q=80'),
(10, 'Bebek Sinjay Goreng Kremes', 44000, 'Tersedia', 'Makanan', 'Bebek ungkep gurih digoreng renyah bertabur kremesan bumbu bebek dan sambal pencit mangga muda segar khas Bangkalan.', 'https://images.unsplash.com/photo-1514944298352-77742110c71e?w=600&auto=format&fit=crop&q=80'),
(11, 'Gado-Gado Siram Betawi', 26000, 'Tersedia', 'Makanan', 'Sayuran rebus segar, tahu tempe goreng, telur rebus, disiram saus kacang gurih dan kerupuk emping melinjo.', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80'),
(12, 'Nasi Goreng Kampung Rempah', 28000, 'Tersedia', 'Makanan', 'Nasi goreng harum bawang merah dengan suwiran ayam, telur ceplok mata sapi, acar segar, dan kerupuk udang.', 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=600&auto=format&fit=crop&q=80'),
(13, 'Es Cendol Durian Rasantara', 22000, 'Tersedia', 'Minuman', 'Cendol pandan suji kenyal dengan santan kelapa murni, gula aren alami Melaka, dan topping daging durian asli.', 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'),
(14, 'Es Teler Spesial Nusantara', 20000, 'Tersedia', 'Minuman', 'Paduan alpukat mentega, kelapa muda serut, nangka manis wangi, selasih, susu kental manis, dan es serut dingin.', 'https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=600&auto=format&fit=crop&q=80'),
(15, 'Wedang Jahe Serai Hangat', 15000, 'Tersedia', 'Minuman', 'Rebusan jahe merah bakar, batang serai wangi, kayu manis, dan gula aren berkhasiat menghangatkan tubuh.', 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80'),
(16, 'Es Kuwut Khas Bali', 18000, 'Tersedia', 'Minuman', 'Kelapa muda serut segar dipadukan dengan melon manis, biji selasih, dan perasan jeruk nipis dingin menyegarkan.', 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80'),
(17, 'Teh Tarik Melayu Rempah', 14000, 'Tersedia', 'Minuman', 'Seduhan teh hitam wangi yang ditarik hingga berbusa lembut bersama susu kental manis dengan sentuhan kapulaga.', 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=600&auto=format&fit=crop&q=80'),
(18, 'Jus Alpukat Kental Kocok', 20000, 'Tersedia', 'Minuman', 'Jus alpukat mentega segar kental dengan swirl cokelat premium kental manis yang melimpah.', 'https://images.unsplash.com/photo-1638176066666-ffb2f83b27bb?w=600&auto=format&fit=crop&q=80'),
(19, 'Kopi Tubruk Gayo Aceh', 16000, 'Tersedia', 'Minuman', 'Kopi robusta-arabika Gayo single origin diseduh tradisional dengan aroma khas tanah tinggi Aceh.', 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop&q=80'),
(20, 'Paket Rantang Berempat Rasantara', 155000, 'Tersedia', 'Paket', 'Paket hemat untuk 4 orang: 2 Rendang Daging, 2 Ayam Betutu, 4 Nasi Liwet Solo, Sayur Krecek, dan 4 Es Teh Manis.', 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=600&auto=format&fit=crop&q=80'),
(21, 'Paket Kenyang Berdua Rendang & Betutu', 85000, 'Tersedia', 'Paket', 'Paket hemat 2 orang: 1 Rendang Minang, 1 Ayam Betutu, 2 Nasi Putih Wangi, 2 Es Cendol Rasantara.', 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80'),
(22, 'Paket Sarapan Solo Nasi Liwet + Teh', 42000, 'Tersedia', 'Paket', '1 Porsi Nasi Liwet Komplit Solo lengkap dengan suwiran ayam opor + 1 cangkir Teh Tarik Hangat.', 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&auto=format&fit=crop&q=80');

SELECT setval(pg_get_serial_sequence('tb_masakan', 'id_masakan'), COALESCE(MAX(id_masakan), 1)) FROM tb_masakan;

-- ============================================================
-- 5. TABEL ORDER / PESANAN
-- ============================================================
CREATE TABLE tb_order (
    id_order SERIAL PRIMARY KEY,
    no_meja VARCHAR(50) NOT NULL,
    tanggal DATE NOT NULL DEFAULT CURRENT_DATE,
    id_user INT REFERENCES tb_user(id_user) ON DELETE SET NULL ON UPDATE CASCADE,
    keterangan TEXT,
    status_order status_order_type NOT NULL DEFAULT 'Menunggu',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 6. TABEL DETAIL ORDER / RINCIAN ITEM PESANAN
-- ============================================================
CREATE TABLE tb_detail_order (
    id_detail_order SERIAL PRIMARY KEY,
    id_order INT NOT NULL REFERENCES tb_order(id_order) ON DELETE CASCADE ON UPDATE CASCADE,
    id_masakan INT NOT NULL REFERENCES tb_masakan(id_masakan) ON DELETE RESTRICT ON UPDATE CASCADE,
    jumlah INT NOT NULL CHECK (jumlah > 0),
    harga_satuan INT NOT NULL DEFAULT 0 CHECK (harga_satuan >= 0),
    subtotal INT NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    keterangan VARCHAR(255) DEFAULT '',
    status_detail_order status_detail_type NOT NULL DEFAULT 'Menunggu'
);

-- ============================================================
-- 7. TABEL TRANSAKSI KASIR
-- ============================================================
CREATE TABLE tb_transaksi (
    id_transaksi SERIAL PRIMARY KEY,
    id_user INT REFERENCES tb_user(id_user) ON DELETE SET NULL ON UPDATE CASCADE,
    id_order INT NOT NULL REFERENCES tb_order(id_order) ON DELETE CASCADE ON UPDATE CASCADE,
    tanggal DATE NOT NULL DEFAULT CURRENT_DATE,
    total_bayar INT NOT NULL CHECK (total_bayar >= 0),
    jumlah_bayar INT NOT NULL CHECK (jumlah_bayar >= 0),
    kembalian INT NOT NULL DEFAULT 0 CHECK (kembalian >= 0),
    metode_pembayaran VARCHAR(50) NOT NULL DEFAULT 'Tunai',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 8. TABEL METODE PEMBAYARAN PENGGUNA (E-WALLET & M-BANKING)
-- ============================================================
CREATE TABLE IF NOT EXISTS tb_user_payment_methods (
    id VARCHAR(50) PRIMARY KEY,
    id_user INT NOT NULL REFERENCES tb_user(id_user) ON DELETE CASCADE,
    provider VARCHAR(50) NOT NULL,
    account_number VARCHAR(100) NOT NULL,
    account_name VARCHAR(150) NOT NULL,
    balance INT NOT NULL DEFAULT 0 CHECK (balance >= 0),
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    connected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 9. TABEL MUTASI & HISTORI SALDO WALLET (BUKU BESAR TRANSAKSI)
-- ============================================================
CREATE TABLE IF NOT EXISTS tb_payment_mutasi (
    id_mutasi SERIAL PRIMARY KEY,
    id_payment_method VARCHAR(50) NOT NULL REFERENCES tb_user_payment_methods(id) ON DELETE CASCADE,
    id_user INT NOT NULL REFERENCES tb_user(id_user) ON DELETE CASCADE,
    tipe VARCHAR(20) NOT NULL CHECK (tipe IN ('Kredit', 'Debit')),
    nominal INT NOT NULL CHECK (nominal > 0),
    saldo_sebelum INT NOT NULL DEFAULT 0,
    saldo_sesudah INT NOT NULL DEFAULT 0,
    keterangan VARCHAR(255) NOT NULL,
    referensi_id VARCHAR(50) DEFAULT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 10. TABEL LOG AKTIVITAS (AUDIT TRAIL)
-- ============================================================
CREATE TABLE tb_log_aktivitas (
    id_log SERIAL PRIMARY KEY,
    id_user INT REFERENCES tb_user(id_user) ON DELETE SET NULL,
    aktivitas VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- SEED DATA HISTORIS TRANSAKSI & PESANAN (MENGISI DIAGRAM REAL-TIME)
-- Menghasilkan data transaksi 7 hari terakhir, variasi metode bayar,
-- serta persebaran tipe layanan (Dine-in, GoFood Delivery, Take Away).
-- Menggunakan subquery COALESCE agar aman dari Foreign Key error
-- jika dijalankan berulang atau jika urutan ID user berbeda.
-- ============================================================

-- Order 1: 6 Hari lalu (Dine In Meja 03) - Bayar Tunai
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    101, 
    'Meja 03', 
    CURRENT_DATE - INTERVAL '6 day', 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'budi' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'Dine-In (2 Orang)', 
    'Selesai', 
    CURRENT_TIMESTAMP - INTERVAL '6 day'
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1001, 101, 1, 2, 45000, 90000, 'Pedas sedang', 'Disajikan'),
(1002, 101, 13, 2, 22000, 44000, 'Durian banyak', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    201, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    101, 
    CURRENT_DATE - INTERVAL '6 day', 
    134000, 
    150000, 
    16000, 
    'Tunai', 
    CURRENT_TIMESTAMP - INTERVAL '6 day'
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Order 2: 5 Hari lalu (GoFood Delivery Rumah) - Bayar QRIS
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    102, 
    'Delivery (Rumah)', 
    CURRENT_DATE - INTERVAL '5 day', 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'siti' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'GoFood Delivery: Jl. Kaliurang KM 5 No. 12 | Jarak: 3.2km | Ongkir: Rp 10500', 
    'Selesai', 
    CURRENT_TIMESTAMP - INTERVAL '5 day'
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1003, 102, 2, 1, 42000, 42000, 'Ayam bagian paha', 'Disajikan'),
(1004, 102, 3, 2, 35000, 70000, 'Krecek pedas', 'Disajikan'),
(1005, 102, 14, 2, 20000, 40000, 'Es sedikit', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    202, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    102, 
    CURRENT_DATE - INTERVAL '5 day', 
    152000, 
    152000, 
    0, 
    'QRIS', 
    CURRENT_TIMESTAMP - INTERVAL '5 day'
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Order 3: 4 Hari lalu (Dine In Meja 05) - Bayar GoPay
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    103, 
    'Meja 05', 
    CURRENT_DATE - INTERVAL '4 day', 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'pelanggan' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'Dine-In (4 Orang)', 
    'Selesai', 
    CURRENT_TIMESTAMP - INTERVAL '4 day'
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1006, 103, 4, 3, 38000, 114000, 'Kecambah dipisah', 'Disajikan'),
(1007, 103, 16, 3, 18000, 54000, 'Segar dingin', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    203, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    103, 
    CURRENT_DATE - INTERVAL '4 day', 
    168000, 
    168000, 
    0, 
    'GoPay / E-Wallet', 
    CURRENT_TIMESTAMP - INTERVAL '4 day'
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Order 4: 3 Hari lalu (Take Away Counter) - Bayar Tunai
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    104, 
    'Take Away (Pick-up)', 
    CURRENT_DATE - INTERVAL '3 day', 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'budi' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'Take Away di Counter | Ambil jam 12:30', 
    'Selesai', 
    CURRENT_TIMESTAMP - INTERVAL '3 day'
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1008, 104, 6, 3, 32000, 96000, 'Bumbu kacang dipisah', 'Disajikan'),
(1009, 104, 18, 2, 20000, 40000, 'Kental manis', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    204, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    104, 
    CURRENT_DATE - INTERVAL '3 day', 
    136000, 
    150000, 
    14000, 
    'Tunai', 
    CURRENT_TIMESTAMP - INTERVAL '3 day'
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Order 5: 2 Hari lalu (Dine In Meja 08) - Bayar Kartu Debit
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    105, 
    'Meja 08', 
    CURRENT_DATE - INTERVAL '2 day', 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'pelanggan' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'Dine-In (6 Orang Keluarga)', 
    'Selesai', 
    CURRENT_TIMESTAMP - INTERVAL '2 day'
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1010, 105, 20, 1, 155000, 155000, 'Paket Rantang Berempat Komplit', 'Disajikan'),
(1011, 105, 1, 2, 45000, 90000, 'Daging empuk', 'Disajikan'),
(1012, 105, 13, 2, 22000, 44000, 'Durian asli', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    205, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    105, 
    CURRENT_DATE - INTERVAL '2 day', 
    289000, 
    289000, 
    0, 
    'Kartu Debit', 
    CURRENT_TIMESTAMP - INTERVAL '2 day'
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Order 6: Kemarin (GoFood Delivery Rumah) - Bayar QRIS
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    106, 
    'Delivery (Rumah)', 
    CURRENT_DATE - INTERVAL '1 day', 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'siti' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'GoFood Delivery: Perumahan Asri Blok C-4 | Ongkir: Rp 8000', 
    'Selesai', 
    CURRENT_TIMESTAMP - INTERVAL '1 day'
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1013, 106, 9, 2, 40000, 80000, 'Bakar pedas lombok', 'Disajikan'),
(1014, 106, 14, 2, 20000, 40000, 'Manis segar', 'Disajikan'),
(1015, 106, 1, 1, 45000, 45000, 'Rendang Minang', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    206, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    106, 
    CURRENT_DATE - INTERVAL '1 day', 
    165000, 
    165000, 
    0, 
    'QRIS', 
    CURRENT_TIMESTAMP - INTERVAL '1 day'
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Order 7: Hari Ini (Dine In Meja 02) - Bayar QRIS
INSERT INTO tb_order (id_order, no_meja, tanggal, id_user, keterangan, status_order, created_at)
VALUES (
    107, 
    'Meja 02', 
    CURRENT_DATE, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'budi' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 5 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    'Dine-In (2 Orang)', 
    'Selesai', 
    CURRENT_TIMESTAMP
)
ON CONFLICT (id_order) DO UPDATE SET status_order = EXCLUDED.status_order, id_user = EXCLUDED.id_user;

INSERT INTO tb_detail_order (id_detail_order, id_order, id_masakan, jumlah, harga_satuan, subtotal, keterangan, status_detail_order) VALUES
(1016, 107, 1, 2, 45000, 90000, 'Rendang Minang favorit', 'Disajikan'),
(1017, 107, 3, 1, 35000, 35000, 'Nasi Liwet Solo', 'Disajikan'),
(1018, 107, 13, 2, 22000, 44000, 'Es Cendol Durian', 'Disajikan')
ON CONFLICT (id_detail_order) DO NOTHING;

INSERT INTO tb_transaksi (id_transaksi, id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran, created_at)
VALUES (
    207, 
    COALESCE((SELECT id_user FROM tb_user WHERE username = 'kasir' LIMIT 1), (SELECT id_user FROM tb_user WHERE id_level = 3 LIMIT 1), (SELECT id_user FROM tb_user LIMIT 1)), 
    107, 
    CURRENT_DATE, 
    169000, 
    169000, 
    0, 
    'QRIS', 
    CURRENT_TIMESTAMP
)
ON CONFLICT (id_transaksi) DO NOTHING;

-- Sesuaikan urutan Sequence ID
SELECT setval(pg_get_serial_sequence('tb_order', 'id_order'), COALESCE(MAX(id_order), 1)) FROM tb_order;
SELECT setval(pg_get_serial_sequence('tb_detail_order', 'id_detail_order'), COALESCE(MAX(id_detail_order), 1)) FROM tb_detail_order;
SELECT setval(pg_get_serial_sequence('tb_transaksi', 'id_transaksi'), COALESCE(MAX(id_transaksi), 1)) FROM tb_transaksi;

-- ============================================================
-- 9. COMPATIBILITY VIEWS (DUAL-NAMING SUPPORT: 'user' & 'tb_user')
-- Memungkinkan query dengan atau tanpa prefix 'tb_' secara transparan.
-- Di PostgreSQL 9.3+, simple view secara otomatis updatable (INSERT/UPDATE/DELETE).
-- ============================================================
CREATE OR REPLACE VIEW "level" AS SELECT * FROM tb_level;
CREATE OR REPLACE VIEW "user" AS SELECT * FROM tb_user;
CREATE OR REPLACE VIEW "masakan" AS SELECT * FROM tb_masakan;
CREATE OR REPLACE VIEW "meja" AS SELECT * FROM tb_meja;
CREATE OR REPLACE VIEW "order" AS SELECT * FROM tb_order;
CREATE OR REPLACE VIEW "detail_order" AS SELECT * FROM tb_detail_order;
CREATE OR REPLACE VIEW "transaksi" AS SELECT * FROM tb_transaksi;

-- ============================================================
-- 10. ROW LEVEL SECURITY (RLS) & PUBLIC GRANT FOR SUPABASE
-- Mengaktifkan izin penuh kepada role 'anon' dan 'authenticated'
-- agar koneksi aplikasi Flutter dapat membaca dan menulis data tanpa kendala.
-- ============================================================
ALTER TABLE tb_level ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_meja ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_masakan ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_detail_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_transaksi ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_user_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_payment_mutasi ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_log_aktivitas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all tb_level" ON tb_level;
CREATE POLICY "Allow all tb_level" ON tb_level FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_user" ON tb_user;
CREATE POLICY "Allow all tb_user" ON tb_user FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_meja" ON tb_meja;
CREATE POLICY "Allow all tb_meja" ON tb_meja FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_masakan" ON tb_masakan;
CREATE POLICY "Allow all tb_masakan" ON tb_masakan FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_order" ON tb_order;
CREATE POLICY "Allow all tb_order" ON tb_order FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_detail_order" ON tb_detail_order;
CREATE POLICY "Allow all tb_detail_order" ON tb_detail_order FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_transaksi" ON tb_transaksi;
CREATE POLICY "Allow all tb_transaksi" ON tb_transaksi FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_user_payment_methods" ON tb_user_payment_methods;
CREATE POLICY "Allow all tb_user_payment_methods" ON tb_user_payment_methods FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_payment_mutasi" ON tb_payment_mutasi;
CREATE POLICY "Allow all tb_payment_mutasi" ON tb_payment_mutasi FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all tb_log_aktivitas" ON tb_log_aktivitas;
CREATE POLICY "Allow all tb_log_aktivitas" ON tb_log_aktivitas FOR ALL USING (true) WITH CHECK (true);

-- Grant privileges ke anon, authenticated, dan service_role
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

-- Selesai! Skema database Restoran Rasantara siap digunakan.
