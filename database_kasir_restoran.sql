-- ============================================================
-- DATABASE UJI KOMPETENSI KEAHLIAN (UKK) REKAYASA PERANGKAT LUNAK
-- TAHUN PELAJARAN 2026/2027
-- Paket 1 (Kode: 2134)
-- Judul Tugas : Aplikasi Kasir Restoran (Table Service)
-- DIALECT    : PostgreSQL / SUPABASE
-- ============================================================

-- Catatan Supabase:
-- 1. Jalankan script ini langsung di Supabase SQL Editor.
-- 2. Jangan gunakan 'CREATE DATABASE' atau 'USE db' karena Supabase sudah mengelola database bawaan (public schema).
-- 3. Script ini aman dijalankan berulang kali (clean re-run).

-- ============================================================
-- CLEANUP / RESET TABEL SEBELUMNYA (JIKA ADA)
-- ============================================================
DROP TABLE IF EXISTS tb_log_aktivitas CASCADE;
DROP TABLE IF EXISTS tb_transaksi CASCADE;
DROP TABLE IF EXISTS tb_detail_order CASCADE;
DROP TABLE IF EXISTS tb_order CASCADE;
DROP TABLE IF EXISTS tb_masakan CASCADE;
DROP TABLE IF EXISTS tb_meja CASCADE;
DROP TABLE IF EXISTS tb_user CASCADE;
DROP TABLE IF EXISTS tb_level CASCADE;

