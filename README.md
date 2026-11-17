<p align="center">
  <img src="assets/images/Rasantara Cloche App Icon.png" alt="Rasantara Logo" width="120" style="border-radius: 20px;" />
</p>

<h1 align="center">RASANTARA — RESTAURANT OPERATING SYSTEM & POS</h1>

<p align="center">
  <strong>Enterprise-Grade Table Service Management, Customer Self-Order, and Point of Sale System</strong><br>
  <em>Built with Flutter Multi-Platform and Supabase PostgreSQL</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%3E%3D3.3.0-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Database-PostgreSQL%20%2F%20Supabase-3ECF8E?logo=supabase&logoColor=white" alt="Supabase PostgreSQL" />
  <img src="https://img.shields.io/badge/Platform-Windows%20%7C%20Web%20%7C%20Android-EA580C" alt="Platforms" />
  <img src="https://img.shields.io/badge/Tests-22%2F22%20Passing-16A34A" alt="Tests" />
  <img src="https://img.shields.io/badge/Architecture-Clean%20%2F%20Offline--First-0F172A" alt="Architecture" />
</p>

---

## Ringkasan Eksekutif

**Rasantara** adalah sistem operasional restoran modern dan *Point of Sale* (POS) terintegrasi yang dirancang untuk mengotomatisasi alur pemesanan meja (*Table Service*), alur pesanan mandiri tamu (*Customer Self-Order via QR Code*), hingga pemrosesan transaksi keuangan di kasir secara *real-time*.

Aplikasi ini dikembangkan sebagai pemenuhan instrumen verifikasi **Uji Kompetensi Keahlian (UKK) Rekayasa Perangkat Lunak**:
* **Paket Soal:** Paket 1 — Aplikasi Kasir Restoran (Kode: 2134)
* **Penyusun:** Muhammad Nazril Putra Natrabu
* **Program Keahlian:** Pengembangan Perangkat Lunak dan GIM (PPLG)
* **Institusi:** SMK Bakti Nusantara 666

---

## Hak Akses Pengguna (Role-Based Access Control)

Sistem menerapkan kontrol otorisasi granular berbasis 5 tingkatan pengguna (*Five-Tier RBAC*) untuk menjaga integritas data transaksi dan pemisahan tugas operasional (*Separation of Duties*):

| Tingkat Pengguna | Tanggung Jawab Operasional | Modul yang Dapat Diakses | Otoritas Cetak Struk |
| :--- | :--- | :--- | :---: |
| **Administrator** | Manajemen sistem penuh, master data, audit user, dan kelola meja | Seluruh modul sistem, Manajemen User, Kelola Menu & Meja, Analitik, Berlangganan | Penuh (Pratinjau & Cetak Fisik) |
| **Kasir** | Pemrosesan pembayaran transaksi (Tunai/QRIS), verifikasi kas masuk | Entri Transaksi Kasir, Riwayat Pesanan, Laporan Keuangan Harian, Profil Akun | Penuh (Pratinjau & Cetak Fisik) |
| **Waiter** | Pelayanan tamu, pemesanan hidangan meja kosong, koordinasi hidangan | Entri Order Meja, Monitor Ketersediaan Meja, Riwayat Pesanan, Profil Akun | Terbatas (Hanya Pratinjau Struk) |
| **Owner** | Pemantauan kinerja bisnis, audit omzet harian/bulanan, tren penjualan | Dashboard Metrik Eksekutif, Laporan Omzet, Grafik Analitik Penjualan, Profil | Terbatas (Hanya Pratinjau Struk) |
| **Pelanggan** | Pemesanan mandiri melalui pemindaian stiker QR meja, pelacakan pesanan | Scan QR Meja Otomatis, Menu Hidangan Meja, Live Order Tracker, Profil | Terbatas (Hanya Pratinjau Struk) |

---

## Spesifikasi Fungsional Sistem

### 1. Alur Pesanan Mandiri Pelanggan (QR Code Table Self-Order)
* **Pindai QR Presisi:** Pelanggan mengakses antarmuka pemindaian kamera berbingkai fokus (*viewport frame*) dengan deteksi instan payload kode meja.
* **Pencegahan Human-Error:** Akses hidangan terkunci sebelum meja terverifikasi, memastikan setiap pesanan terikat valid ke nomor meja fisik restoran.
* **Live Order Tracker:** Status hidangan terpantau secara transparan melalui tahapan antrean, persiapan dapur koki, pengantaran meja oleh waiter, hingga selesai disajikan.

### 2. Generator Kartu Stiker QR Meja (PNG & PDF Export)
* **Ekspor Kartu PNG Resolusi Tinggi:** Menghasilkan stiker meja berformat grafis lengkap (600 DPI) memuat logo resmi Rasantara, QR code beresolusi tinggi, nomor meja, dan panduan kapasitas tamu.
* **Dokumen PDF Siap Cetak:** Format presisi dimensi stiker 100 × 130 mm dan lembar multi-stiker A4 terpadu yang terintegrasi langsung dengan dialog cetak sistem operasi (*Native Print Dialog*).

### 3. Pemrosesan Transaksi Kasir Pintar (Smart POS Cashier)
* **Format Mata Uang Otomatis:** Input nominal tunai dilengkapi pemisah ribuan dinamis untuk mencegah kesalahan entri kasir.
* **Kalkulasi Kembalian Real-Time:** Perhitungan otomatis selisih pembayaran dan kembalian secara instan.
* **Integrasi Pembayaran Digital (QRIS):** Mendukung pembayaran nontunai QRIS dinamis yang siap dipindai oleh seluruh aplikasi perbankan dan e-wallet nasional.
* **Thermal Printing Standar POS:** Layout struk termal ukuran standar 76mm/80mm memuat nomor transaksi, identitas kasir, rincian menu, tarif pajak restoran (PB1), potongan member, dan QR survei kepuasan pelanggan.

