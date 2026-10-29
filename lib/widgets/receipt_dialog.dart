import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../theme/app_theme.dart';

class ReceiptDialog extends StatelessWidget {
  final TransactionModel transaction;

  const ReceiptDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm:ss');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Receipt Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.orangeLight,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.statusGreen,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'RESTORAN NUSANTARA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Table Service & Family Dining',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jl. Raya Pendidikan No. 45, Kota Ujikom',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),

            // Receipt Meta
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  _metaRow('No. Transaksi', '#TRX-${transaction.idTransaksi.toString().padLeft(4, '0')}'),
                  _metaRow('Waktu', dateFormatter.format(transaction.tanggal)),
                  _metaRow('Meja / Pelanggan', '${transaction.order.noMeja} (${transaction.order.namaPelanggan})'),
                  _metaRow('Kasir', transaction.namaKasir),
                  _metaRow('Metode', transaction.metodePembayaran),
                  const SizedBox(height: 10),
                  const Divider(thickness: 1, color: AppTheme.borderSubtle),
                  const SizedBox(height: 8),

                  // Items List
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: transaction.order.items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = transaction.order.items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.jumlah}x',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.menu.namaMasakan,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                                  ),
                                  if (item.catatan.isNotEmpty)
                                    Text(
                                      'Note: ${item.catatan}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormatter.format(item.subtotal),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(thickness: 1, color: AppTheme.borderSubtle),
                  const SizedBox(height: 10),

                  // Calculation
                  _totalRow('Total Tagihan', currencyFormatter.format(transaction.totalBayar), isBold: true),
                  const SizedBox(height: 4),
                  _totalRow('Tunai / Bayar', currencyFormatter.format(transaction.jumlahBayar)),
                  const SizedBox(height: 4),
                  _totalRow('Kembalian', currencyFormatter.format(transaction.kembalian), isHighlight: true),
                ],
              ),
            ),

            // Footer / Actions
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Struk berhasil disimulasikan cetak ke printer kasir'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Cetak Struk'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textDark)),
        ],
      ),
    );
  }

  Widget _totalRow(String title, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? AppTheme.orangePrimary : AppTheme.textDark,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isHighlight ? AppTheme.orangePrimary : AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
