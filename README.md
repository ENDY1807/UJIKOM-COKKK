<p align="center">
  <img src="assets/images/Rasantara Cloche App Icon.png" alt="Rasantara Logo" width="130" style="border-radius: 24px; box-shadow: 0 4px 16px rgba(0,0,0,0.12);" />
</p>

<h1 align="center">🍽️ RASANTARA — RESTORAN & POS SYSTEM</h1>

<p align="center">
  <strong>Sistem Informasi Pemesanan Meja (Table Service) & Kasir Pintar Berbasis Flutter Multi-Platform</strong><br>
  <em>Autentik Cita Rasa Kuliner Nusantara</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%3E%3D3.3.0-02569B?logo=flutter&logoColor=white" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Dart-%3E%3D3.0.0-0175C2?logo=dart&logoColor=white" alt="Dart Version" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Web-E44D26" alt="Platforms" />
  <img src="https://img.shields.io/badge/Tests-15%2F15%20Passing-success" alt="Unit & Widget Tests" />
  <img src="https://img.shields.io/badge/Backend-Supabase%20PostgreSQL-3ECF8E?logo=supabase&logoColor=white" alt="Supabase" />
</p>

---

## 📌 Tentang Proyek

**Rasantara** adalah aplikasi sistem kasir (*Point of Sale*) dan manajemen operasional restoran terpadu yang dirancang untuk mempercepat alur kerja dari pemesanan meja (*table service*) hingga transaksi pembayaran di kasir. 

Aplikasi ini dikembangkan untuk memenuhi kriteria kelulusan **Uji Kompetensi Keahlian (UKK) Rekayasa Perangkat Lunak 2026/2027**:
* **Paket Soal:** Paket 1 — Aplikasi Kasir Restoran (Kode: 2134)
* **Pengembang:** Muhammad Nazril Putra Natrabu
* **Kelas:** XII PPLG 2
* **Instansi:** SMK Bakti Nusantara 666

---

## 👥 Hak Akses 5 Level Pengguna (Role-Based Access Control)

Aplikasi ini mengimplementasikan pembagian hak akses (*Role-Based Access Control*) yang ketat dan presisi sesuai standar operasional restoran profesional:

| Role | Ikon | Modul Utama | Akses Struk |
| :--- | :---: | :--- | :---: |
| **Administrator** | 🛡️ | Manajemen Menu, Manajemen User & Pegawai, Entri Transaksi, Riwayat, Laporan, Berlangganan | Pratinjau & Cetak Resmi |
| **Kasir** | 💼 | Entri Transaksi (Tunai/QRIS), Riwayat Pesanan Restoran (Filter & Search), Laporan Penjualan, Profil | Pratinjau & Cetak Resmi |
| **Waiter** | 📋 | Entri Order Meja (Table Service), Pelacakan Meja, Riwayat Pesanan Restoran, Laporan Menu, Profil | Pratinjau Saja *(Tanpa Tombol Cetak)* |
| **Owner** | 👑 | Dasbor Analitik Penjualan, Laporan Omset/Keuangan Lengkap, Riwayat Pesanan, Profil | Pratinjau Saja *(Tanpa Tombol Cetak)* |
| **Pelanggan** | 👤 | Entri Order Mandiri (Self-Order), Riwayat Pesanan Saya, Pelacakan Status Hidangan, Profil | Pratinjau Saja *(Tanpa Tombol Cetak)* |

---

## ✨ Fitur Unggulan

### 1. 💵 Entri Transaksi Kasir Pintar
- **Kesesuaian Metode:** Menampilkan metode pembayaran secara dinamis sesuai pilihan waiter (Tunai / QRIS) dan terkunci otomatis.
- **Pemisah Ribuan Otomatis:** Input nominal pembayaran tunai otomatis memformat titik ribuan (misal: `1000000` menjadi `1.000.000`).
- **Kalkulasi Kembalian Otomatis:** Menghitung sisa kembalian atau kekurangan uang secara *real-time*.
- **Direct Thermal Print:** Transaksi diselesaikan dengan satu klik tombol "Terima Pesanan", langsung memicu pencetakan struk termal resmi tanpa pop-up konfirmasi yang berbelit.

### 2. 🧾 Struk Termal Standar POS (76mm / 80mm)
- Tata letak cetak PDF termal dan dialog pratinjau di dalam aplikasi disinkronkan secara presisi (100% identik).
- Memuat logo kuliner nusantara, nama resto, nomor transaksi & order, nama kasir pemroses, rincian hidangan, subtotal, pajak restoran (PB1), status bayar, kembalian, serta QR Code survei kepuasan pelanggan.

