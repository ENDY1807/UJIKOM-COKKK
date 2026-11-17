# Panduan Debugging & Kustomisasi UI — Rasantara POS

Dokumen ini berisi panduan praktis untuk melakukan *debugging*, mengubah ukuran komponen, mengganti warna, memodifikasi bentuk grafik (*charts*), serta mengatur tata letak antarmuka aplikasi Rasantara.

---

## 1. Alat & Teknik Debugging di Flutter

### A. Hot Reload vs Hot Restart
Jalankan aplikasi melalui terminal dengan perintah:
```bash
flutter run -d windows    # Menjalankan di desktop Windows
flutter run -d chrome     # Menjalankan di browser Web
```
* **Tekan tombol `r` (Hot Reload):** Memperbarui perubahan kode UI secara instan (1–2 detik) tanpa mereset data atau state aplikasi.
* **Tekan tombol `R` (Hot Restart):** Memuat ulang aplikasi dari awal (state di-reset ke `initState`). Gunakan ini jika mengubah struktur data atau menambahkan controller baru.

### B. Logging ke Terminal Konsol
Gunakan `debugPrint()` untuk memantau data tanpa memperlambat performa aplikasi:
```dart
debugPrint('[DEBUG] Nilai Meja: $_selectedTableNo');
debugPrint('[DEBUG] Total Bayar: $totalBayar');
```

### C. Flutter DevTools & Widget Inspector
* Tekan tombol **`v`** di terminal saat aplikasi sedang berjalan, lalu buka tautan DevTools di browser.
* Aktifkan fitur **Select Widget Mode** untuk mengklik elemen apa pun di layar dan melihat ukuran pasti (*width*, *height*, *padding*, serta *margin*).

### D. Mengatasi Error Umum Tampilan
* **RenderFlex Overflow (Garis Hitam-Kuning):** Terjadi jika konten melebihi batas layar. Bungkus widget dengan `SingleChildScrollView` atau gunakan widget `Flexible` / `Expanded`.
* **Cannot hit test a render box with no size:** Terjadi jika widget interaktif berada di dalam container tanpa ukuran pasti. Bungkus widget dengan `SizedBox` atau tentukan `width` dan `height`.

---

## 2. Cara Mengubah Ukuran Komponen

### A. Mengubah Ukuran Tombol
```dart
// 1. Menggunakan Padding (Menyesuaikan teks di dalam)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
  ),
  onPressed: () {},
  child: const Text('Simpan'),
)

// 2. Mengunci Ukuran Pasti (Lebar 160px, Tinggi 48px)
ElevatedButton(
  style: ElevatedButton.styleFrom(
    minimumSize: const Size(160, 48),
  ),
  onPressed: () {},
  child: const Text('Simpan'),
)

// 3. Lebar Penuh (100% Mengikuti Layar)
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {},
    child: const Text('Selesaikan Transaksi'),
  ),
)
```

### B. Mengubah Ukuran QR Code
* **Pada Tampilan Layar ([menu_management_screen.dart](file:///d:/Coding/UJIKOM-COKKK/lib/screens/reference/menu_management_screen.dart#L378)):**
  ```dart
  QrImageView(
    data: table.qrPayload,
    size: 160, // Ubah angka ini untuk memperbesar/memperkecil QR di dialog
  )
  ```
* **Pada Hasil Unduh PNG ([export_report_service.dart](file:///d:/Coding/UJIKOM-COKKK/lib/services/export_report_service.dart#L947)):**
  ```dart
  const qrSize = 360.0; // Ukuran QR di dalam canvas kartu stiker
  ```

---

## 3. Cara Mengubah Warna

Flutter menggunakan format warna Hexadecimal ARGB: `const Color(0xFF + Kode Hex)`.

### A. Palet Warna Utama Proyek
* **Oranye Utama Rasantara:** `Color(0xFFEA580C)`
* **Oranye Border:** `Color(0xFFC2410C)`
* **Oranye Lembut (Background):** `Color(0xFFFFF7ED)`
* **Teks Hitam Slate:** `Color(0xFF0F172A)`
* **Teks Abu Muted:** `Color(0xFF64748B)`
* **Hijau Sukses:** `Color(0xFF16A34A)`
* **Merah Peringatan/Batal:** `Color(0xFFDC2626)`

### B. Mengubah Warna Tombol
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFEA580C), // Latar belakang tombol
    foregroundColor: Colors.white,             // Warna tulisan / icon
  ),
  onPressed: () {},
  child: const Text('Konfirmasi'),
)
```

### C. Mengubah Warna Background & Border Kartu (Card)
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,                     // Background kartu
    borderRadius: BorderRadius.circular(16), // Kelengkungan sudut
    border: Border.all(
      color: const Color(0xFFE2E8F0),        // Warna garis batas
      width: 1.5,                            // Ketebalan garis
    ),
  ),
  child: const Text('Isi Kartu'),
)
```

### D. Mengubah Warna QR Code
Di dalam widget `QrImageView` atau `QrPainter`:
```dart
eyeStyle: const QrEyeStyle(
  eyeShape: QrEyeShape.square, // Bisa diganti QrEyeShape.circle
  color: Color(0xFFEA580C),     // Warna 3 kotak sudut QR
),
dataModuleStyle: const QrDataModuleStyle(
  dataModuleShape: QrDataModuleShape.square, // Bisa diganti QrDataModuleShape.circle
  color: Color(0xFF0F172A),     // Warna titik-titik data QR
),
```

---

## 4. Cara Mengubah Posisi & Tata Letak (Layout)

### A. Atas-Bawah (Vertikal) menggunakan `Column`
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch, // Rata kiri-kanan
  children: [
    widgetAtas,
    const SizedBox(height: 16), // Jarak pemisah vertikal
    widgetBawah,
  ],
)
```

### B. Berdampingan Kiri-Kanan (Horizontal) menggunakan `Row`
Bungkus masing-masing elemen dengan `Expanded` agar lebarnya membagi proporsional:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      flex: 1, // Mengambil 50% lebar
      child: widgetKiri,
    ),
    const SizedBox(width: 14), // Jarak pemisah horizontal
    Expanded(
      flex: 1, // Mengambil 50% lebar
      child: widgetKanan,
    ),
  ],
)
```

