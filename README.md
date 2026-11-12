# Rasantara — Aplikasi Kasir & Pemesanan Meja Restoran (Table Service)

Aplikasi kasir dan manajemen restoran modern berbasis **Flutter** untuk mendukung operasional restoran nusantara multi-platform (Android, Windows Desktop, dan Web).

Dikembangkan untuk memenuhi standar **Uji Kompetensi Keahlian (UKK) Rekayasa Perangkat Lunak 2026/2027 (Paket 1 - Kode: 2134)**.

---

## Fitur Utama

- **Multi-Role Access Control**:
  - `Administrator`: Manajemen pengguna, hak akses level, dan konfigurasi sistem.
  - `Waiter`: Pemesanan meja (table service), pemilihan denah meja visual, dan pengiriman pesanan ke dapur/kasir.
  - `Kasir`: Manajemen billing, transaksi kasir, pembayaran tunai, QRIS, Virtual Account, dan pencetakan struk.
  - `Owner`: Pemantauan dashboard real-time, laporan transaksi, omset, dan analisis menu terlaris.
  - `Pelanggan`: Layanan mandiri VIP / reservasi meja pelanggan terdaftar.
- **Modern Responsive UI**:
  - Dukungan tampilan adaptif untuk smartphone, tablet waiter, dan monitor desktop POS kasir.
  - Nuansa desain elegan dengan palet khas kuliner nusantara (*Warm Spice Orange* & *Charcoal Slate*).
- **Integrasi Cloud & Offline**:
  - Didukung oleh backend PostgreSQL / Supabase untuk sinkronisasi data cloud real-time.
  - Fallback local database service untuk stabilitas demo offline.
- **Ekspor Laporan**:
  - Cetak struk pembayaran PDF/Thermal.
  - Ekspor laporan harian dan bulanan dalam format CSV dan PDF.

---

## Struktur Database

1. **`rasantara_database.sql`**: Script database resmi untuk PostgreSQL / Supabase / Neon lengkap dengan RLS (Row Level Security), views, dan data awal.
2. **`database_kasir_restoran_mysql.sql`**: Script database untuk pengujian lingkungan MySQL / XAMPP / phpMyAdmin.

---

## Menjalankan Proyek

Pastikan Flutter SDK (>= 3.3.0) sudah terpasang di sistem:

```bash
# 1. Unduh dependencies
flutter pub get

# 2. Jalankan analisis kode
flutter analyze

# 3. Jalankan automated tests
flutter test

# 4. Jalankan aplikasi (pilih platform yang diinginkan)
flutter run -d chrome
flutter run -d windows
flutter run -d android
```