-- Drop functions lama jika ada
DROP FUNCTION IF EXISTS sp_google_login CASCADE;
DROP FUNCTION IF EXISTS sp_proses_transaksi CASCADE;
DROP FUNCTION IF EXISTS sp_laporan_harian CASCADE;
DROP FUNCTION IF EXISTS sp_laporan_bulanan CASCADE;
DROP FUNCTION IF EXISTS sp_menu_terlaris CASCADE;
DROP FUNCTION IF EXISTS set_updated_at CASCADE;


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
-- 2. TABEL USER / PENGGUNA (DUKUNGAN GOOGLE OAUTH)
-- ============================================================
CREATE TABLE tb_user (
    id_user SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    password VARCHAR(255) DEFAULT NULL,
    nama_user VARCHAR(100) NOT NULL,
    id_level INT NOT NULL DEFAULT 5 REFERENCES tb_level(id_level) ON DELETE RESTRICT ON UPDATE CASCADE,
    foto_profil VARCHAR(500) DEFAULT NULL,
    -- Google OAuth
    auth_provider VARCHAR(20) NOT NULL DEFAULT 'local' CHECK (auth_provider IN ('local', 'google', 'both')),
    google_uid VARCHAR(128) UNIQUE DEFAULT NULL,
    google_email VARCHAR(150) UNIQUE DEFAULT NULL,
    google_photo VARCHAR(500) DEFAULT NULL,
    -- Metadata
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_google_uid ON tb_user(google_uid);
CREATE INDEX idx_user_google_email ON tb_user(google_email);
CREATE INDEX idx_user_auth_provider ON tb_user(auth_provider);

-- Trigger auto-update field updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_user_updated_at
BEFORE UPDATE ON tb_user
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Akun demo bawaan UKK
INSERT INTO tb_user (id_user, username, password, nama_user, id_level, auth_provider) VALUES
(1, 'admin',     'admin123',     'Ahmad Administrator', 1, 'local'),
(2, 'waiter',    'waiter123',    'Budi Waiter',         2, 'local'),
(3, 'kasir',     'kasir123',     'Citra Kasir',         3, 'local'),
(4, 'owner',     'owner123',     'Dedi Pemilik',        4, 'local'),
(5, 'pelanggan', 'pelanggan123', 'Eka Pelanggan',       5, 'local');

SELECT setval(pg_get_serial_sequence('tb_user', 'id_user'), COALESCE(MAX(id_user), 1)) FROM tb_user;


-- ============================================================
-- 3. TABEL MEJA (TABLE SERVICE)
-- ============================================================
CREATE TABLE tb_meja (
    id_meja SERIAL PRIMARY KEY,
    nomor_meja VARCHAR(10) NOT NULL UNIQUE,
    kapasitas INT NOT NULL DEFAULT 4,
    status_meja VARCHAR(20) NOT NULL DEFAULT 'Kosong' CHECK (status_meja IN ('Kosong', 'Terisi', 'Reservasi'))
);

INSERT INTO tb_meja (id_meja, nomor_meja, kapasitas, status_meja) VALUES
(1, 'Meja 01', 2, 'Kosong'),
(2, 'Meja 02', 4, 'Terisi'),
(3, 'Meja 03', 4, 'Kosong'),
(4, 'Meja 04', 6, 'Kosong'),
(5, 'Meja 05', 2, 'Kosong'),
(6, 'Meja 06', 4, 'Reservasi'),
(7, 'Meja 07', 8, 'Kosong'),
(8, 'Meja 08', 4, 'Kosong');

SELECT setval(pg_get_serial_sequence('tb_meja', 'id_meja'), COALESCE(MAX(id_meja), 1)) FROM tb_meja;


-- ============================================================
-- 4. TABEL MASAKAN / MENU
-- ============================================================
CREATE TABLE tb_masakan (
    id_masakan SERIAL PRIMARY KEY,
    nama_masakan VARCHAR(100) NOT NULL,
    kategori VARCHAR(20) NOT NULL DEFAULT 'Makanan' CHECK (kategori IN ('Makanan', 'Minuman', 'Paket')),
    harga INT NOT NULL,
    deskripsi TEXT DEFAULT NULL,
    gambar VARCHAR(500) DEFAULT NULL,
    status_masakan VARCHAR(20) NOT NULL DEFAULT 'Tersedia' CHECK (status_masakan IN ('Tersedia', 'Habis')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_masakan_kategori ON tb_masakan(kategori);
CREATE INDEX idx_masakan_status ON tb_masakan(status_masakan);

INSERT INTO tb_masakan (id_masakan, nama_masakan, kategori, harga, status_masakan) VALUES
(1,  'Nasi Goreng Spesial',                          'Makanan',  25000,  'Tersedia'),
(2,  'Ayam Bakar Madu',                               'Makanan',  32000,  'Tersedia'),
(3,  'Mie Goreng Seafood',                             'Makanan',  28000,  'Tersedia'),
(4,  'Sop Buntut Sapi',                                'Makanan',  45000,  'Tersedia'),
(5,  'Sate Ayam Madura (10 tsk)',                      'Makanan',  30000,  'Tersedia'),
(6,  'Es Teh Manis',                                   'Minuman',   6000,  'Tersedia'),
(7,  'Es Jeruk Peras',                                 'Minuman',   9000,  'Tersedia'),
(8,  'Jus Alpukat Kocok',                              'Minuman',  16000,  'Tersedia'),
(9,  'Kopi Susu Gula Aren',                            'Minuman',  18000,  'Tersedia'),
(10, 'Paket Hemat Pelajar (Nasi + Ayam + Es Teh)',     'Paket',    27000,  'Tersedia'),
(11, 'Paket Keluarga 4 Orang',                         'Paket',   125000,  'Tersedia');

SELECT setval(pg_get_serial_sequence('tb_masakan', 'id_masakan'), COALESCE(MAX(id_masakan), 1)) FROM tb_masakan;


-- ============================================================
-- 5. TABEL ORDER (PESANAN)
-- ============================================================
CREATE TABLE tb_order (
    id_order SERIAL PRIMARY KEY,
    no_meja VARCHAR(10) NOT NULL,
    nama_pelanggan VARCHAR(100) NOT NULL,
    tanggal TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_user INT NOT NULL REFERENCES tb_user(id_user) ON DELETE RESTRICT ON UPDATE CASCADE,
    keterangan TEXT DEFAULT NULL,
    status_order VARCHAR(20) NOT NULL DEFAULT 'Menunggu' CHECK (status_order IN ('Menunggu', 'Diproses', 'Selesai', 'Dibatalkan'))
);

CREATE INDEX idx_order_status ON tb_order(status_order);
CREATE INDEX idx_order_tanggal ON tb_order(tanggal);


-- ============================================================
-- 6. TABEL DETAIL ORDER
-- ============================================================
CREATE TABLE tb_detail_order (
    id_detail_order SERIAL PRIMARY KEY,
    id_order INT NOT NULL REFERENCES tb_order(id_order) ON DELETE CASCADE ON UPDATE CASCADE,
    id_masakan INT NOT NULL REFERENCES tb_masakan(id_masakan) ON DELETE RESTRICT ON UPDATE CASCADE,
    jumlah INT NOT NULL DEFAULT 1,
    subtotal INT NOT NULL,
    keterangan VARCHAR(255) DEFAULT '',
    status_detail_order VARCHAR(20) NOT NULL DEFAULT 'Menunggu' CHECK (status_detail_order IN ('Menunggu', 'Dimasak', 'Disajikan'))
);


-- ============================================================
-- 7. TABEL TRANSAKSI (PEMBAYARAN)
-- ============================================================
CREATE TABLE tb_transaksi (
    id_transaksi SERIAL PRIMARY KEY,
    id_user INT NOT NULL REFERENCES tb_user(id_user) ON DELETE RESTRICT ON UPDATE CASCADE,
    id_order INT NOT NULL REFERENCES tb_order(id_order) ON DELETE RESTRICT ON UPDATE CASCADE,
    tanggal TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_bayar INT NOT NULL,
    jumlah_bayar INT NOT NULL,
    kembalian INT NOT NULL DEFAULT 0,
    metode_pembayaran VARCHAR(30) NOT NULL DEFAULT 'Tunai' CHECK (metode_pembayaran IN ('Tunai', 'QRIS', 'Kartu Debit', 'Kartu Kredit', 'Transfer Bank'))
);

CREATE INDEX idx_transaksi_tanggal ON tb_transaksi(tanggal);
CREATE INDEX idx_transaksi_metode ON tb_transaksi(metode_pembayaran);


-- ============================================================
-- 8. TABEL LOG AKTIVITAS (AUDIT TRAIL)
-- ============================================================
CREATE TABLE tb_log_aktivitas (
    id_log SERIAL PRIMARY KEY,
    id_user INT REFERENCES tb_user(id_user) ON DELETE SET NULL ON UPDATE CASCADE,
    aksi VARCHAR(100) NOT NULL,
    detail TEXT DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_log_aksi ON tb_log_aktivitas(aksi);
CREATE INDEX idx_log_waktu ON tb_log_aktivitas(created_at);


-- ============================================================
-- SUPABASE ROW LEVEL SECURITY (RLS) & POLICIES
-- ============================================================
-- Mengaktifkan RLS dan memberikan full access ke anon & authenticated
-- agar aplikasi Flutter dapat langsung membaca dan menulis data.

ALTER TABLE tb_level ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_meja ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_masakan ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_detail_order ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_transaksi ENABLE ROW LEVEL SECURITY;
ALTER TABLE tb_log_aktivitas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public full access tb_level" ON tb_level FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_user" ON tb_user FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_meja" ON tb_meja FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_masakan" ON tb_masakan FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_order" ON tb_order FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_detail_order" ON tb_detail_order FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_transaksi" ON tb_transaksi FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public full access tb_log_aktivitas" ON tb_log_aktivitas FOR ALL USING (true) WITH CHECK (true);


-- ============================================================
-- STORED FUNCTIONS / RPC (PL/pgSQL) UNTUK SUPABASE
-- ============================================================

-- 1. Function: Login / Register via Google OAuth
-- Bisa dipanggil langsung lewat Supabase RPC: supabase.rpc('sp_google_login', {...})
CREATE OR REPLACE FUNCTION sp_google_login(
    p_google_uid TEXT,
    p_google_email TEXT,
    p_nama TEXT,
    p_google_photo TEXT DEFAULT NULL
)
RETURNS TABLE (
    id_user INT,
    username VARCHAR,
    nama_user VARCHAR,
    id_level INT,
    nama_level VARCHAR,
    auth_provider VARCHAR,
    google_email VARCHAR,
    google_photo VARCHAR
) AS $$
DECLARE
    v_user_id INT;
BEGIN
    -- Cek apakah google_uid sudah terdaftar
    SELECT u.id_user INTO v_user_id
    FROM tb_user u
    WHERE u.google_uid = p_google_uid
    LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        UPDATE tb_user
        SET nama_user    = COALESCE(p_nama, tb_user.nama_user),
            google_email = p_google_email,
            google_photo = p_google_photo,
            updated_at   = CURRENT_TIMESTAMP
        WHERE tb_user.id_user = v_user_id;
    ELSE
        -- Cek apakah email sudah terdaftar lewat akun lokal
        SELECT u.id_user INTO v_user_id
        FROM tb_user u
        WHERE u.username = p_google_email OR u.google_email = p_google_email
        LIMIT 1;

        IF v_user_id IS NOT NULL THEN
            UPDATE tb_user
            SET google_uid    = p_google_uid,
                google_email  = p_google_email,
                google_photo  = p_google_photo,
                auth_provider = 'both',
                updated_at    = CURRENT_TIMESTAMP
            WHERE tb_user.id_user = v_user_id;
        ELSE
            -- Buat akun baru sebagai Pelanggan (id_level = 5)
            INSERT INTO tb_user (username, password, nama_user, id_level, auth_provider, google_uid, google_email, google_photo)
            VALUES (p_google_email, NULL, p_nama, 5, 'google', p_google_uid, p_google_email, p_google_photo)
            RETURNING tb_user.id_user INTO v_user_id;
        END IF;
    END IF;

    -- Catat log aktivitas
    INSERT INTO tb_log_aktivitas (id_user, aksi, detail)
    VALUES (v_user_id, 'LOGIN_GOOGLE', 'Login via Google: ' || p_google_email);

    -- Kembalikan data user beserta nama level
    RETURN QUERY
    SELECT u.id_user, u.username, u.nama_user, u.id_level, l.nama_level, u.auth_provider, u.google_email, u.google_photo
    FROM tb_user u
    JOIN tb_level l ON u.id_level = l.id_level
    WHERE u.id_user = v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Function: Selesaikan Transaksi Pembayaran
-- Bisa dipanggil lewat Supabase RPC: supabase.rpc('sp_proses_transaksi', {...})
CREATE OR REPLACE FUNCTION sp_proses_transaksi(
    p_id_user INT,
    p_id_order INT,
    p_total_bayar INT,
    p_jumlah_bayar INT,
    p_metode VARCHAR,
    p_no_meja VARCHAR
)
RETURNS JSON AS $$
DECLARE
    v_kembalian INT;
    v_id_transaksi INT;
BEGIN
    v_kembalian := p_jumlah_bayar - p_total_bayar;

    INSERT INTO tb_transaksi (id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran)
    VALUES (p_id_user, p_id_order, CURRENT_TIMESTAMP, p_total_bayar, p_jumlah_bayar, v_kembalian, p_metode)
    RETURNING id_transaksi INTO v_id_transaksi;

    UPDATE tb_order SET status_order = 'Selesai' WHERE id_order = p_id_order;
    UPDATE tb_meja SET status_meja = 'Kosong' WHERE nomor_meja = p_no_meja;

    INSERT INTO tb_log_aktivitas (id_user, aksi, detail)
    VALUES (p_id_user, 'TRANSAKSI', 'Order #' || p_id_order || ' - Total Rp ' || p_total_bayar || ' (' || p_metode || ')');

    RETURN json_build_object(
        'success', true,
        'id_transaksi', v_id_transaksi,
        'kembalian', v_kembalian
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. Function: Rekap Laporan Penjualan Harian
CREATE OR REPLACE FUNCTION sp_laporan_harian(p_tanggal DATE)
RETURNS TABLE (
    id_transaksi INT,
    tanggal TIMESTAMPTZ,
    kasir VARCHAR,
    nama_pelanggan VARCHAR,
    no_meja VARCHAR,
    total_bayar INT,
    metode_pembayaran VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id_transaksi,
        t.tanggal,
        u.nama_user AS kasir,
        o.nama_pelanggan,
        o.no_meja,
        t.total_bayar,
        t.metode_pembayaran
    FROM tb_transaksi t
    JOIN tb_user u ON t.id_user = u.id_user
    JOIN tb_order o ON t.id_order = o.id_order
    WHERE CAST(t.tanggal AS DATE) = p_tanggal
    ORDER BY t.tanggal DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Function: Rekap Laporan Penjualan Bulanan
CREATE OR REPLACE FUNCTION sp_laporan_bulanan(p_bulan INT, p_tahun INT)
RETURNS TABLE (
    tanggal DATE,
    jumlah_transaksi BIGINT,
    total_pendapatan BIGINT,
    metode_digunakan TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        CAST(t.tanggal AS DATE) AS tgl,
        COUNT(t.id_transaksi) AS jml_transaksi,
        COALESCE(SUM(t.total_bayar), 0)::BIGINT AS total_pndptn,
        STRING_AGG(DISTINCT t.metode_pembayaran, ', ') AS metode_list
    FROM tb_transaksi t
    WHERE EXTRACT(MONTH FROM t.tanggal)::INT = p_bulan
      AND EXTRACT(YEAR FROM t.tanggal)::INT = p_tahun
    GROUP BY CAST(t.tanggal AS DATE)
    ORDER BY tgl ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. Function: Menu Terlaris
CREATE OR REPLACE FUNCTION sp_menu_terlaris(p_limit INT)
RETURNS TABLE (
    id_masakan INT,
    nama_masakan VARCHAR,
    kategori VARCHAR,
    harga INT,
    total_terjual BIGINT,
    total_pendapatan BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id_masakan,
        m.nama_masakan,
        m.kategori,
        m.harga,
        COALESCE(SUM(d.jumlah), 0)::BIGINT AS terjual,
        COALESCE(SUM(d.subtotal), 0)::BIGINT AS pendapatan
    FROM tb_detail_order d
    JOIN tb_masakan m ON d.id_masakan = m.id_masakan
    JOIN tb_order o ON d.id_order = o.id_order
    WHERE o.status_order = 'Selesai'
    GROUP BY m.id_masakan, m.nama_masakan, m.kategori, m.harga
    ORDER BY terjual DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
