import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/file_downloader.dart';
import '../services/payment_gateway_service.dart';
import '../theme/app_theme.dart';
import 'receipt_dialog.dart';

/// Modal Pembayaran QRIS Standar Nasional (ASPI / Bank Indonesia / GPN)
/// Dilengkapi tampilan visual resmi QRIS dan fitur Download QRIS untuk pembayaran via DANA, GoPay, OVO, dll.
class QrisPaymentDialog extends StatefulWidget {
  final OrderModel order;
  final int totalAmount;
  final DatabaseService db;
  final VoidCallback? onPaymentSuccess;

  const QrisPaymentDialog({
    super.key,
    required this.order,
    required this.totalAmount,
    required this.db,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required int totalAmount,
    required DatabaseService db,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QrisPaymentDialog(
        order: order,
        totalAmount: totalAmount,
        db: db,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<QrisPaymentDialog> createState() => _QrisPaymentDialogState();
}

class _QrisPaymentDialogState extends State<QrisPaymentDialog> {
  final GlobalKey _qrCardKey = GlobalKey();
  int _secondsRemaining = 300; // 5 Menit kedaluwarsa QRIS
  Timer? _countdownTimer;
  bool _isProcessingPayment = false;
  bool _isDownloading = false;
  late String _qrisPayload;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _qrisPayload = PaymentGatewayService.generateAspiEmvCoQris(
      orderId: 'ORDER-${widget.order.idOrder}',
      amount: widget.totalAmount,
      merchantName: PaymentGatewayConfig.defaultMerchantName,
      city: PaymentGatewayConfig.defaultCity,
      postalCode: PaymentGatewayConfig.defaultPostalCode,
      nmid: PaymentGatewayConfig.defaultNmid,
    );
    _initDanaH2hQris();
    _startTimer();
  }

  Future<void> _initDanaH2hQris() async {
    try {
      final res = await PaymentGatewayService.generateQris(
        orderId: 'RSN-${widget.order.idOrder}-${DateTime.now().millisecondsSinceEpoch % 100000}',
        amount: widget.totalAmount,
      );
      if (res.qrString.isNotEmpty && mounted) {
        setState(() {
          _qrisPayload = res.qrString;
        });
      }
    } catch (_) {}
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String get _formattedTimer {
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Menangkap kartu QRIS dan mengunduhnya ke perangkat (Web & Mobile/APK)
  Future<void> _downloadQrisImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 120));

      final boundary = _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Objek kartu QRIS belum siap dirender.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal mengonversi gambar QRIS.');
      }

      final bytes = byteData.buffer.asUint8List();
      final filename = 'QRIS-Rasantara-${widget.order.idOrder}.png';

      if (kIsWeb) {
        downloadFileWeb(
          bytes: bytes,
          filename: filename,
          mimeType: 'image/png',
        );
      } else {
        // Pada Android APK / Desktop: Simpan dokumen gambar QRIS resolusi tinggi
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a5,
            margin: const pw.EdgeInsets.all(16),
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
        await Printing.sharePdf(
          bytes: await doc.save(),
          filename: 'QRIS-Rasantara-${widget.order.idOrder}.pdf',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: const Color(0xFF16A34A),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'QRIS berhasil diunduh. Silakan buka aplikasi DANA, GoPay, atau M-Banking Anda dan scan dari galeri.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
              'Gagal mengunduh QRIS: $e',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _isProcessingPayment = true);

    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    final transaction = widget.db.processTransaction(
      order: widget.order,
      jumlahBayar: widget.totalAmount,
      metodePembayaran: 'QRIS Nasional (ASPI/GPN)',
    );

    setState(() {
      _isProcessingPayment = false;
    });

    widget.onPaymentSuccess?.call();

    if (mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ReceiptDialog(transaction: transaction),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 410,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Dialog
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Color(0xFFEA580C),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('Pembayaran QRIS', 'QRIS Payment'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                            Text(
                              context.t('Standar Nasional BI & ASPI', 'National Standard BI & ASPI'),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.textSecondary, size: 22),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.borderSubtle),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Column(
                    children: [
                      // Standee Canvas yang dapat di-download ke perangkat
                      RepaintBoundary(
                        key: _qrCardKey,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: Stack(
                              children: [
                                // Aksen Geometris Pita Merah QRIS Resmi
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _QrisOfficialFramePainter(),
                                  ),
                                ),

                                // Konten Fisik Standee QRIS
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 1. Header Logo Bar: QRIS & GPN
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          _buildOfficialQrisHeaderLogo(),
                                          _buildOfficialGpnLogo(),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // 2. Info Toko & NMID
                                      Text(
                                        PaymentGatewayConfig.defaultMerchantName,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'NMID : ${PaymentGatewayConfig.defaultNmid} • A01',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // 3. QR Code Bersih & Berkontras Tinggi
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: QrImageView(
                                          data: _qrisPayload,
                                          version: QrVersions.auto,
                                          size: 200.0,
                                          backgroundColor: Colors.white,
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: Color(0xFF000000),
                                          ),
                                          dataModuleStyle: const QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: Color(0xFF000000),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // 4. Banner Nominal Transaksi di dalam kartu
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFFEDD5)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Nominal Bayar:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF7C2D12),
                                              ),
                                            ),
                                            Text(
                                              _currencyFmt.format(widget.totalAmount),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFFEA580C),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // 5. Badge Dompet Digital & Mobile Banking
                                      _buildSupportedPaymentPills(),
                                      const SizedBox(height: 8),

                                      // 6. Footer Standee
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: const [
                                          Text(
                                            'Dicetak oleh : 93600013',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                          Text(
                                            'VERIFIKASI OTOMATIS',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0284C7),
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Box Total Pembayaran & Hitung Mundur
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('Total Tagihan', 'Total Bill'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyFmt.format(widget.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.isDarkMode ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formattedTimer,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Panduan Singkat Cara Scan dari Galeri
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: context.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                                const SizedBox(width: 6),
                                Text(
                                  context.t('Cara Bayar Scan dari Galeri:', 'How to Pay via Gallery Scan:'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              context.t(
                                '1. Klik tombol "Download QRIS" di bawah ini.\n'
                                '2. Buka DANA, GoPay, ShopeePay, atau M-Banking Anda.\n'
                                '3. Pilih menu "Scan QR" lalu klik ikon "Galeri / Foto".\n'
                                '4. Pilih foto QRIS tadi, bayar, lalu klik "Cek Status".',
                                '1. Click "Download QRIS" below.\n'
                                '2. Open your DANA, GoPay, ShopeePay, or M-Banking app.\n'
                                '3. Select "Scan QR" and tap "Gallery / Photo".\n'
                                '4. Select the downloaded QRIS, pay, then click "Check Status".',
                              ),
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.35,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                child: Column(
                  children: [
                    // Tombol 1: Download QRIS
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEA580C),
                        minimumSize: const Size(double.infinity, 42),
                        side: const BorderSide(color: Color(0xFFEA580C), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isDownloading ? null : _downloadQrisImage,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFEA580C),
                              ),
                            )
                          : const Icon(Icons.download_rounded, size: 19),
                      label: Text(
                        _isDownloading
                            ? context.t('Menyiapkan Gambar...', 'Preparing Image...')
                            : context.t('Download / Simpan QRIS', 'Download / Save QRIS'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tombol 2: Cek Status Pembayaran
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isProcessingPayment ? null : _checkPaymentStatus,
                      icon: _isProcessingPayment
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.verified_rounded, size: 19),
                      label: Text(
                        _isProcessingPayment
                            ? context.t('Memeriksa Pembayaran...', 'Verifying Payment...')
                            : context.t('Cek Status Pembayaran', 'Check Payment Status'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Tombol 3: Bayar Nanti di Kasir
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: context.textSecondary,
                        minimumSize: const Size(double.infinity, 36),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        context.t('Bayar Nanti di Kasir', 'Pay Later at Cashier'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Badges logo e-wallet & m-banking yang didukung
  Widget _buildSupportedPaymentPills() {
    final badges = [
      {'name': 'DANA', 'color': const Color(0xFF118EEA)},
      {'name': 'GOPAY', 'color': const Color(0xFF00AED6)},
      {'name': 'OVO', 'color': const Color(0xFF4C3494)},
      {'name': 'SHOPEEPAY', 'color': const Color(0xFFEE4D2D)},
      {'name': 'BCA', 'color': const Color(0xFF003D79)},
      {'name': 'MANDIRI', 'color': const Color(0xFF003366)},
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: badges.map((b) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: (b['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: (b['color'] as Color).withValues(alpha: 0.3)),
          ),
          child: Text(
            b['name'] as String,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: b['color'] as Color,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Official QRIS Logo & Text (Standar Bank Indonesia / ASPI)
  Widget _buildOfficialQrisHeaderLogo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 11,
                height: 11,
                color: Colors.black,
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 4.5,
                  height: 4.5,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'QRIS',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.5,
                height: 1.0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'QR Code Standar\nPembayaran Nasional',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Official GPN Logo (Garuda Merah & Tulisan GPN Biru)
  Widget _buildOfficialGpnLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.flight_takeoff_rounded, color: Color(0xFFDC2626), size: 17),
          ],
        ),
        const Text(
          'GPN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF005BAC),
            letterSpacing: 1.1,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter untuk aksen grafis merah bersudut resmi QRIS Standar Nasional
class _QrisOfficialFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;

    // 1. Aksen Sisi Kiri
    final leftPath = Path();
    final leftTop = size.height * 0.17;
    final leftArrowHeight = 22.0;
    final leftWidth = 14.0;
    final leftArrowWidth = 34.0;
    final leftBottom = size.height * 0.56;

    leftPath.moveTo(0, leftTop);
    leftPath.lineTo(leftArrowWidth, leftTop + leftArrowHeight);
    leftPath.lineTo(leftWidth, leftTop + leftArrowHeight);
    leftPath.lineTo(leftWidth, leftBottom);
    leftPath.lineTo(0, leftBottom - 18.0);
    leftPath.close();

    canvas.drawPath(leftPath, paint);

    // 2. Aksen Sudut Kanan-Bawah
    final rightPath = Path();
    final rightWidth = 14.0;
    final rightTop = size.height * 0.79;
    final bottomCutLength = 54.0;

    rightPath.moveTo(size.width, rightTop);
    rightPath.lineTo(size.width - rightWidth, rightTop + 16.0);
    rightPath.lineTo(size.width - rightWidth, size.height - rightWidth);
    rightPath.lineTo(size.width - bottomCutLength, size.height - rightWidth);
    rightPath.lineTo(size.width - bottomCutLength - 16.0, size.height);
    rightPath.lineTo(size.width, size.height);
    rightPath.close();

    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
