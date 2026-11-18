# Analisis & Perbandingan Proyek: UJIKOM-COKKK vs UJIKOM Endy (Backup)

Dokumen ini menyajikan perbandingan mendalam antara proyek saat ini (**UJIKOM-COKKK**) dengan versi cadangan terdahulu (**UJIKOM Endy(Backup)**), mencakup perubahan arsitektur, penambahan fitur mandiri (*self-service*), optimasi tata letak (*mobile responsive*), hingga panduan teknis khusus untuk memodifikasi desain grafik visual (*charts*) pada modul laporan.

---

## 1. Ringkasan Eksekutif & Statistik Perubahan

| Parameter | UJIKOM Endy (Backup) | UJIKOM-COKKK (Proyek Aktif) |
| :--- | :--- | :--- |
| **Commit Acuan** | `49b2349 gabut` (Base) | Terkini (Base + Commit Rilis + Fitur Baru) |
| **Statistik Perubahan Kode** | - | **+6.775 baris disisipkan**, **-2.715 baris di-refactor** pada 31 file |
| **Alur Pelanggan (QR Meja)** | Terbatas (belum terintegrasi penuh) | **Lengkap**: Scan QR meja, dialog pemesanan real-time, cetak stiker QR meja (PNG/PDF) |
| **Pembayaran Mandiri (QRIS)** | Harus melalui Kasir | **Self-Service**: Pelanggan dapat membayar QRIS langsung dari HP sendiri |
| **Responsivitas Mobile** | Banyak *render flex overflow* pada layar HP | **100% Bebas Overflow**: Header wrap, card stack, responsive modal & bottom sheet |
| **Status Analisis & Pengujian** | Sering tertahan error import | **Lulus 100%**: 0 Error `flutter analyze`, 22 unit & widget test sukses |

---

## 2. Tabel Perbandingan Fitur Detail

### A. Fitur Pemesanan & Alur Pelanggan (Customer Flow)
- **UJIKOM Endy (Backup)**:
  - Pelanggan masih bergantung pada alur kasir/waiter konvensional.
  - Masih terdapat file lama `order_history_screen.dart` yang terpisah dan belum terhubung dinamis dengan sesi meja.