### 3. 🔍 Riwayat Pesanan Restoran Komprehensif
- Dilengkapi fitur pencarian cepat berdasarkan nomor pesanan (#ORD) atau nama meja/tamu.
- Filter tanggal kalender untuk meninjau rekapan transaksi sebelumnya.
- Fitur **Cetak Ulang Struk Resmi** dan **Cetak Slip Tagihan QRIS** khusus untuk Administrator dan Kasir.

### 4. 📱 Tampilan Responsif & Clean Architecture
- **Multi-Device Ready:** Mendukung antarmuka responsif untuk ponsel Android (pelanggan & waiter), tablet dapur, dan layar monitor kasir Desktop (Windows & Web).
- **Dual Mode Synchronization:** Terhubung ke cloud backend PostgreSQL melalui **Supabase**, dengan sistem fallback lokal (*offline-first*) yang memastikan aplikasi tetap berjalan lancar saat demo atau tanpa koneksi internet.
- **User Experience Nyaman:** Bersih dari notifikasi banner atau snackbar bawah yang menumpuk.

---

## 🔑 Akun Demo Pengujian (Default Credentials)

Untuk kemudahan pengujian fitur oleh penguji/guru, tersedia akun demo siap pakai:

| Role | Username | Password | Deskripsi Tugas |
| :--- | :--- | :---: | :--- |
| **Administrator** | `admin` | `123` | Kelola akun pegawai, daftar menu, & konfigurasi |
| **Kasir** | `kasir` | `123` | Proses transaksi kasir, input uang, & cetak struk |
| **Waiter** | `waiter` | `123` | Catat pesanan meja tamu & kirim ke dapur/kasir |
| **Owner** | `owner` | `123` | Pantau omset penjualan & ekspor laporan PDF/CSV |
| **Pelanggan** | `pelanggan` | `123` | Pesan menu mandiri & pantau status hidangan |

---

## 📁 Struktur Direktori Utama

```text
UJIKOM-COKKK/
├── assets/
│   └── images/
│       ├── Rasantara Cloche App Icon.png   # Logo resmi aplikasi Rasantara
│       └── logo_smk_baknus_666.png         # Logo SMK Bakti Nusantara 666
├── lib/
│   ├── models/                             # Data model (Order, Menu, User, Table, Transaction)
│   ├── screens/
│   │   ├── cashier/                        # Layar transaksi kasir & riwayat pesanan restoran
│   │   ├── dashboard/                      # Dasbor metrik penjualan Owner & Admin
│   │   ├── order/                          # Entri order meja waiter & order mandiri pelanggan
│   │   ├── profile/                        # Profil pengguna, preferensi, & keamanan
│   │   ├── reference/                      # Manajemen menu makanan/minuman
│   │   ├── reports/                        # Laporan keuangan & ekspor PDF/CSV
│   │   └── users/                          # Manajemen data pengguna & pegawai (Admin)
│   ├── services/                           # DatabaseService, SupabaseService, ExportReportService
│   ├── theme/                              # Desain tema warna Rasantara (Warm Spice & Charcoal)
│   └── widgets/                            # Komponen reusable (ReceiptDialog, QRISDialog, dll.)
├── test/
│   ├── supabase_google_test.dart           # Automated tests integrasi data model & config
│   └── widget_test.dart                    # Automated tests widget antarmuka seluruh role
├── rasantara_database.sql                  # Skrip DDL & DML skema database PostgreSQL/Supabase
└── README.md
```

---

## 🚀 Panduan Instalasi & Menjalankan Aplikasi

### Persyaratan Sistem:
* Flutter SDK (>= 3.3.0)
* Dart SDK (>= 3.0.0)
* Android Studio / VS Code / Antigravity IDE
* Google Chrome (untuk Web) / Visual Studio C++ (untuk Windows Desktop)

### Langkah Menjalankan:

```bash
# 1. Clone repositori ini
git clone https://github.com/ENDY1807/UJIKOM-COKKK.git
cd UJIKOM-COKKK

# 2. Ambil paket dependensi
flutter pub get

# 3. Jalankan automated tests (15/15 test wajib lulus)
flutter test

# 4. Jalankan linter & static analyzer
flutter analyze

# 5. Jalankan aplikasi pada platform yang diinginkan:
flutter run -d windows    # Windows Desktop
flutter run -d chrome     # Web Browser
flutter run -d android    # Perangkat Android / Emulator
```

---

<p align="center">
  Dibuat dengan ❤️ dan dedikasi oleh <strong>Muhammad Nazril Putra Natrabu</strong><br>
  <em>SMK Bakti Nusantara 666 &copy; 2026/2027</em>
</p>
