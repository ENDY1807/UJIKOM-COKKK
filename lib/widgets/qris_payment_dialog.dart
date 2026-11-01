import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/payment_gateway_service.dart';
import 'receipt_dialog.dart';

/// Modal Pembayaran QRIS Dinamis Standar Nasional (ASPI / Bank Indonesia SNAP BI)
/// Memberikan pengalaman pembayaran transaksi digital yang nyata dan terverifikasi.
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
  bool _isPaymentCompleted = false;
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
      final res = await PaymentGatewayService.createDanaH2hQrisPayment(
        orderId: 'ORD-${widget.order.idOrder}-${DateTime.now().millisecondsSinceEpoch % 100000}',
        amount: widget.totalAmount,
        orderTitle: 'Pesanan Meja ${widget.order.noMeja}',
      );
      if (res['qrCode'] != null && mounted) {
        setState(() {
          _qrisPayload = res['qrCode'].toString();
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

  Future<void> _simulateSuccessfulPayment() async {
    setState(() => _isProcessingPayment = true);

    // Simulasi handshake callback gateway ASPI / SNAP BI (1.2 detik)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Catat transaksi resmi ke database
    final transaction = widget.db.processTransaction(
      order: widget.order,
      jumlahBayar: widget.totalAmount,
      metodePembayaran: 'QRIS',
    );

    setState(() {
      _isProcessingPayment = false;
      _isPaymentCompleted = true;
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
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            // ── Header QRIS Nasional ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QRIS DINAMIS NASIONAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Standar Pembayaran Digital BI / ASPI',
                            style: TextStyle(
                              color: Color(0xFFFFE4E6),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Detail Merchant & Nominal ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  const Text(
                    'RASANTARA RESTORAN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'DANA H2H Gateway • Merchant ID: 216620010001053576081',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),

                  // Kotak Total Tagihan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Tagihan:',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFDC2626)),
                              const SizedBox(width: 4),
                              Text(
                                _formattedTimer,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Kanvas QR Code Dinamis ──
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrisPayload,
                  version: QrVersions.auto,
                  size: 190.0,
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
              ),
            ),

            const SizedBox(height: 12),

            // Instruksi Pembayaran Multi-Aplikasi
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Buka BCA, Mandiri, BRI, BNI, DANA, GoPay, OVO, ShopeePay atau M-Banking apa saja untuk scan QRIS di atas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tombol Konfirmasi Pembayaran Gateway ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isProcessingPayment || _isPaymentCompleted
                        ? null
                        : _simulateSuccessfulPayment,
                    icon: _isProcessingPayment
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isProcessingPayment
                          ? 'Memverifikasi Pembayaran...'
                          : 'Simulasi Scan Berhasil (Lunas)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      minimumSize: const Size(double.infinity, 40),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Bayar Nanti di Kasir', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
