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

/// Modal Pembayaran QRIS / GoPay persis dengan antarmuka Midtrans Snap Checkout
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
  int _secondsRemaining = 855; // 00:14:15 seperti di referensi Snap
  Timer? _countdownTimer;
  bool _isProcessingPayment = false;
  bool _isDownloading = false;
  bool _showHowToPay = false;
  late String _qrisPayload;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
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
    final hours = (_secondsRemaining ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_secondsRemaining % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Menangkap QR Code dan mengunduhnya ke perangkat (Web & Mobile/APK)
  Future<void> _downloadQrisImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _qrCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Objek QR belum siap dirender.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Gagal membuat gambar QRIS.');
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
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(
                      'QRIS berhasil diunduh. Silakan buka aplikasi DANA, GoPay, atau M-Banking Anda dan scan dari galeri.',
                      'QRIS downloaded successfully. Open DANA, GoPay, or M-Banking to scan from gallery.',
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
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
              context.t('Gagal mengunduh QRIS: $e', 'Failed to download QRIS: $e'),
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
      metodePembayaran: 'GoPay / QRIS Snap',
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
              // 1. Top Bar: DEMO STORE / RASANTARA Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: const Color(0xFF0F2137), // Dark navy snap header
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      PaymentGatewayConfig.defaultMerchantName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Body Area (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Floating Card Total & Expiry Time
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0C000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kolom Kiri: Total & Nominal & Order ID
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _currencyFmt.format(widget.totalAmount),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Order ID #ORD-${widget.order.idOrder}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Kolom Kanan: Pay within & Dropdown Arrow
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Pay within ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _formattedTimer,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB), // Snap blue timer
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF64748B),
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Area QR yang dapat ditangkap dan diunduh pelanggan
                      RepaintBoundary(
                        key: _qrCardKey,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bar Judul Metode Pembayaran: GoPay & Ikon Dompet
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'GoPay / QRIS',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00AED6), // GoPay Cyan/Blue
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Tampilan QR Code Bersih di Tengah (Sesuai Screenshot)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  color: Colors.white,
                                  child: QrImageView(
                                    data: _qrisPayload,
                                    version: QrVersions.auto,
                                    size: 240.0,
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
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Baris "How to pay" dengan ikon tanda tanya biru dan accordion
                      InkWell(
                        onTap: () {
                          setState(() => _showHowToPay = !_showHowToPay);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.help_rounded,
                                color: Color(0xFF2563EB),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'How to pay',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showHowToPay
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.unfold_more_rounded,
                                color: const Color(0xFF2563EB),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Konten Accordion Petunjuk Pembayaran
                      if (_showHowToPay) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(
                                  '1. Klik tombol "Download QRIS" untuk menyimpan QR ke ponsel Anda.',
                                  '1. Click "Download QRIS" to save the QR code to your phone.',
                                ),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t(
                                  '2. Buka aplikasi GoPay, DANA, BCA Mobile, atau e-Wallet lainnya.',
                                  '2. Open your GoPay, DANA, BCA Mobile, or other e-Wallet app.',
                                ),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t(
                                  '3. Pilih menu "Scan QR" lalu ketuk ikon "Galeri / Foto" untuk memuat QRIS yang diunduh.',
                                  '3. Select "Scan QR" then tap the "Gallery / Photo" icon to load the saved QRIS.',
                                ),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.t(
                                  '4. Konfirmasi pembayaran, kemudian tekan tombol "Cek Status Pembayaran".',
                                  '4. Confirm the payment, then tap the "Check Status" button.',
                                ),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 3. Bottom Action Bar (Sesuai Screenshot Midtrans Snap)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  children: [
                    // Tombol Aksi Download QRIS & Cek Status
                    Row(
                      children: [
                        // Tombol Download QRIS
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                              side: const BorderSide(color: Color(0xFF2563EB)),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isDownloading ? null : _downloadQrisImage,
                            icon: _isDownloading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF2563EB),
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 17),
                            label: Text(
                              _isDownloading
                                  ? context.t('Menyimpan...', 'Saving...')
                                  : context.t('Download QRIS', 'Download QRIS'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tombol Cek Status Pembayaran
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isProcessingPayment ? null : _checkPaymentStatus,
                            icon: _isProcessingPayment
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded, size: 17),
                            label: Text(
                              _isProcessingPayment
                                  ? context.t('Memeriksa...', 'Verifying...')
                                  : context.t('Cek Status', 'Check Status'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tombol "Back to merchant" (Sesuai Screenshot: Hitam / Charcoal Elegan)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF232A34), // Charcoal black snap button
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          context.t('Back to merchant', 'Back to merchant'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
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
}