- **UJIKOM-COKKK**:
  - Penambahan modul [customer_order_flow_screen.dart](file:///Users/pplgsmkbn666/Documents/UJIKOM-COKKK/lib/screens/order/customer_order_flow_screen.dart) dan [table_qr_scanner_dialog.dart](file:///Users/pplgsmkbn666/Documents/UJIKOM-COKKK/lib/widgets/table_qr_scanner_dialog.dart).
  - Meja memiliki QR unik yang dapat di-scan oleh kamera HP pelanggan atau diinput manual nomor mejanya.
  - Sesi meja langsung terkunci ke pesanan pelanggan, menampilkan status pesanan (*Menunggu Verifikasi*, *Diproses*, *Selesai*).

### B. Pembayaran QRIS Mandiri Pelanggan
- **UJIKOM Endy (Backup)**:
  - Pelanggan yang telah selesai memilih makanan harus datang ke meja kasir untuk memproses dan mencatat pembayaran.
- **UJIKOM-COKKK**:
  - Pelanggan dapat menekan tombol **"Bayar Sekarang via QRIS"** langsung dari keranjang di HP sendiri.
  - Disediakan metode khusus `processCustomerDirectQris` di [database_service.dart](file:///Users/pplgsmkbn666/Documents/UJIKOM-COKKK/lib/services/database_service.dart) yang otomatis menandai pesanan lunas (`isPaid = true`), mengubah status menjadi `diproses`, menjaga status meja tetap `terisi` selama makan, mencatat log mutasi `Self-Service QRIS`, dan menyinkronkan data ke Supabase tanpa perlu antre di kasir.

### C. Tampilan Mobile & Antarmuka Responsif
- **UJIKOM Endy (Backup)**:
  - Terjadi *Right Overflowed by 94px* pada ringkasan laporan kasir dan owner di layar < 600px.
  - Tombol aksi ekspor (Excel, PDF, Refresh, Pratinjau) terpotong jika dibuka dari ponsel.
  - Manajemen pengguna (*User Management*) menggunakan baris horizontal kaku yang menyebabkan avatar dan tombol aksi tumpang-tindih.
  - Pada layar kasir mobile, menekan tombol kembali (*back*) dapat langsung keluar aplikasi tanpa membatalkan pilihan pesanan aktif.
- **UJIKOM-COKKK**:
  - **Laporan Responsif**: Kartu ringkasan omzet otomatis berubah menjadi susunan vertikal (*stacking*) saat layar sempit, dan bilah tombol aksi menggunakan baris gulir horizontal (*single child scroll view*).
  - **User Management Responsif**: Tata letak kartu pengguna dirombak dengan model 3-tingkat (Header: Avatar & Role Badge; Tengah: Username/Email/No HP; Bawah: Tombol Edit & Hapus).
  - **Kasir Ramah Mobile**: Dilengkapi `PopScope` sehingga tombol kembali pada HP membatalkan pesanan yang dipilih terlebih dahulu sebelum keluar.

### D. Perbedaan File & Komponen Penting
| Nama File | Status di Proyek Aktif | Keterangan |
| :--- | :--- | :--- |
| `lib/screens/order/customer_order_flow_screen.dart` | **Baru** | Halaman khusus alur mandiri pelanggan |
| `lib/widgets/table_qr_scanner_dialog.dart` | **Baru** | Dialog scan dan input nomor QR meja pelanggan |
| `lib/models/user_address_model.dart` | **Diperbaiki / Dipulihkan** | Model alamat terintegrasi Supabase |
| `lib/screens/order/order_history_screen.dart` | **Dihapus / Direfaktor** | Digantikan oleh riwayat kasir & tracker pelanggan |
| `DEBUGGING_GUIDE.md` | **Baru** | Dokumentasi panduan pelacakan & penyelesaian bug |

---

## 3. Panduan Khusus Laporan: Cara Merubah Desain Grafik (*Charts*)

Seluruh visualisasi grafik pada laporan restoran Rasantara dikelola dalam satu file utama:
👉 **[lib/widgets/analytics_charts.dart](file:///Users/pplgsmkbn666/Documents/UJIKOM-COKKK/lib/widgets/analytics_charts.dart)**

Grafik dibangun menggunakan `CustomPainter` murni dari Flutter (tanpa pustaka pihak ketiga yang berat) sehingga rendering sangat cepat, ringan, dan dapat disesuaikan secara bebas.

Berikut adalah panduan langkah demi langkah cara mengubah desain tiap komponen grafik:

---

### A. Mengubah Desain Grafik Donat Metode Pembayaran (`_PaymentDonutPainter`)
Grafik donat terletak pada class `_PaymentDonutPainter` (sekitar baris 780 - 840).

```dart
// Lokasi: lib/widgets/analytics_charts.dart
class _PaymentDonutPainter extends CustomPainter {
  final double qrisShare;
  final double cashShare;
```

#### 1. Mengubah Ketebalan Donat (*Stroke Width*)
Cari konstanta `strokeWidth` di dalam method `paint`:
```dart
const strokeWidth = 12.0; // Ubah nilai ini (misal: 18.0 untuk lebih tebal, atau 6.0 untuk garis tipis modern)
```

#### 2. Mengubah Warna Segmen Pembayaran
Cari baris pemanggilan fungsi `drawSegment`:
```dart
drawSegment(qrisShare, const Color(0xFFEA580C)); // Warna Oranye QRIS
drawSegment(cashShare, const Color(0xFF2563EB)); // Warna Biru Tunai
```
*Tips Desain*: Ganti kode heksadesimal warna (misal `0xFF10B981` untuk Hijau Emerald, `0xFF6366F1` untuk Indigo, atau `0xFF059669` untuk nuansa modern).

#### 3. Mengubah Bentuk Ujung Busur Lingkaran (*Stroke Cap*)
Jika ingin ujung donat membulat (*rounded caps*):
```dart
// Ganti:
..strokeCap = StrokeCap.butt;
// Menjadi:
..strokeCap = StrokeCap.round;
```

#### 4. Mengubah Diameter atau Ukuran Donat di Tampilan
Pada fungsi induk `build` (sekitar baris 455), cari widget pembungkus:
```dart
SizedBox(
  width: 110,   // Ganti lebar (misal: 130)
  height: 110,  // Ganti tinggi (misal: 130)
  child: CustomPaint( ... ),
)
```

---

### B. Mengubah Desain Grafik Garis & Kurva Omzet (`RasantaraAreaChartCard` & `_SimpleAreaChartPainter`)
Grafik kurva pendapatan (*Area Spline Chart*) terletak pada class `_SimpleAreaChartPainter` (sekitar baris 1030 - 1245).

#### 1. Mengubah Warna Garis Kurva Utama & Sekunder
Warna kurva dikontrol oleh parameter di `RasantaraAreaChartCard`:
```dart
this.primaryColor = const Color(0xFFEA580C),   // Warna kurva total omzet / QRIS (Oranye)
this.secondaryColor = const Color(0xFF2563EB), // Warna kurva sekunder / Tunai (Biru)
```
Anda dapat menggantinya langsung pada parameter widget atau mengubah nilai default-nya.

#### 2. Mengatur Ketebalan Garis Kurva (*Stroke Width*)
Cari bagian `strokePaint` (sekitar baris 1172):
```dart
final strokePaint = Paint()
  ..color = strokeColor
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.0 // Ubah ke 3.0 untuk garis lebih tebal, atau 1.5 untuk garis halus
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
```

#### 3. Mengatur Efek Gradien Area di Bawah Kurva (*Gradient Fill*)
Cari bagian `LinearGradient` (sekitar baris 1160):
```dart
final fillPaint = Paint()
  ..shader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      strokeColor.withValues(alpha: isDark ? 0.30 : 0.20), // Kepekatan gradien atas (0.20 = 20%)
      strokeColor.withValues(alpha: 0.01),                // Kepekatan gradien bawah (transparan)
    ],
  ).createShader(...);
```
- Jika ingin area di bawah kurva **polos/tanpa gradien**, hapus pemanggilan `canvas.drawPath(fillPath, fillPaint);`.
- Jika ingin gradien lebih tegas, naikkan `alpha` atas menjadi `0.40`.

#### 4. Menyesuaikan Garis Grid Horizontal & Skala Sumbu Y
Cari pengaturan `gridLinePaint` (sekitar baris 1076):
```dart
final gridLinePaint = Paint()
  ..color = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 0.8; // Ubah ketebalan garis panduan horizontal
```
Jumlah level garis ditentukan oleh daftar `steps`:
```dart
final steps = [1.0, 0.5, 0.0]; // Menghasilkan 3 garis panduan (Maksimum, 50%, dan 0)
// Jika ingin 4 garis, ganti menjadi: [1.0, 0.66, 0.33, 0.0];
```
    
#### 5. Mengubah Tinggi Wadah Grafik (*Height*)
Pada widget `RasantaraAreaChartCard`, cari parameter:
```dart
this.height = 155, // Ubah nilai ini (misal: 180 atau 200) untuk tampilan grafik yang lebih tinggi
```

---

### C. Mengubah Desain Grafik Batang (*Bar Chart* - Menu Terlaris)
Grafik batang penjualan menu terletak pada widget `RasantaraBarChartCard` dan `_SimpleBarPainter` (sekitar baris 630 - 750).

#### 1. Mengubah Warna Batang (*Bar Color*)
```dart
final barPaint = Paint()
  ..color = const Color(0xFFEA580C) // Oranye tema Rasantara
  ..style = PaintingStyle.fill;
```

#### 2. Mengubah Sudut Kelengkungan Batang (*Corner Radius*)
Cari fungsi pembuatan `RRect`:
```dart
final rrect = RRect.fromRectAndCorners(
  Rect.fromLTWH(x, y, barWidth, barHeight),
  topLeft: const Radius.circular(4),  // Ubah ke 8 untuk batang yang lebih membulat
  topRight: const Radius.circular(4),
);
```

---

### D. Mengubah Tampilan Kartu Metrik Ringkasan (*KPI Summary Cards*)
Pada awal metode `build` di [analytics_charts.dart](file:///Users/pplgsmkbn666/Documents/UJIKOM-COKKK/lib/widgets/analytics_charts.dart#L130-L240), Anda dapat memodifikasi desain kartu ringkasan omzet, total transaksi, rata-rata tiket, dan proporsi QRIS:
- **Radius Sudut Kotak**: Ganti `BorderRadius.circular(16)` sesuai selera (misal `12` untuk sudut tegas atau `24` untuk sudut modern *squircle*).
- **Warna Ikon & Latar Belakang Ikon**: Ganti warna `Container` ikon pada masing-masing metrik agar selaras dengan identitas restoran.

---

## 4. Kesimpulan
Proyek **UJIKOM-COKKK** merupakan penyempurnaan menyeluruh dari versi cadangan **UJIKOM Endy (Backup)**:
1. **Lebih Mandiri**: Pelanggan dapat memesan dari QR meja dan membayar langsung via QRIS dari HP masing-masing.
2. **Lebih Rapi & Bebas Bug**: Seluruh antarmuka diuji bebas *overflow*, laporan kasir/owner responsif di desktop maupun layar HP sempit.
3. **Laporan Bersih & Akurat**: Distribusi pembayaran telah disederhanakan hanya fokus pada QRIS dan Tunai, didukung arsitektur grafik visual yang mudah dikustomisasi desainnya kapan saja.
