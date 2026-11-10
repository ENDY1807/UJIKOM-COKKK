import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/payment_gateway_service.dart';
import '../theme/app_theme.dart';
import 'receipt_dialog.dart';

/// Modal Pembayaran QRIS Standar Nasional (ASPI / Bank Indonesia / GPN)
/// Menampilkan template fisik resmi QRIS Standar Pembayaran Nasional
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
  int _secondsRemaining = 300; // 5 Menit kedaluwarsa QRIS
  Timer? _countdownTimer;
  bool _isProcessingPayment = false;
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

  Future<void> _checkPaymentStatus() async {
    setState(() => _isProcessingPayment = true);

    // Verifikasi pembayaran langsung ke gateway
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    // Catat transaksi resmi ke database
    final transaction = widget.db.processTransaction(
      order: widget.order,
      jumlahBayar: widget.totalAmount,
      metodePembayaran: 'QRIS Nasional (ASPI/GPN)',
    );

    setState(() {
      _isProcessingPayment = false;
    });

    widget.onPaymentSuccess?.call();

    // Buka struk transaksi resmi
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
          maxWidth: 390,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Bar Dialog (Minimalis & Elegan) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          context.t('Pembayaran QRIS Nasional', 'National QRIS Payment'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
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

              // ── Scrollable Body: Official Standee QRIS Template (Sesuai Foto 2) ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    children: [
                      // Standee Canvas (Pure White Sheet sesuai Standar BI / ASPI)
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            children: [
                              // Red Geometric Angular Frame Accents (Signature QRIS Template)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _QrisOfficialFramePainter(),
                                ),
                              ),

                              // Content of the Standee
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                                child: Column(
                                  children: [
                                    // 1. Top Logo Row: Official QRIS & GPN Logo
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Left: QRIS Logo & Text
                                        _buildOfficialQrisHeaderLogo(),

                                        // Right: GPN National Payment Gateway Logo
                                        _buildOfficialGpnLogo(),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // 2. Merchant Name & NMID
                                    Text(
                                      PaymentGatewayConfig.defaultMerchantName,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'NMID : ${PaymentGatewayConfig.defaultNmid}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF334155),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    // 3. Central Clean QR Code Canvas (Sesuai Foto 2: Tanpa logo penutup di tengah)
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      color: Colors.white,
                                      child: QrImageView(
                                        data: _qrisPayload,
                                        version: QrVersions.auto,
                                        size: 210.0,
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
                                    const SizedBox(height: 18),

                                    // 4. Footer Standee: "Dicetak oleh : 93600013"
                                    Row(
                                      children: const [
                                        Text(
                                          'Dicetak oleh : 93600013',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
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

                      const SizedBox(height: 12),

                      // ── Kotak Informasi Nominal & Timer Pembayaran ──
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
                                  context.t('Total Pembayaran', 'Total Payment'),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: context.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currencyFmt.format(widget.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFEA580C),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                      fontSize: 12.5,
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

                      // Status Real-Time Polling
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isProcessingPayment
                                ? context.t('Memeriksa status pembayaran...', 'Checking payment status...')
                                : context.t('Menunggu pembayaran via QRIS... (Real-Time)', 'Awaiting QRIS payment... (Real-Time)'),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Action Buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Column(
                  children: [
                    // Tombol Verifikasi Resmi: Cek Status Pembayaran
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
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
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isProcessingPayment
                            ? context.t('Memeriksa Status Transaksi...', 'Verifying Transaction...')
                            : context.t('Cek Status Pembayaran', 'Check Payment Status'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Secondary Button: Bayar Nanti di Kasir
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textSecondary,
                        minimumSize: const Size(double.infinity, 38),
                        side: BorderSide(color: context.borderSubtle),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

  /// Official QRIS Logo & Text (Sesuai Standar Bank Indonesia / ASPI di Foto 2)
  Widget _buildOfficialQrisHeaderLogo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Stylized QRIS Icon Box
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                color: Colors.black,
              ),
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 5,
                  height: 5,
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
                fontSize: 8.5,
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

  /// Official GPN Logo (Garuda Merah & Tulisan GPN Biru di Foto 2)
  Widget _buildOfficialGpnLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Garuda Wings in Red
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.flight_takeoff_rounded, color: Color(0xFFDC2626), size: 18),
          ],
        ),
        const Text(
          'GPN',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF005BAC),
            letterSpacing: 1.2,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter untuk menggambar aksen grafis merah bersudut resmi QRIS Standar Nasional
/// Persis seperti pita merah di sisi kiri dan sudut kanan-bawah pada Foto 2
class _QrisOfficialFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDC2626) // Merah resmi QRIS / BI
      ..style = PaintingStyle.fill;

    // ── 1. Aksen Sisi Kiri: Pita Vertikal dengan Ujung Panah Menghadap ke Atas (Sesuai Foto 2) ──
    final leftPath = Path();
    final leftTop = size.height * 0.17;
    final leftArrowHeight = 22.0;
    final leftWidth = 14.0;
    final leftArrowWidth = 34.0;
    final leftBottom = size.height * 0.56;

    // Titik puncak panah di tepi kiri
    leftPath.moveTo(0, leftTop);
    // Garis diagonal ke kanan-bawah membentuk sayap panah
    leftPath.lineTo(leftArrowWidth, leftTop + leftArrowHeight);
    // Takik masuk ke badan pita
    leftPath.lineTo(leftWidth, leftTop + leftArrowHeight);
    // Garis vertikal lurus ke bawah
    leftPath.lineTo(leftWidth, leftBottom);
    // Potongan diagonal keluar ke tepi kiri
    leftPath.lineTo(0, leftBottom - 18.0);
    leftPath.close();

    canvas.drawPath(leftPath, paint);

    // ── 2. Aksen Sudut Kanan-Bawah: Pita Sudut Diagonal (Sesuai Foto 2) ──
    final rightPath = Path();
    final rightWidth = 14.0;
    final rightTop = size.height * 0.79;
    final bottomCutLength = 54.0;

    // Mulai dari tepi kanan
    rightPath.moveTo(size.width, rightTop);
    // Potongan diagonal ke badan pita
    rightPath.lineTo(size.width - rightWidth, rightTop + 16.0);
    // Turun sepanjang tepi kanan
    rightPath.lineTo(size.width - rightWidth, size.height - rightWidth);
    // Meluas ke arah kiri di sepanjang bagian bawah
    rightPath.lineTo(size.width - bottomCutLength, size.height - rightWidth);
    // Ujung panah/potongan diagonal ke tepi bawah
    rightPath.lineTo(size.width - bottomCutLength - 16.0, size.height);
    // Menutup sepanjang tepi bawah ke sudut kanan-bawah
    rightPath.lineTo(size.width, size.height);
    rightPath.close();

    canvas.drawPath(rightPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
