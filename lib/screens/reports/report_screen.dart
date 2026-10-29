import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_dialog.dart';

class ReportScreen extends StatefulWidget {
  final DatabaseService db;

  const ReportScreen({super.key, required this.db});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  void _showPrintReportPreview() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.print, color: AppTheme.orangePrimary),
              SizedBox(width: 8),
              Text('Pratinjau Laporan Penjualan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: Text(
                      'LAPORAN TRANSAKSI RESTORAN NUSANTARA\nUJIKOM REKAYASA PERANGKAT LUNAK',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Text('Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}'),
                  Text('Total Transaksi: ${widget.db.totalTransaksiCount} Transaksi'),
                  Text('Total Omzet: ${_currencyFormat.format(widget.db.totalOmzet)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Daftar Transaksi Selesai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...widget.db.transactions.map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('#TRX-${t.idTransaksi} (${t.order.noMeja}) - ${t.namaKasir}', style: const TextStyle(fontSize: 12)),
                          Text(_currencyFormat.format(t.totalBayar), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  const Center(
                    child: Text(
                      'Dokumen ini sah dihasilkan secara sistematis oleh Aplikasi Kasir Restoran',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Laporan siap dicetak atau disimpan sebagai PDF'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Cetak Sekarang'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = widget.db.transactions;
    final topSelling = widget.db.topSellingMenus;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Action Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laporan Penjualan & Keuangan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      'Rekapitulasi omzet dan riwayat pembayaran table service',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showPrintReportPreview,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Cetak Laporan'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3 Summary Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final cards = [
                  _summaryCard(
                    title: 'Total Pendapatan',
                    value: _currencyFormat.format(widget.db.totalOmzet),
                    subtitle: 'Semua transaksi selesai',
                    icon: Icons.account_balance_wallet,
                    isPrimary: true,
                  ),
                  _summaryCard(
                    title: 'Jumlah Transaksi',
                    value: '${widget.db.totalTransaksiCount} Order',
                    subtitle: 'Lunas & terlayani',
                    icon: Icons.receipt_long,
                  ),
                  _summaryCard(
                    title: 'Rata-Rata Bill',
                    value: _currencyFormat.format(widget.db.rataRataTransaksi),
                    subtitle: 'Rata-rata per meja',
                    icon: Icons.trending_up,
                  ),
                ];

                if (isWide) {
                  return Row(
                    children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
                  );
                } else {
                  return Column(
                    children: cards.map((c) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: c)).toList(),
                  );
                }
              },
            ),

            const SizedBox(height: 20),

            // Top Selling Menu Items
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star_outline, color: AppTheme.orangePrimary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Menu Terlaris (Favorit Pelanggan)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (topSelling.isEmpty)
                      const Text('Belum ada data penjualan menu', style: TextStyle(color: AppTheme.textMuted))
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: topSelling.take(6).map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.orangeLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.orangeBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  entry.key,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textDark),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orangePrimary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${entry.value} Terjual',
                                    style: const TextStyle(color: AppTheme.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Transaction History Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderSubtle),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Riwayat Transaksi Kasir',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 12),
                    if (transactions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Belum ada transaksi tercatat', style: TextStyle(color: AppTheme.textMuted)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.borderSubtle),
                        itemBuilder: (context, index) {
                          final trx = transactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orangeLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.receipt, color: AppTheme.orangePrimary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '#TRX-${trx.idTransaksi.toString().padLeft(4, '0')} • ${trx.order.noMeja}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textDark),
                                      ),
                                      Text(
                                        'Kasir: ${trx.namaKasir} • ${_dateFormat.format(trx.tanggal)}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _currencyFormat.format(trx.totalBayar),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.orangePrimary),
                                    ),
                                    Text(
                                      trx.metodePembayaran,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 20, color: AppTheme.textMuted),
                                  tooltip: 'Lihat Struk',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => ReceiptDialog(transaction: trx),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    bool isPrimary = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isPrimary ? AppTheme.orangeBorder : AppTheme.borderSubtle),
      ),
      color: isPrimary ? AppTheme.orangeLight : AppTheme.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary ? AppTheme.orangePrimary : AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: isPrimary ? AppTheme.white : AppTheme.orangePrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? AppTheme.orangePrimary : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
