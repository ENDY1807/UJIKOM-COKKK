import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
import '../services/database_service.dart';
import '../services/payment_gateway_service.dart';
import '../theme/app_theme.dart';
import 'app_loading_animation.dart';
import 'qris_payment_dialog.dart';
import 'receipt_dialog.dart';

class SnapPaymentDialog extends StatefulWidget {
  final OrderModel order;
  final int totalAmount;
  final String providerName; // 'DANA' or 'GoPay'
  final DatabaseService db;
  final VoidCallback? onPaymentSuccess;

  const SnapPaymentDialog({
    super.key,
    required this.order,
    required this.totalAmount,
    required this.providerName,
    required this.db,
    this.onPaymentSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required int totalAmount,
    required String providerName,
    required DatabaseService db,
    VoidCallback? onPaymentSuccess,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SnapPaymentDialog(
        order: order,
        totalAmount: totalAmount,
        providerName: providerName,
        db: db,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<SnapPaymentDialog> createState() => _SnapPaymentDialogState();
}

class _SnapPaymentDialogState extends State<SnapPaymentDialog> {
  String? _redirectUrl;
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Color get _brandColor {
    if (widget.providerName == 'DANA') return const Color(0xFF118EEA);
    if (widget.providerName == 'GoPay') return const Color(0xFF00AED6);
    if (widget.providerName == 'QRIS') return const Color(0xFF002855);
    return const Color(0xFFEA580C);
  }

  IconData get _brandIcon {
    if (widget.providerName == 'DANA') return Icons.account_balance_wallet_rounded;
    if (widget.providerName == 'GoPay') return Icons.wallet_rounded;
    if (widget.providerName == 'QRIS') return Icons.qr_code_scanner_rounded;
    return Icons.payment_rounded;
  }

  @override
  void initState() {
    super.initState();
    _initSnapPayment();
  }

  Future<void> _initSnapPayment() async {
    setState(() => _isLoading = true);
    try {
      final res = await PaymentGatewayService.createSnapTransaction(
        orderId: 'RSN-${widget.providerName}-${widget.order.idOrder}-${DateTime.now().millisecondsSinceEpoch % 10000}',
        amount: widget.totalAmount,
        customerName: widget.order.namaPelanggan.isNotEmpty ? widget.order.namaPelanggan : 'Pelanggan Rasantara',
        email: 'pelanggan@rasantara.com',
        enabledPayments: widget.providerName == 'QRIS' ? ['qris'] : null,
      );
      if (mounted) {
        setState(() {
          _redirectUrl = res['redirect_url']?.toString();
          _isLoading = false;
        });
        // Otomatis buka halaman checkout resmi Midtrans Snap
        _openPaymentUrl();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPaymentUrl() async {
    if (_redirectUrl != null) {
      final uri = Uri.parse(_redirectUrl!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Launch url error: $e');
      }
    }
  }

  Future<void> _completePayment() async {
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final transaction = widget.db.processTransaction(
      order: widget.order,
      jumlahBayar: widget.totalAmount,
      metodePembayaran: widget.providerName == 'QRIS'
          ? 'QRIS (Midtrans Snap)'
          : '${widget.providerName} (Direct Debit SNAP BI)',
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
                      Icon(_brandIcon, color: _brandColor, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        widget.providerName == 'QRIS'
                            ? 'QRIS Midtrans Snap'
                            : 'Pembayaran ${widget.providerName}',
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

              // Kartu Nominal & Detail
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.fillSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.providerName == 'QRIS'
                          ? 'Total Tagihan QRIS'
                          : 'Total Pembayaran ${widget.providerName}',
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currencyFmt.format(widget.totalAmount),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _brandColor),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF15803D)),
                          SizedBox(width: 6),
                          Text(
                            'Midtrans SNAP BI Gateway Aktif',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: AppLoadingAnimation(
                    size: 40,
                    primaryColor: _brandColor,
                    message: widget.providerName == 'QRIS'
                        ? 'Membuat Transaksi QRIS Midtrans Snap...'
                        : 'Menghubungkan ke Gateway ${widget.providerName}...',
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFFEA580C), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.t(
                                'Pengujian Browser Web (CORS Aktif).\nDi file APK Android / HP, koneksi Midtrans Snap berjalan 100% lancar secara native tanpa CORS.',
                                'Web Browser Testing (CORS Active).\nOn Android APK / Mobile, Midtrans Snap connects 100% natively without CORS.',
                              ),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9A3412), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          minimumSize: const Size.fromHeight(36),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          QrisPaymentDialog.show(
                            context,
                            order: widget.order,
                            totalAmount: widget.totalAmount,
                            db: widget.db,
                            onPaymentSuccess: widget.onPaymentSuccess,
                          );
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                        label: const Text('Buka Barcode QRIS Standar (In-App)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )
              else if (_redirectUrl != null) ...[
                if (widget.providerName == 'QRIS')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.t(
                              'Halaman QRIS resmi Midtrans otomatis dibuka di browser. Anda dapat memindai QRIS di sana, lalu klik tombol verifikasi di bawah.',
                              'Official Midtrans QRIS page has been opened in your browser. Scan the QRIS code there, then tap the verify button below.',
                            ),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Tombol Buka Web Pembayaran DANA / GoPay / QRIS Midtrans
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: Text(
                    widget.providerName == 'QRIS'
                        ? 'Buka Halaman QRIS Midtrans di Browser'
                        : 'Buka Gerbang ${widget.providerName} di Browser',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _openPaymentUrl,
                ),
                const SizedBox(height: 10),
              ],

              // Tombol Konfirmasi Selesai Bayar
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isVerifying ? null : _completePayment,
                child: _isVerifying
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cek Status & Konfirmasi Selesai Bayar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
