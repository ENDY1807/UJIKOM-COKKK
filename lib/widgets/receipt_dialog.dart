import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/transaction_model.dart';
import '../services/export_report_service.dart';
import '../theme/app_theme.dart';

class ReceiptDialog extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm:ss');
    final order = transaction.order;

    // Hitung diskon & potongan
    final diskonEvent = transaction.diskonEvent > 0 ? transaction.diskonEvent : order.diskonEvent;
    final diskonKupon = transaction.diskonKupon > 0 ? transaction.diskonKupon : order.diskonKupon;
    final potonganPoin = transaction.potonganPoin > 0 ? transaction.potonganPoin : order.potonganPoin;
    final diskonMember = transaction.diskonMember > 0 ? transaction.diskonMember : order.diskonMember;
    final kodeKupon = transaction.kodeKupon.isNotEmpty ? transaction.kodeKupon : order.kodeKupon;

    final subtotal = order.totalHarga;
    final grandTotal = transaction.totalBayar;

    final qrPayload = 'https://rasantara.resto/verify/trx?id=${transaction.idTransaksi}&ord=${order.idOrder}&amt=$grandTotal&ts=${transaction.tanggal.millisecondsSinceEpoch}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Struk Termal Resmi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'RASANTARA',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Cita Rasa Kuliner Nusantara',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Bandung',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                    const Text(
                      'Telp: (022) 756-4321 • NPWPD: 98.765.432.1-429.000',
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              // Garis Potong Termal Berlubang (Perforated Line)
              Row(
                children: List.generate(
                  30,
                  (index) => Expanded(
                    child: Container(
                      color: index % 2 == 0 ? Colors.transparent : const Color(0xFFCBD5E1),
                      height: 1.5,
                    ),
                  ),
                ),
              ),

              // Scrollable Detail Struk
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metadata Transaksi
                      _buildReceiptRow(context.t('No. Transaksi', 'Transaction No.'), '#TRX-${transaction.idTransaksi.toString().padLeft(5, '0')}'),
                      _buildReceiptRow(context.t('No. Pesanan', 'Order No.'), '#ORD-${order.idOrder}'),
                      _buildReceiptRow(context.t('Waktu Transaksi', 'Transaction Time'), dateFmt.format(transaction.tanggal)),
                      _buildReceiptRow(context.t('Layanan / Meja', 'Service / Table'), order.noMeja),
                      _buildReceiptRow(context.t('Nama Pelanggan', 'Customer Name'), order.namaPelanggan),
                      _buildReceiptRow(context.t('Kasir Pemroses', 'Cashier'), transaction.namaKasir),
                      _buildReceiptRow(context.t('Metode Pembayaran', 'Payment Method'), transaction.metodePembayaran, isBoldValue: true),

                      const SizedBox(height: 12),
                      _buildDashedLine(),
                      const SizedBox(height: 10),

                      // Daftar Item Hidangan
                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.jumlah}x',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.menu.namaMasakan,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                    if (item.catatan.isNotEmpty)
                                      Text(
                                        '${context.t('Catatan', 'Notes')}: ${item.catatan}',
                                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                currencyFmt.format(item.subtotal),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 10),
                      _buildDashedLine(),
                      const SizedBox(height: 10),

                      // Rincian Biaya & Diskon
                      _buildCostSummaryRow(context.t('Subtotal Hidangan', 'Dishes Subtotal'), currencyFmt.format(subtotal)),
                      if (diskonEvent > 0)
                        _buildCostSummaryRow(context.t('Diskon Event Promo', 'Promo Event Discount'), '- ${currencyFmt.format(diskonEvent)}', isDiscount: true),
                      if (diskonMember > 0)
                        _buildCostSummaryRow(context.t('Diskon Pelanggan Langganan (VIP 10%)', 'VIP Member Discount (10%)'), '- ${currencyFmt.format(diskonMember)}', isDiscount: true),
                      if (diskonKupon > 0)
                        _buildCostSummaryRow('${context.t('Diskon Kupon', 'Coupon Discount')} ${kodeKupon.isNotEmpty ? "($kodeKupon)" : ""}', '- ${currencyFmt.format(diskonKupon)}', isDiscount: true),
                      if (potonganPoin > 0)
                        _buildCostSummaryRow(context.t('Potongan Poin Kuliner (1 Poin = Rp 1)', 'Culinary Points Discount (1 Point = Rp 1)'), '- ${currencyFmt.format(potonganPoin)}', isDiscount: true),
                      _buildCostSummaryRow(context.t('Pajak Restoran PB1 (10%)', 'Restaurant Tax PB1 (10%)'), context.t('Sudah Termasuk', 'Included'), isMuted: true),

                      const SizedBox(height: 8),
                      _buildDashedLine(),
                      const SizedBox(height: 8),

                      // Total Akhir
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.t('TOTAL TAGIHAN', 'TOTAL BILL'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            currencyFmt.format(grandTotal),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildReceiptRow(context.t('Jumlah Dibayar', 'Amount Paid'), currencyFmt.format(transaction.jumlahBayar)),
                      _buildReceiptRow(context.t('Kembalian', 'Change'), currencyFmt.format(transaction.kembalian), isBoldValue: true),

                      const SizedBox(height: 16),

                      // QR Code Verifikasi Keaslian Struk
                      Center(
                        child: Column(
                          children: [
                            QrImageView(
                              data: qrPayload,
                              version: QrVersions.auto,
                              size: 90.0,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1E293B)),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.t('Pindai QR untuk verifikasi keaslian struk digital', 'Scan QR to verify digital receipt authenticity'),
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.t('*** TERIMA KASIH ATAS KUNJUNGAN ANDA ***', '*** THANK YOU FOR YOUR VISIT ***'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tombol Tindakan (Cetak Struk & Tutup)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          await ExportReportService.printReceiptPdf(
                            transaction: transaction,
                            restaurantName: 'Rasantara Restoran',
                            address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Bandung',
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text(context.t('Cetak Struk', 'Print Receipt'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('Tutup', 'Close'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildReceiptRow(String title, String val, {bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Text(
            val,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummaryRow(String title, String val, {bool isDiscount = false, bool isMuted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              color: isDiscount ? const Color(0xFF16A34A) : (isMuted ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              fontWeight: isDiscount ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isDiscount ? FontWeight.bold : FontWeight.w600,
              color: isDiscount ? const Color(0xFF16A34A) : (isMuted ? const Color(0xFF94A3B8) : const Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return Row(
      children: List.generate(
        40,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.transparent : const Color(0xFFE2E8F0),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
