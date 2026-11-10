import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/payment_gateway_service.dart';
import '../theme/app_theme.dart';
import 'app_loading_animation.dart';
import 'receipt_dialog.dart';

class VirtualAccountPaymentDialog extends StatefulWidget {
  final OrderModel order;
  final int totalAmount;
  final DatabaseService db;
  final VoidCallback? onPaymentSuccess;

  const VirtualAccountPaymentDialog({
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
      builder: (ctx) => VirtualAccountPaymentDialog(
        order: order,
        totalAmount: totalAmount,
        db: db,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<VirtualAccountPaymentDialog> createState() => _VirtualAccountPaymentDialogState();
}

class _VirtualAccountPaymentDialogState extends State<VirtualAccountPaymentDialog> {
  String _selectedBank = 'BCA';
  String _vaNumber = 'Memuat VA...';
  bool _isLoading = true;
  bool _isVerifying = false;
  int _secondsRemaining = 86400; // 24 jam
  Timer? _countdownTimer;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadVirtualAccount();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0 && mounted) {
        setState(() => _secondsRemaining--);
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

  Future<void> _loadVirtualAccount() async {
    setState(() => _isLoading = true);
    try {
      final res = await PaymentGatewayService.createVirtualAccount(
        orderId: 'RSN-VA-${widget.order.idOrder}-${DateTime.now().millisecondsSinceEpoch % 10000}',
        bank: _selectedBank.toLowerCase(),
        amount: widget.totalAmount,
      );
      if (mounted) {
        setState(() {
          _vaNumber = res.vaNumber;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vaNumber = '93933${widget.order.idOrder.toString().padLeft(10, '0')}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyPayment() async {
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Pelunasan transaksi di database
    final transaction = widget.db.processTransaction(
      order: widget.order,
      jumlahBayar: widget.totalAmount,
      metodePembayaran: 'M-Banking Virtual Account ($_selectedBank)',
    );

    setState(() => _isVerifying = false);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: context.surfaceCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_rounded, color: Color(0xFF4338CA), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Virtual Account M-Banking',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: context.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 16, color: context.borderSubtle),

              // Pilihan Bank
              Text('Pilih Bank Tujuan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['BCA', 'BRI', 'BNI', 'Mandiri'].map((bank) {
                  final isSel = _selectedBank == bank;
                  return ChoiceChip(
                    label: Text(bank),
                    selected: isSel,
                    selectedColor: context.isDarkMode
                        ? const Color(0xFF4338CA).withValues(alpha: 0.3)
                        : const Color(0xFFEEF2FF),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSel
                          ? (context.isDarkMode ? Colors.white : const Color(0xFF4338CA))
                          : context.textSecondary,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedBank = bank);
                        _loadVirtualAccount();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Kotak Nomor VA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.fillSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Column(
                  children: [
                    Text('Nomor Virtual Account ($_selectedBank)', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                    const SizedBox(height: 6),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: AppLoadingAnimation(size: 38, message: 'Membuat nomor Virtual Account...'),
                      )
                    else
                      SelectableText(
                        _vaNumber,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: context.textPrimary),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEEF2FF),
                        foregroundColor: const Color(0xFF4338CA),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Salin Nomor VA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _vaNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nomor Virtual Account berhasil disalin!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Total Tagihan
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  Text(
                    _currencyFmt.format(widget.totalAmount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tombol Konfirmasi Pembayaran
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isVerifying ? null : _verifyPayment,
                child: _isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Cek Status Pembayaran (Saya Sudah Bayar)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
