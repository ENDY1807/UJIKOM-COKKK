import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/export_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/status_badge.dart';

class CashierOrderHistoryScreen extends StatefulWidget {
  final DatabaseService db;

  const CashierOrderHistoryScreen({super.key, required this.db});

  @override
  State<CashierOrderHistoryScreen> createState() => _CashierOrderHistoryScreenState();
}

class _CashierOrderHistoryScreenState extends State<CashierOrderHistoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'semua'; // 'semua', 'selesai', 'aktif', 'dibatalkan'
  DateTime? _selectedDate;
  DateTimeRange? _selectedDateRange;

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');
  final _dayFmt = DateFormat('dd MMMM yyyy', 'id_ID');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
      _selectedDateRange = null;
    });
  }

  void _selectToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedDateRange = null;
    });
  }

  void _selectYesterday() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    setState(() {
      _selectedDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      _selectedDateRange = null;
    });
  }

  void _selectLast7Days() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = null;
      _selectedDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    });
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal Riwayat Pesanan',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _selectedDateRange = null;
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isWithinRange(DateTime date, DateTimeRange range) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  void _deleteOrderConfirm(OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Hapus Pesanan dari Riwayat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Apakah Anda yakin ingin menghapus data pesanan #${order.idOrder} (${order.noMeja} - ${order.namaPelanggan})?\n\nTindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              widget.db.deleteOrder(order.idOrder);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Pesanan #${order.idOrder} berhasil dihapus dari riwayat.'),
                  backgroundColor: const Color(0xFFDC2626),
                ),
              );
            },
            child: const Text('Ya, Hapus Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailSheet(OrderModel order) {
    final transaction = widget.db.transactions.where((t) => t.order.idOrder == order.idOrder).firstOrNull;
    final isQris = order.metodePembayaran?.toUpperCase() == 'QRIS';
    final canPrint = widget.db.currentUser?.role.canProcessTransactions ?? false;
    final isAdmin = widget.db.currentUser?.role == UserRole.administrator;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                order.noMeja,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge.fromStatus(order.status.label),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Order #${order.idOrder} • ${order.namaPelanggan}',
                            style: TextStyle(fontSize: 13, color: context.textSecondary),
                          ),
                          Text(
                            _dateFmt.format(order.tanggal),
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Body scrollable
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Info Metode Pembayaran
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isQris ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isQris ? const Color(0xFFFFEDD5) : const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isQris ? Icons.qr_code_2_rounded : Icons.payments_rounded,
                            color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Metode Pembayaran: ${isQris ? "QRIS (Nirsentuh)" : "TUNAI (Cash)"}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isQris ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                                  ),
                                ),
                                if (transaction != null)
                                  Text(
                                    'Kasir Pemroses: ${transaction.namaKasir}',
                                    style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rincian Hidangan
                    Text(
                      'Rincian Menu Hidangan:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderSubtle),
                      ),
                      child: Column(
                        children: order.items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.jumlah}x ${item.menu.namaMasakan}',
                                        style: TextStyle(fontSize: 13, color: context.textPrimary, fontWeight: FontWeight.w500),
                                      ),
                                      if (item.catatan.isNotEmpty)
                                        Text(
                                          'Catatan: ${item.catatan}',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _currencyFmt.format(item.subtotal),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ringkasan Pembayaran
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.orangeBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Subtotal Menu (${order.totalItem} item):', style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
                              Text(_currencyFmt.format(order.totalHarga), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textPrimary)),
                            ],
                          ),
                          if (order.totalDiskon > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Potongan Diskon:', style: TextStyle(fontSize: 12.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                Text('- ${_currencyFmt.format(order.totalDiskon)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOTAL TAGIHAN:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary)),
                              Text(
                                _currencyFmt.format(order.grandTotalSetelahDiskon),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.orangePrimary),
                              ),
                            ],
                          ),
                          if (transaction != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Jumlah Dibayar:', style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
                                Text(_currencyFmt.format(transaction.jumlahBayar), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary)),
                              ],
                            ),
                            if (transaction.kembalian > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Uang Kembalian:', style: TextStyle(fontSize: 12.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                                  Text(_currencyFmt.format(transaction.kembalian), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Aksi Sesuai Hak Akses Role
                    if (transaction != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.orangePrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(canPrint ? Icons.receipt_long_rounded : Icons.visibility_outlined, color: Colors.white, size: 20),
                          label: Text(
                            canPrint ? 'Cetak Ulang Struk Resmi' : 'Lihat Pratinjau Struk',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (canPrint) {
                              // Langsung print struk dengan ukuran kertas termal tanpa konfirmasi
                              ExportReportService.printReceiptPdf(
                                transaction: transaction,
                                restaurantName: 'Rasantara Restoran',
                                address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Bandung',
                              );
                            }
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => ReceiptDialog(
                                transaction: transaction,
                                allowPrint: canPrint,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (isQris && canPrint) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: const Text('Cetak Lembar Tagihan QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            ExportReportService.printQrisBill(order: order);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Tombol Hapus Pesanan: Khusus Administrator
                    if (isAdmin) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFDC2626)),
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('Hapus Pesanan Ini dari Riwayat'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _deleteOrderConfirm(order);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.db,
      builder: (context, _) {
        final allOrders = widget.db.orders;

        // Filter status
        var filtered = allOrders.where((o) {
          if (_statusFilter == 'selesai') return o.status == OrderStatus.selesai || o.isPaid;
          if (_statusFilter == 'aktif') {
            return (o.status == OrderStatus.menunggu || o.status == OrderStatus.diproses) && !o.isPaid;
          }
          if (_statusFilter == 'dibatalkan') return o.status == OrderStatus.dibatalkan;
          return true;
        }).toList();

        // Filter tanggal
        if (_selectedDate != null) {
          filtered = filtered.where((o) => _isSameDay(o.tanggal, _selectedDate!)).toList();
        } else if (_selectedDateRange != null) {
          filtered = filtered.where((o) => _isWithinRange(o.tanggal, _selectedDateRange!)).toList();
        }

        // Filter search query
        if (_searchQuery.isNotEmpty) {
          filtered = filtered.where((o) {
            return o.noMeja.toLowerCase().contains(_searchQuery) ||
                o.namaPelanggan.toLowerCase().contains(_searchQuery) ||
                '${o.idOrder}'.contains(_searchQuery) ||
                (o.metodePembayaran?.toLowerCase().contains(_searchQuery) ?? false);
          }).toList();
        }

        return Scaffold(
          backgroundColor: context.surfaceBg,
          appBar: Navigator.canPop(context)
              ? AppBar(
                  elevation: 0,
                  backgroundColor: context.surfaceCard,
                  foregroundColor: context.textPrimary,
                  title: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 22, color: AppTheme.orangePrimary),
                      const SizedBox(width: 8),
                      Text(
                        'Riwayat Pesanan Restoran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: context.textPrimary),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.date_range_rounded),
                      tooltip: 'Pilih Tanggal',
                      onPressed: _pickCustomDate,
                    ),
                  ],
                )
              : null,
          body: Column(
            children: [
              // ── BAGIAN SEARCH & FILTER TANGGAL ──
              Container(
                color: context.surfaceCard,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    if (!Navigator.canPop(context))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.orangeLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.history_rounded, size: 18, color: AppTheme.orangePrimary),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Riwayat Pesanan',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.textPrimary),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.date_range_rounded, color: AppTheme.orangePrimary, size: 20),
                              tooltip: 'Pilih Tanggal',
                              onPressed: _pickCustomDate,
                            ),
                          ],
                        ),
                      ),
                    // Search Bar
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderSubtle),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        style: TextStyle(fontSize: 13, color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Cari Meja, Pelanggan, atau No. Order...',
                          hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Date Chips & Custom Date Picker
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildDateFilterChip(
                            label: 'Semua Tanggal',
                            isSelected: _selectedDate == null && _selectedDateRange == null,
                            onTap: _clearDateFilter,
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'Hari Ini',
                            isSelected: _selectedDate != null && _isSameDay(_selectedDate!, DateTime.now()),
                            onTap: _selectToday,
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: 'Kemarin',
                            isSelected: _selectedDate != null &&
                                _isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1))),
                            onTap: _selectYesterday,
                          ),
                          const SizedBox(width: 6),
                          _buildDateFilterChip(
                            label: '7 Hari Terakhir',
                            isSelected: _selectedDateRange != null,
                            onTap: _selectLast7Days,
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _pickCustomDate,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (_selectedDate != null &&
                                        !_isSameDay(_selectedDate!, DateTime.now()) &&
                                        !_isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1))))
                                    ? AppTheme.orangePrimary
                                    : context.surfaceBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: context.borderSubtle),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_month_outlined,
                                    size: 14,
                                    color: (_selectedDate != null &&
                                            !_isSameDay(_selectedDate!, DateTime.now()) &&
                                            !_isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1))))
                                        ? Colors.white
                                        : context.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedDate != null &&
                                            !_isSameDay(_selectedDate!, DateTime.now()) &&
                                            !_isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1)))
                                        ? _dayFmt.format(_selectedDate!)
                                        : 'Pilih Tanggal...',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: (_selectedDate != null &&
                                              !_isSameDay(_selectedDate!, DateTime.now()) &&
                                              !_isSameDay(_selectedDate!, DateTime.now().subtract(const Duration(days: 1))))
                                          ? Colors.white
                                          : context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Status Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusTab('semua', 'Semua'),
                          const SizedBox(width: 6),
                          _buildStatusTab('selesai', 'Selesai (Lunas)'),
                          const SizedBox(width: 6),
                          _buildStatusTab('aktif', 'Sedang Aktif'),
                          const SizedBox(width: 6),
                          _buildStatusTab('dibatalkan', 'Dibatalkan'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


              // ── LIST RIWAYAT PESANAN ──
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFEA580C),
                  onRefresh: () async {
                    await widget.db.initSupabase();
                    if (mounted) setState(() {});
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_toggle_off_rounded, size: 54, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Tidak ada pesanan cocok dengan kata kunci "$_searchQuery"'
                                        : 'Belum ada riwayat pesanan pada filter tanggal ini',
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, 10, 16, 24 + MediaQuery.of(context).padding.bottom),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final isQris = order.metodePembayaran?.toUpperCase() == 'QRIS';

                          return InkWell(
                            onTap: () => _showOrderDetailSheet(order),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surfaceCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Row 1: Meja, Order ID, Status Badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            order.noMeja,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '#${order.idOrder}',
                                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            margin: const EdgeInsets.only(right: 6),
                                            decoration: BoxDecoration(
                                              color: isQris ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isQris ? const Color(0xFFFFEDD5) : const Color(0xFFBBF7D0)),
                                            ),
                                            child: Text(
                                              isQris ? 'QRIS' : 'TUNAI',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                              ),
                                            ),
                                          ),
                                          StatusBadge.fromStatus(order.status.label),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Row 2: Tamu & Tanggal
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Tamu: ${order.namaPelanggan}',
                                          style: TextStyle(fontSize: 13, color: context.textPrimary, fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _dateFmt.format(order.tanggal),
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Row 3: Items & Total
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${order.totalItem} item hidangan',
                                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                                      ),
                                      Text(
                                        _currencyFmt.format(order.grandTotalSetelahDiskon),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.orangePrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.orangePrimary : context.surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.orangePrimary : context.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab(String key, String label) {
    final isSelected = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0F172A),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : context.textPrimary,
      ),
      onSelected: (_) => setState(() => _statusFilter = key),
    );
  }
}