### C. Responsif (Desktop Berdampingan, HP Bertumpuk)
Gunakan `LayoutBuilder` seperti di [analytics_charts.dart baris 526–554](file:///d:/Coding/UJIKOM-COKKK/lib/widgets/analytics_charts.dart#L526-L554):
```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 780) {
      // Layar Lebar (Desktop/Tablet): Berdampingan ke samping
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 11, child: kartuKiri),
          const SizedBox(width: 14),
          Expanded(flex: 10, child: kartuKanan),
        ],
      );
    }

    // Layar Sempit (HP Mobile): Tersusun ke bawah
    return Column(
      children: [
        kartuKiri,
        const SizedBox(height: 14),
        kartuKanan,
      ],
    );
  },
)
```

---

## 5. Cara Memodifikasi Bentuk Chart (Grafik)

Semua komponen visual grafik berada di [lib/widgets/analytics_charts.dart](file:///d:/Coding/UJIKOM-COKKK/lib/widgets/analytics_charts.dart).

### A. Memodifikasi Donut Chart (Metode Pembayaran)
Dibuat dengan `_PaymentDonutChartPainter` ([analytics_charts.dart baris 808](file:///d:/Coding/UJIKOM-COKKK/lib/widgets/analytics_charts.dart#L808)):
* **Mengubah Ketebalan Cincin Donut:**
  Cari baris `strokeWidth`:
  ```dart
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 24.0; // Ganti angka ini (semakin besar semakin tebal)
  ```
* **Mengubah Cincin Menjadi Lingkaran Penuh (Pie Chart Tradisional):**
  Ubah style dari `PaintingStyle.stroke` menjadi `PaintingStyle.fill`:
  ```dart
  final paint = Paint()
    ..style = PaintingStyle.fill; // Menjadi pie utuh tanpa lubang tengah
  ```
* **Mengubah Warna Irisan Metode Pembayaran:**
  Di [analytics_charts.dart baris 260](file:///d:/Coding/UJIKOM-COKKK/lib/widgets/analytics_charts.dart#L260):
  - Tunai: `Color(0xFFEA580C)`
  - QRIS: `Color(0xFF0284C7)`
  - Debit: `Color(0xFF64748B)`

### B. Memodifikasi Diagram Batang (Bar Chart)
Tinggi batang dihitung secara proporsional berdasarkan rasio omzet:
```dart
final ratio = maxOmzet > 0 ? (omzetHari / maxOmzet) : 0.0;
final barHeight = ratio * 140.0; // 140.0 adalah tinggi maksimal batang (px)
```
* **Mengubah Lebar Batang:**
  Ubah `width: 14.0` menjadi `width: 20.0` pada `Container` batang.
* **Mengubah Radius Sudut Batang:**
  Ubah `borderRadius: BorderRadius.circular(6.0)`.

---

## 6. Daftar File Penting untuk Modifikasi Cepat

| Komponen yang Ingin Diubah | Lokasi File |
| :--- | :--- |
| **Grafik, Diagram Donut, & Metrik Omzet** | [lib/widgets/analytics_charts.dart](file:///d:/Coding/UJIKOM-COKKK/lib/widgets/analytics_charts.dart) |
| **Ekspor PNG / PDF Stiker Meja & Struk POS** | [lib/services/export_report_service.dart](file:///d:/Coding/UJIKOM-COKKK/lib/services/export_report_service.dart) |
| **Alur & Kamera Scanner QR Meja Pelanggan** | [lib/screens/order/customer_order_flow_screen.dart](file:///d:/Coding/UJIKOM-COKKK/lib/screens/order/customer_order_flow_screen.dart) |
| **Layar Kasir & Pembayaran Transaksi** | [lib/screens/cashier/cashier_screen.dart](file:///d:/Coding/UJIKOM-COKKK/lib/screens/cashier/cashier_screen.dart) |
| **Dialog Pratinjau Struk Kasir** | [lib/widgets/receipt_dialog.dart](file:///d:/Coding/UJIKOM-COKKK/lib/widgets/receipt_dialog.dart) |
| **Tema Warna & Tipografi Aplikasi** | [lib/theme/app_theme.dart](file:///d:/Coding/UJIKOM-COKKK/lib/theme/app_theme.dart) |
| **Manajemen State & Database Offline-First** | [lib/services/database_service.dart](file:///d:/Coding/UJIKOM-COKKK/lib/services/database_service.dart) |
| **Skrip DDL/DML Database PostgreSQL** | [rasantara_database.sql](file:///d:/Coding/UJIKOM-COKKK/rasantara_database.sql) |
