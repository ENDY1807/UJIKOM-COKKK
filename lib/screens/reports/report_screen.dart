import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/export_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/receipt_dialog.dart';

class ReportScreen extends StatefulWidget {
  final DatabaseService db;

  const ReportScreen({super.key, required this.db});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  bool _showDiagrams = true;
  bool _isSyncingCloud = false;

  @override
  void initState() {
    super.initState();
    widget.db.addListener(_onDbChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshFromSupabase();
    });
  }

  @override
  void dispose() {
    widget.db.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshFromSupabase() async {
    if (_isSyncingCloud) return;
    setState(() => _isSyncingCloud = true);
    await widget.db.syncReportDataFromCloud();
    if (mounted) {
      setState(() {
        _isSyncingCloud = false;
      });
    }
  }

  void _showPrintReportPreview() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.print, color: AppTheme.orangePrimary),
              SizedBox(width: 8),
              Text(
                'Pratinjau Laporan Penjualan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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
                      'LAPORAN TRANSAKSI RESTORAN RASANTARA (TABLE SERVICE)\nREKAPITULASI KASIR & PENJUALAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Text(
                    'Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}',
                  ),
                  Text(
                    'Total Transaksi: ${widget.db.totalTransaksiCount} Transaksi',
                  ),
                  Text(
                    'Total Omzet: ${_currencyFormat.format(widget.db.totalOmzet)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Daftar Transaksi Selesai:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  ...widget.db.transactions.map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#TRX-${t.idTransaksi} (${t.order.noMeja}) - ${t.namaKasir}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _currencyFormat.format(t.totalBayar),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  const Center(
                    child: Text(
                      'Dokumen ini sah dihasilkan secara sistematis oleh Aplikasi Kasir Restoran',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
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
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ExportReportService.exportTransactionsExcelCsv(
                  transactions: widget.db.transactions,
                );
              },
              icon: const Icon(Icons.table_view_rounded, size: 18),
              label: const Text('Ekspor Excel (CSV)'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await ExportReportService.exportTransactionsPdf(
                  transactions: widget.db.transactions,
                  totalOmzet: widget.db.totalOmzet,
                  restaurantName: 'Rasantara Restoran (Table Service)',
                  address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Kota Bandung',
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text('Cetak Dokumen PDF'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.db.currentUser;
    final role = currentUser?.role ?? UserRole.owner;

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: RefreshIndicator(
        onRefresh: _refreshFromSupabase,
        color: AppTheme.orangePrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          child: _buildRoleSpecificReport(role),
        ),
      ),
    );
  }

  Widget _buildRoleSpecificReport(UserRole role) {
    switch (role) {
      case UserRole.waiter:
        return _buildWaiterBestSellerReport();
      case UserRole.kasir:
        return _buildKasirSalesReport();
      case UserRole.owner:
        return _buildOwnerRevenueReport();
      case UserRole.administrator:
      default:
        return _buildAdminFullReport();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HELPER RESPONSIVE MOBILE TAMPILAN LEBIH RAPIH & TERSTRUKTUR
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildResponsiveSummaryCards(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: c,
            )).toList(),
          );
        }
        return Row(
          children: cards.asMap().entries.map((entry) {
            final idx = entry.key;
            final card = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: idx < cards.length - 1 ? 8 : 0),
                child: card,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildResponsiveHeader({
    required BuildContext context,
    required Widget titleWidget,
    required Widget subtitleWidget,
    required List<Widget> actions,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;
        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 4),
              subtitleWidget,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: actions.map((a) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: a,
                    )).toList(),
                  ),
                ),
              ],
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleWidget,
                  const SizedBox(height: 4),
                  subtitleWidget,
                ],
              ),
            ),
            const SizedBox(width: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 1. LAPORAN KHUSUS WAITER: LAPORAN MAKANAN BEST SELLER
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildWaiterBestSellerReport() {
    final topSelling = widget.db.topSellingMenus;
    final totalPortions = topSelling.fold<int>(0, (sum, e) => sum + e.value);
    final topOne = topSelling.isNotEmpty ? topSelling.first.key : 'Belum Ada';
    final topOneQty = topSelling.isNotEmpty ? topSelling.first.value : 0;
    final menus = widget.db.menus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Waiter
        _buildResponsiveHeader(
          context: context,
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.military_tech_rounded, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Laporan Makanan Best Seller',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitleWidget: Text(
            'Peringkat menu masakan & minuman terfavorit tamu untuk panduan table service',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
              ),
              onPressed: _isSyncingCloud ? null : _refreshFromSupabase,
              icon: _isSyncingCloud
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Segarkan'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 3 Metrik Waiter
        _buildResponsiveSummaryCards(
          context,
          [
            _summaryCard(
              title: 'Total Porsi Terjual',
              value: '$totalPortions Porsi',
              subtitle: 'Dipesan oleh tamu',
              icon: Icons.restaurant_rounded,
              isPrimary: true,
            ),
            _summaryCard(
              title: 'Menu Terlaris #1',
              value: topOne,
              subtitle: '$topOneQty porsi terjual',
              icon: Icons.star_rounded,
            ),
            _summaryCard(
              title: 'Total Hidangan',
              value: '${menus.length} Menu',
              subtitle: 'Katalog aktif restoran',
              icon: Icons.inventory_2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Kartu Panduan Rekomendasi Table Service
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tips Pelayanan Waiter (Table Service)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rekomendasikan menu peringkat 1 s/d 3 di bawah saat tamu menanyakan hidangan unggulan khas Rasantara.',
                      style: TextStyle(fontSize: 12, color: Colors.brown.shade700, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Daftar Peringkat Menu Terlaris (Best Seller Table)
        Card(
          elevation: 0,
          color: context.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Peringkat Menu Terlaris (Best Seller)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${topSelling.length} Menu Terjual',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (topSelling.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Belum ada data pesanan menu yang tercatat.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  )
                else ...[
                  ...topSelling.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final item = entry.value;
                    final maxSold = topSelling.first.value;
                    final ratio = maxSold > 0 ? (item.value / maxSold) : 0.0;

                    Color rankColor = const Color(0xFF64748B);
                    Color rankBg = const Color(0xFFF1F5F9);
                    if (rank == 1) {
                      rankColor = const Color(0xFFD97706);
                      rankBg = const Color(0xFFFEF3C7);
                    } else if (rank == 2) {
                      rankColor = const Color(0xFF475569);
                      rankBg = const Color(0xFFE2E8F0);
                    } else if (rank == 3) {
                      rankColor = const Color(0xFFB45309);
                      rankBg = const Color(0xFFFFEDD5);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: rankBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: rankColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.key,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    height: 6,
                                    color: context.borderSubtle,
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ratio.clamp(0.0, 1.0),
                                      child: Container(color: AppTheme.orangePrimary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rank == 1 ? const Color(0xFFDCFCE7) : context.surfaceBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: rank == 1 ? const Color(0xFFBBF7D0) : context.borderSubtle,
                              ),
                            ),
                            child: Text(
                              '${item.value} Porsi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: rank == 1 ? const Color(0xFF15803D) : context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 2. LAPORAN KHUSUS KASIR: DAFTAR PENJUALAN
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildKasirSalesReport() {
    final transactions = widget.db.transactions;
    int totalCash = 0;
    int totalQris = 0;
    for (final t in transactions) {
      final method = t.metodePembayaran.trim().toLowerCase();
      if (method.contains('qris')) {
        totalQris += t.totalBayar;
      } else {
        totalCash += t.totalBayar;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Kasir
        _buildResponsiveHeader(
          context: context,
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF16A34A), size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Laporan Daftar Penjualan Kasir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitleWidget: Text(
            'Rekapitulasi penjualan selesai, setoran uang tunai kasir, dan pembayaran QRIS',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
              ),
              onPressed: () async {
                await ExportReportService.exportTransactionsExcelCsv(
                  transactions: widget.db.transactions,
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Ekspor Excel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orangePrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await ExportReportService.exportTransactionsPdf(
                  transactions: widget.db.transactions,
                  totalOmzet: widget.db.totalOmzet,
                  restaurantName: 'Rasantara Restoran (Table Service)',
                  address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Kota Bandung',
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Cetak PDF'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Summary Kasir (Total Penjualan, Total Tunai Kasir, Total QRIS)
        _buildResponsiveSummaryCards(
          context,
          [
            _summaryCard(
              title: 'Total Penjualan Selesai',
              value: _currencyFormat.format(widget.db.totalOmzet),
              subtitle: '${transactions.length} Transaksi Terlayani',
              icon: Icons.payments_rounded,
              isPrimary: true,
            ),
            _summaryCard(
              title: 'Total Uang Tunai (Cash)',
              value: _currencyFormat.format(totalCash),
              subtitle: 'Uang fisik di laci kasir',
              icon: Icons.attach_money_rounded,
            ),
            _summaryCard(
              title: 'Total QRIS (Nirsentuh)',
              value: _currencyFormat.format(totalQris),
              subtitle: 'Masuk langsung rekening bank',
              icon: Icons.qr_code_2_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Daftar Transaksi Penjualan Kasir
        Card(
          elevation: 0,
          color: context.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daftar Transaksi Kasir',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    Text(
                      '${transactions.length} Transaksi Selesai',
                      style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Belum ada transaksi kasir yang selesai tercatat.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: context.borderSubtle),
                    itemBuilder: (context, index) {
                      final trx = transactions[index];
                      final isQris = trx.metodePembayaran.toUpperCase().contains('QRIS');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isQris ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isQris ? Icons.qr_code_2_rounded : Icons.payments_rounded,
                                color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#TRX-${trx.idTransaksi.toString().padLeft(4, '0')} • ${trx.order.noMeja}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: context.textPrimary),
                                  ),
                                  Text(
                                    'Kasir: ${trx.namaKasir} • ${_dateFormat.format(trx.tanggal)}',
                                    style: TextStyle(fontSize: 11.5, color: context.textSecondary),
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
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isQris ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isQris ? const Color(0xFFFFEDD5) : const Color(0xFFBBF7D0),
                                    ),
                                  ),
                                  child: Text(
                                    trx.metodePembayaran,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.print_outlined, size: 20, color: AppTheme.textMuted),
                              tooltip: 'Lihat & Cetak Struk',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => ReceiptDialog(transaction: trx, allowPrint: true),
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 3. LAPORAN KHUSUS OWNER: PENGHASILAN, DLL & DIAGRAM ANALITIK
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildOwnerRevenueReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Owner
        _buildResponsiveHeader(
          context: context,
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Laporan Penghasilan & Keuangan (Owner)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitleWidget: Text(
            'Analisis omzet restoran, tren pendapatan table service, dan performa finansial',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
              ),
              onPressed: () async {
                await ExportReportService.exportTransactionsExcelCsv(
                  transactions: widget.db.transactions,
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Ekspor Excel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orangePrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await ExportReportService.exportTransactionsPdf(
                  transactions: widget.db.transactions,
                  totalOmzet: widget.db.totalOmzet,
                  restaurantName: 'Rasantara Restoran (Table Service)',
                  address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Kota Bandung',
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Cetak Laporan'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Metric Cards Owner
        _buildResponsiveSummaryCards(
          context,
          [
            _summaryCard(
              title: 'Total Omzet Restoran',
              value: _currencyFormat.format(widget.db.totalOmzet),
              subtitle: 'Seluruh pesanan selesai',
              icon: Icons.account_balance_wallet_rounded,
              isPrimary: true,
            ),
            _summaryCard(
              title: 'Total Transaksi Selesai',
              value: '${widget.db.totalTransaksiCount} Order',
              subtitle: 'Lunas & terlayani',
              icon: Icons.receipt_long_rounded,
            ),
            _summaryCard(
              title: 'Rata-Rata Bill Meja',
              value: _currencyFormat.format(widget.db.rataRataTransaksi),
              subtitle: 'Average order value',
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Visual Diagram Charts Simple Oren-Putih
        AnalyticsChartsWidget(db: widget.db),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 4. LAPORAN ADMINISTRATOR: TERPADU (LENGKAP SEMUA MODUL)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildAdminFullReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Action Header Admin
        _buildResponsiveHeader(
          context: context,
          titleWidget: Text(
            'Laporan Terpadu Restoran (Admin)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          subtitleWidget: Text(
            'Rekapitulasi lengkap omzet penghasilan, penjualan kasir, dan menu best seller',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
              ),
              onPressed: _isSyncingCloud ? null : _refreshFromSupabase,
              icon: _isSyncingCloud
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Segarkan'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.orangePrimary,
                side: const BorderSide(color: AppTheme.orangePrimary),
              ),
              onPressed: _showPrintReportPreview,
              icon: const Icon(Icons.preview_rounded, size: 16),
              label: const Text('Pratinjau'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: const BorderSide(color: Color(0xFF16A34A)),
              ),
              onPressed: () async {
                await ExportReportService.exportTransactionsExcelCsv(
                  transactions: widget.db.transactions,
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Excel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orangePrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await ExportReportService.exportTransactionsPdf(
                  transactions: widget.db.transactions,
                  totalOmzet: widget.db.totalOmzet,
                  restaurantName: 'Rasantara Restoran (Table Service)',
                  address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Kota Bandung',
                );
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: const Text('Cetak PDF'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Summary Cards
        _buildResponsiveSummaryCards(
          context,
          [
            _summaryCard(
              title: 'Total Pendapatan',
              value: _currencyFormat.format(widget.db.totalOmzet),
              subtitle: 'Semua transaksi selesai',
              icon: Icons.account_balance_wallet_rounded,
              isPrimary: true,
            ),
            _summaryCard(
              title: 'Jumlah Transaksi',
              value: '${widget.db.totalTransaksiCount} Order',
              subtitle: 'Lunas & terlayani',
              icon: Icons.receipt_long_rounded,
            ),
            _summaryCard(
              title: 'Rata-Rata Bill',
              value: _currencyFormat.format(widget.db.rataRataTransaksi),
              subtitle: 'Rata-rata per meja',
              icon: Icons.trending_up_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Tab Switcher Admin: Diagram & Penghasilan vs Daftar Transaksi Kasir
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.fillSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _showDiagrams = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _showDiagrams ? context.surfaceCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _showDiagrams
                          ? const [BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 16,
                          color: _showDiagrams ? const Color(0xFFEA580C) : context.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Grafik Analitik Restoran',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _showDiagrams ? const Color(0xFFEA580C) : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _showDiagrams = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_showDiagrams ? context.surfaceCard : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: !_showDiagrams
                          ? const [BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: !_showDiagrams ? const Color(0xFFEA580C) : context.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Daftar Penjualan Kasir (${widget.db.transactions.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: !_showDiagrams ? const Color(0xFFEA580C) : context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_showDiagrams)
          AnalyticsChartsWidget(db: widget.db)
        else
          _buildKasirSalesReport(),
      ],
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
        side: BorderSide(
          color: isPrimary
              ? (context.isDarkMode ? const Color(0xFFEA580C) : AppTheme.orangeBorder)
              : context.borderSubtle,
        ),
      ),
      color: isPrimary
          ? (context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.35) : AppTheme.orangeLight)
          : context.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary
                    ? AppTheme.orangePrimary
                    : (context.isDarkMode ? const Color(0xFF334155) : AppTheme.surfaceBg),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : AppTheme.orangePrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPrimary
                          ? AppTheme.orangePrimary
                          : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
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
}
