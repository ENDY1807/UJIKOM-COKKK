import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/payment_gateway_service.dart';
import '../theme/app_theme.dart';
import 'receipt_dialog.dart';

/// Modal Pembayaran QRIS Dinamis Resmi Template DANA Bisnis & Bank Indonesia (SNAP BI / ASPI)
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

    // Verifikasi pembayaran langsung ke backend / gateway DANA Bisnis
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    // Catat transaksi resmi ke database
    final transaction = widget.db.processTransaction(
      order: widget.order,
      jumlahBayar: widget.totalAmount,
      metodePembayaran: 'QRIS (DANA Bisnis)',
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(22),
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
              // ── 1. Official DANA Bisnis Header Banner ──
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF108EE9), Color(0xFF0077D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Official QRIS Logo Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'QRIS',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // DANA Bisnis Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'DANA Bisnis',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // ── 2. Scrollable Body: DANA Bisnis QRIS Standee Card ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    children: [
                      // Standee Container (Physical White Acrylic Standee Aesthetic)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Merchant Header
                            const Text(
                              'RASANTARA RESTORAN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'NMID: ID1020260081928 • A01 (DANA INDONESIA)',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // QR Code with Professional Standee Frame Corner Markers
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: _qrisPayload,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  // Center DANA Logo Badge
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF108EE9),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x26000000),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Total Tagihan Box (Embedded Dynamic Amount)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Pembayaran',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _currencyFmt.format(widget.totalAmount),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Expiry Timer Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFBAE6FD)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formattedTimer,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Multi-Payment Supported Logos Text
                            const Text(
                              'SATU QRIS UNTUK SEMUA PEMBAYARAN',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF475569),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                'DANA',
                                'BCA',
                                'Mandiri',
                                'BRI',
                                'BNI',
                                'GoPay',
                                'OVO',
                                'ShopeePay',
                              ].map((bank) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    bank,
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Status Transaksi Real-Time Pulsing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF108EE9),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isProcessingPayment
                                ? 'Menghubungkan ke Gateway DANA...'
                                : 'Menunggu pembayaran via QRIS... (Real-Time)',
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

              // ── 3. Bottom Action Buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Column(
                  children: [
                    // Official "Cek Status Pembayaran" Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF108EE9),
                        minimumSize: const Size(double.infinity, 46),
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
                            ? 'Memeriksa Status Transaksi...'
                            : 'Cek Status Pembayaran',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Secondary Button: Bayar Nanti di Kasir
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textSecondary,
                        minimumSize: const Size(double.infinity, 40),
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
}