### 4. Dasbor Analitik & Pelaporan Finansial
* **Metrik Keuangan Harian & Periodik:** Pemantauan omzet total, laba kotor, volume transaksi harian, dan rata-rata belanja tamu (*Average Order Value*).
* **Visualisasi Tren Penjualan:** Grafik analitik pergerakan pendapatan 7 hari terakhir dan analisis kategori hidangan paling diminati (*Best Seller Ranking*).
* **Ekspor Laporan:** Dukungan ekspor laporan rekapitulasi penjualan ke dalam format PDF dan file spreadsheet CSV.

---

## Arsitektur Teknis & Dependensi

```text
[ Presentation Layer ]  Flutter UI Widgets (Material 3 Theme Engine)
         │
[ State & Domain ]     DatabaseService (ChangeNotifier & Event-Driven)
         │
    ┌────┴───────────────────────────┐
    ▼                                ▼
[ Local Persistence ]      [ Cloud Backend ]
SharedPreferences Engine    Supabase Cloud PostgreSQL
(Offline-First Cache)       (Remote Sync & REST Data Source)
```

* **Framework:** Flutter SDK `>=3.3.0` / Dart SDK `>=3.0.0`
* **Manajemen State:** Provider Pattern (`ChangeNotifier` & reactive listeners)
* **Database Backend:** PostgreSQL via Supabase PostgREST
* **Penyimpanan Lokal:** `shared_preferences` dengan mekanisme fallback offline
* **Format Dokumen:** `pdf: ^3.13.1` & `printing: ^5.15.1`
* **Pemrosesan Barcode:** `qr_flutter: ^4.1.0` & `mobile_scanner: ^5.2.3`

---

## Struktur Direktori Repositori

```text
UJIKOM-COKKK/
├── assets/
│   └── images/
│       ├── Rasantara Cloche App Icon.png   # Identitas visual aplikasi Rasantara
│       └── logo_smk_baknus_666.png         # Logo instansi pendidikan
├── lib/
│   ├── main.dart                           # Titik masuk aplikasi & routing otentikasi
│   ├── models/                             # Definisi data model (Order, Menu, User, Table, Trx)
│   ├── screens/
│   │   ├── auth/                           # Dialog onboarding pengguna Google OAuth
│   │   ├── cashier/                        # Antarmuka kasir & riwayat transaksi restoran
│   │   ├── dashboard/                      # Dasbor metrik eksekutif Owner & Administrator
│   │   ├── order/                          # Entri pesanan waiter & alur QR mandiri pelanggan
│   │   ├── profile/                        # Konfigurasi akun, preferensi tema, & audit profil
│   │   ├── reference/                      # Modul manajemen master data menu & meja restoran
│   │   ├── reports/                        # Pelaporan pendapatan & ekspor rekapitulasi
│   │   ├── subscription/                   # Modul langganan keanggotaan VIP pelanggan
│   │   └── users/                          # Pengelolaan data hak akses dan akun pegawai
│   ├── services/                           # Lapisan layanan (Database, Supabase, Ekspor, Audio)
│   ├── theme/                              # Konfigurasi palet warna & tipografi Material 3
│   └── widgets/                            # Komponen visual modular (Struk, QRIS, Analitik)
├── test/
│   ├── login_email_and_settings_test.dart  # Pengujian otentikasi dan preferensi sistem
│   ├── supabase_google_test.dart           # Pengujian integrasi skema cloud dan mapping model
│   └── widget_test.dart                    # Pengujian otomasi widget antarmuka seluruh peran
├── rasantara_database.sql                  # Skrip DDL & DML skema database PostgreSQL
└── README.md
```

---

## Petunjuk Instalasi & Menjalankan Aplikasi

### Prasyarat
1. Flutter SDK terpasang (versi `>=3.3.0`).
2. Dart SDK terpasang (versi `>=3.0.0`).
3. Google Chrome (untuk Web target) atau perangkat Windows / Android.

### Langkah Menjalankan
```bash
# 1. Kloning repositori
git clone https://github.com/ENDY1807/UJIKOM-COKKK.git
cd UJIKOM-COKKK

# 2. Unduh seluruh dependensi paket
flutter pub get

# 3. Jalankan verifikasi statis kode
flutter analyze

# 4. Jalankan rangkaian automated testing
flutter test

# 5. Jalankan aplikasi pada platform yang dituju
flutter run -d chrome     # Target Web Browser
flutter run -d windows    # Target Windows Desktop
```

---

## Kredensial Pengujian Sistem (Demo Akun)

| Peran Akun | Username | Password | Otoritas Utama |
| :--- | :--- | :--- | :--- |
| **Administrator** | `admin` | `admin123` | Master Menu, Meja, User, Transaksi, Laporan |
| **Kasir** | `kasir` | `kasir123` | Entri Transaksi, Pembayaran QRIS/Tunai, Cetak Struk |
| **Waiter** | `waiter` | `waiter123` | Entri Pesanan Meja Tamu, Cek Meja Kosong |
| **Owner** | `owner` | `owner123` | Analitik Omzet, Laporan Penjualan, Audit Bisnis |
| **Pelanggan VIP** | `pelanggan` | `pelanggan123` | Scan QR Meja, Diskon Otomatis Member 10% |
| **Pelanggan Reguler** | `pelanggan_reguler` | `pelanggan123` | Scan QR Meja, Pesan Mandiri |

---

<p align="center">
  <strong>Proyek Uji Kompetensi Keahlian (UKK) Rekayasa Perangkat Lunak 2026/2027</strong><br>
  SMK Bakti Nusantara 666 — Bandung
</p>
