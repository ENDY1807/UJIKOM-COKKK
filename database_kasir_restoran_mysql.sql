-- ============================================================
-- DATABASE UJI KOMPETENSI KEAHLIAN (UKK) REKAYASA PERANGKAT LUNAK
-- TAHUN PELAJARAN 2026/2027
-- Paket 1 (Kode: 2134)
-- Judul Tugas : Aplikasi Kasir Restoran (Table Service)
-- DIALECT: MySQL / MariaDB (XAMPP / Laragon / phpMyAdmin)
-- ============================================================

DROP DATABASE IF EXISTS db_kasir_restoran;
CREATE DATABASE db_kasir_restoran CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE db_kasir_restoran;

-- ============================================================
-- 1. Tabel Level Hak Akses
-- ============================================================
CREATE TABLE tb_level (
    id_level INT AUTO_INCREMENT PRIMARY KEY,
    nama_level VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

INSERT INTO tb_level (id_level, nama_level) VALUES
(1, 'Administrator'),
(2, 'Waiter'),
(3, 'Kasir'),
(4, 'Owner'),
(5, 'Pelanggan');

-- ============================================================
-- 2. Tabel User / Pengguna (dengan dukungan Google OAuth)
-- ============================================================
CREATE TABLE tb_user (
    id_user INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    password VARCHAR(255) DEFAULT NULL,
    nama_user VARCHAR(100) NOT NULL,
    id_level INT NOT NULL DEFAULT 5,
    foto_profil VARCHAR(500) DEFAULT NULL,
    -- Kolom Google OAuth
    auth_provider ENUM('local', 'google', 'both') NOT NULL DEFAULT 'local',
    google_uid VARCHAR(128) UNIQUE DEFAULT NULL,
    google_email VARCHAR(150) UNIQUE DEFAULT NULL,
    google_photo VARCHAR(500) DEFAULT NULL,
    -- Metadata
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (id_level) REFERENCES tb_level(id_level) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_google_uid (google_uid),
    INDEX idx_google_email (google_email),
    INDEX idx_auth_provider (auth_provider)
) ENGINE=InnoDB;

INSERT INTO tb_user (id_user, username, password, nama_user, id_level, auth_provider) VALUES
(1, 'admin',     'admin123',     'Ahmad Administrator', 1, 'local'),
(2, 'waiter',    'waiter123',    'Budi Waiter',         2, 'local'),
(3, 'kasir',     'kasir123',     'Citra Kasir',         3, 'local'),
(4, 'owner',     'owner123',     'Dedi Pemilik',        4, 'local'),
(5, 'pelanggan', 'pelanggan123', 'Eka Pelanggan',       5, 'local');

-- ============================================================
-- 3. Tabel Meja (Table Service)
-- ============================================================
CREATE TABLE tb_meja (
    id_meja INT AUTO_INCREMENT PRIMARY KEY,
    nomor_meja VARCHAR(10) NOT NULL UNIQUE,
    kapasitas INT NOT NULL DEFAULT 4,
    status_meja ENUM('Kosong', 'Terisi', 'Reservasi') NOT NULL DEFAULT 'Kosong'
) ENGINE=InnoDB;

INSERT INTO tb_meja (id_meja, nomor_meja, kapasitas, status_meja) VALUES
(1, 'Meja 01', 2, 'Kosong'),
(2, 'Meja 02', 4, 'Terisi'),
(3, 'Meja 03', 4, 'Kosong'),
(4, 'Meja 04', 6, 'Kosong'),
(5, 'Meja 05', 2, 'Kosong'),
(6, 'Meja 06', 4, 'Reservasi'),
(7, 'Meja 07', 8, 'Kosong'),
(8, 'Meja 08', 4, 'Kosong');

-- ============================================================
-- 4. Tabel Masakan / Menu
-- ============================================================
CREATE TABLE tb_masakan (
    id_masakan INT AUTO_INCREMENT PRIMARY KEY,
    nama_masakan VARCHAR(100) NOT NULL,
    kategori ENUM('Makanan', 'Minuman', 'Paket') NOT NULL DEFAULT 'Makanan',
    harga INT NOT NULL,
    deskripsi TEXT DEFAULT NULL,
    gambar VARCHAR(500) DEFAULT NULL,
    status_masakan ENUM('Tersedia', 'Habis') NOT NULL DEFAULT 'Tersedia',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_kategori (kategori),
    INDEX idx_status (status_masakan)
) ENGINE=InnoDB;

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

-- ============================================================
-- 5. Tabel Order (Pesanan)
-- ============================================================
CREATE TABLE tb_order (
    id_order INT AUTO_INCREMENT PRIMARY KEY,
    no_meja VARCHAR(10) NOT NULL,
    nama_pelanggan VARCHAR(100) NOT NULL,
    tanggal DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_user INT NOT NULL,
    keterangan TEXT DEFAULT NULL,
    status_order ENUM('Menunggu', 'Diproses', 'Selesai', 'Dibatalkan') NOT NULL DEFAULT 'Menunggu',
    FOREIGN KEY (id_user) REFERENCES tb_user(id_user) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_status_order (status_order),
    INDEX idx_tanggal (tanggal)
) ENGINE=InnoDB;

-- ============================================================
-- 6. Tabel Detail Order
-- ============================================================
CREATE TABLE tb_detail_order (
    id_detail_order INT AUTO_INCREMENT PRIMARY KEY,
    id_order INT NOT NULL,
    id_masakan INT NOT NULL,
    jumlah INT NOT NULL DEFAULT 1,
    subtotal INT NOT NULL,
    keterangan VARCHAR(255) DEFAULT '',
    status_detail_order ENUM('Menunggu', 'Dimasak', 'Disajikan') NOT NULL DEFAULT 'Menunggu',
    FOREIGN KEY (id_order) REFERENCES tb_order(id_order) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (id_masakan) REFERENCES tb_masakan(id_masakan) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 7. Tabel Transaksi
-- ============================================================
CREATE TABLE tb_transaksi (
    id_transaksi INT AUTO_INCREMENT PRIMARY KEY,
    id_user INT NOT NULL,
    id_order INT NOT NULL,
    tanggal DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_bayar INT NOT NULL,
    jumlah_bayar INT NOT NULL,
    kembalian INT NOT NULL DEFAULT 0,
    metode_pembayaran ENUM('Tunai', 'QRIS', 'Kartu Debit', 'Kartu Kredit', 'Transfer Bank') NOT NULL DEFAULT 'Tunai',
    FOREIGN KEY (id_user) REFERENCES tb_user(id_user) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (id_order) REFERENCES tb_order(id_order) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_tanggal_transaksi (tanggal),
    INDEX idx_metode (metode_pembayaran)
) ENGINE=InnoDB;

-- ============================================================
-- 8. Tabel Log Aktivitas (Audit Trail)
-- ============================================================
CREATE TABLE tb_log_aktivitas (
    id_log INT AUTO_INCREMENT PRIMARY KEY,
    id_user INT DEFAULT NULL,
    aksi VARCHAR(100) NOT NULL,
    detail TEXT DEFAULT NULL,
    ip_address VARCHAR(45) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_user) REFERENCES tb_user(id_user) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_aksi (aksi),
    INDEX idx_log_waktu (created_at)
) ENGINE=InnoDB;

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

DELIMITER $$

CREATE PROCEDURE sp_google_login(
    IN p_google_uid VARCHAR(128),
    IN p_google_email VARCHAR(150),
    IN p_nama VARCHAR(100),
    IN p_google_photo VARCHAR(500)
)
BEGIN
    DECLARE v_user_id INT DEFAULT NULL;

    SELECT id_user INTO v_user_id
    FROM tb_user
    WHERE google_uid = p_google_uid
    LIMIT 1;

    IF v_user_id IS NOT NULL THEN
        UPDATE tb_user
        SET nama_user    = COALESCE(p_nama, nama_user),
            google_email = p_google_email,
            google_photo = p_google_photo,
            updated_at   = NOW()
        WHERE id_user = v_user_id;
    ELSE
        SELECT id_user INTO v_user_id
        FROM tb_user
        WHERE username = p_google_email OR google_email = p_google_email
        LIMIT 1;

        IF v_user_id IS NOT NULL THEN
            UPDATE tb_user
            SET google_uid    = p_google_uid,
                google_email  = p_google_email,
                google_photo  = p_google_photo,
                auth_provider = 'both',
                updated_at    = NOW()
            WHERE id_user = v_user_id;
        ELSE
            INSERT INTO tb_user (username, password, nama_user, id_level, auth_provider, google_uid, google_email, google_photo)
            VALUES (p_google_email, NULL, p_nama, 5, 'google', p_google_uid, p_google_email, p_google_photo);

            SET v_user_id = LAST_INSERT_ID();
        END IF;
    END IF;

    INSERT INTO tb_log_aktivitas (id_user, aksi, detail)
    VALUES (v_user_id, 'LOGIN_GOOGLE', CONCAT('Login via Google: ', p_google_email));

    SELECT u.*, l.nama_level
    FROM tb_user u
    JOIN tb_level l ON u.id_level = l.id_level
    WHERE u.id_user = v_user_id;
END$$

CREATE PROCEDURE sp_proses_transaksi(
    IN p_id_user INT,
    IN p_id_order INT,
    IN p_total_bayar INT,
    IN p_jumlah_bayar INT,
    IN p_metode VARCHAR(30),
    IN p_no_meja VARCHAR(10)
)
BEGIN
    DECLARE v_kembalian INT;
    SET v_kembalian = p_jumlah_bayar - p_total_bayar;

    INSERT INTO tb_transaksi (id_user, id_order, tanggal, total_bayar, jumlah_bayar, kembalian, metode_pembayaran)
    VALUES (p_id_user, p_id_order, NOW(), p_total_bayar, p_jumlah_bayar, v_kembalian, p_metode);

    UPDATE tb_order SET status_order = 'Selesai' WHERE id_order = p_id_order;

    UPDATE tb_meja SET status_meja = 'Kosong' WHERE nomor_meja = p_no_meja;

    INSERT INTO tb_log_aktivitas (id_user, aksi, detail)
    VALUES (p_id_user, 'TRANSAKSI', CONCAT('Order #', p_id_order, ' - Rp ', FORMAT(p_total_bayar, 0), ' (', p_metode, ')'));
END$$

CREATE PROCEDURE sp_laporan_harian(IN p_tanggal DATE)
BEGIN
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
    WHERE DATE(t.tanggal) = p_tanggal
    ORDER BY t.tanggal DESC;
END$$

CREATE PROCEDURE sp_laporan_bulanan(IN p_bulan INT, IN p_tahun INT)
BEGIN
    SELECT
        DATE(t.tanggal) AS tanggal,
        COUNT(t.id_transaksi) AS jumlah_transaksi,
        SUM(t.total_bayar) AS total_pendapatan,
        GROUP_CONCAT(DISTINCT t.metode_pembayaran) AS metode_digunakan
    FROM tb_transaksi t
    WHERE MONTH(t.tanggal) = p_bulan AND YEAR(t.tanggal) = p_tahun
    GROUP BY DATE(t.tanggal)
    ORDER BY tanggal ASC;
END$$

CREATE PROCEDURE sp_menu_terlaris(IN p_limit INT)
BEGIN
    SELECT
        m.id_masakan,
        m.nama_masakan,
        m.kategori,
        m.harga,
        SUM(d.jumlah) AS total_terjual,
        SUM(d.subtotal) AS total_pendapatan
    FROM tb_detail_order d
    JOIN tb_masakan m ON d.id_masakan = m.id_masakan
    JOIN tb_order o ON d.id_order = o.id_order
    WHERE o.status_order = 'Selesai'
    GROUP BY m.id_masakan, m.nama_masakan, m.kategori, m.harga
    ORDER BY total_terjual DESC
    LIMIT p_limit;
END$$

DELIMITER ;
