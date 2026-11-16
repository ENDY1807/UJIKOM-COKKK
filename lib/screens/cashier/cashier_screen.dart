import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
import '../../services/export_report_service.dart';
import '../../services/order_simulation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/qris_payment_dialog.dart';
import 'cashier_order_history_screen.dart';

/// Formatter otomatis ribuan Indonesia (contoh: 1000 -> 1.000, 1000000 -> 1.000.000, 233500 -> 233.500)
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue();
    }
    final int? value = int.tryParse(cleanText);
    if (value == null) {
      return oldValue;
    }
    final formatted = _formatter.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CashierScreen extends StatefulWidget {
  final DatabaseService db;

  const CashierScreen({super.key, required this.db});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  OrderModel? _selectedOrder;
  final _bayarController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Semua, 1: Menunggu Bayar, 2: Sedang Dimasak
  bool _isPrintingQris = false;

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void dispose() {
    _bayarController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectOrder(OrderModel order) {
    setState(() {
      _selectedOrder = order;
      _bayarController.clear();
    });
  }

  int get _parsedBayar {
    final text = _bayarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(text) ?? 0;
  }

  bool get _isPaymentValid {
    if (_selectedOrder == null) return false;
    final isQris = _selectedOrder!.metodePembayaran?.toUpperCase() == 'QRIS';
    if (isQris) {
      return _selectedOrder!.isPaid;
    }
    return _parsedBayar >= _selectedOrder!.grandTotalSetelahDiskon && _parsedBayar > 0;
  }

  void _printQris(OrderModel order) async {
    setState(() => _isPrintingQris = true);
    try {
      await ExportReportService.printQrisBill(order: order);
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) setState(() => _isPrintingQris = false);
    }
  }

  void _showQrisModal(OrderModel order) {
    QrisPaymentDialog.show(
      context,
      order: order,
      totalAmount: order.grandTotalSetelahDiskon,
      db: widget.db,
      onPaymentSuccess: () {
        setState(() {
          _selectedOrder = null;
          _bayarController.clear();
        });
      },
    );
  }

  void _toggleQrisPayment(OrderModel order) {
    final newStatus = !order.isPaid;
    widget.db.updateOrderPaymentStatus(order.idOrder, newStatus);
    setState(() {
      _selectedOrder = widget.db.orders.firstWhere((o) => o.idOrder == order.idOrder, orElse: () => order);
    });
  }

  void _processPayment() {
    if (_selectedOrder == null) return;
    final order = _selectedOrder!;
    final isQris = order.metodePembayaran?.toUpperCase() == 'QRIS';

    final tenderAmount = isQris ? order.grandTotalSetelahDiskon : _parsedBayar;

    // 1. Simpan Transaksi Pembayaran Kasir
    final transaction = widget.db.processTransaction(
      order: order,
      jumlahBayar: tenderAmount,
      metodePembayaran: isQris ? 'QRIS' : 'Tunai',
    );

    // 2. Pesanan otomatis lunas & selesai, langsung masuk ke riwayat pesanan dan meja kembali kosong
    widget.db.updateOrderStatus(order.idOrder, OrderStatus.selesai);
    widget.db.updateOrderPaymentStatus(order.idOrder, true);
    widget.db.updateTableStatus(order.noMeja, TableStatus.kosong);

    // 3. Masukkan ke simulasi alur dapur koki
    OrderSimulationService().getOrCreateProgress(order);

    setState(() {
      _selectedOrder = null;
      _bayarController.clear();
    });

    // 4. Langsung print struk dengan ukuran kertas termal
    ExportReportService.printReceiptPdf(
      transaction: transaction,
      restaurantName: 'Rasantara Restoran',
      address: 'Jl. Soekarno-Hatta No. 590, Sekejati, Buahbatu, Bandung',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(
        transaction: transaction,
        allowPrint: true,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pembayaran lunas! Transaksi tersimpan dan pesanan ${order.noMeja} langsung masuk ke Riwayat Pesanan.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.db,
      builder: (context, _) {
        final activeOrders = widget.db.orders
            .where((o) => o.status != OrderStatus.selesai && o.status != OrderStatus.dibatalkan)
            .toList();

        // Sync selected order state from db if currently selected
        if (_selectedOrder != null) {
          final updated = activeOrders.where((o) => o.idOrder == _selectedOrder!.idOrder).firstOrNull;
          if (updated != null && updated != _selectedOrder) {
            _selectedOrder = updated;
          }
        }

        return Scaffold(
          backgroundColor: context.surfaceBg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 840;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kolom Kiri: Antrean Pesanan Meja
                    Expanded(
                      flex: 5,
                      child: _buildOrderList(activeOrders),
                    ),
                    const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
                    // Kolom Kanan: Terminal Pembayaran Kasir
                    Expanded(
                      flex: 6,
                      child: _buildPaymentPanel(),
                    ),
                  ],
                );
              } else {
                return _selectedOrder == null
                    ? _buildOrderList(activeOrders)
                    : _buildPaymentPanel();
              }
            },
          ),
        );
      },
    );
  }

  // ── DAFTAR ANTREAN PESANAN MEJA ──
  Widget _buildOrderList(List<OrderModel> activeOrders) {
    final unpaidOrders = activeOrders.where((o) => !o.isPaid || o.status == OrderStatus.menunggu).toList();
    final cookingOrders = activeOrders.where((o) => o.isPaid || o.status == OrderStatus.diproses).toList();

    var filtered = activeOrders;
    if (_selectedFilterIndex == 1) {
      filtered = unpaidOrders;
    } else if (_selectedFilterIndex == 2) {
      filtered = cookingOrders;
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((o) =>
              o.noMeja.toLowerCase().contains(_searchQuery) ||
              o.namaPelanggan.toLowerCase().contains(_searchQuery) ||
              '${o.idOrder}'.contains(_searchQuery))
          .toList();
    }

    return Container(
      color: context.surfaceBg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.point_of_sale, size: 20, color: AppTheme.orangePrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Antrean Kasir & Meja',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Tombol Shortcut Riwayat Pesanan
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.orangePrimary,
                  side: const BorderSide(color: AppTheme.orangeBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: const Text('Riwayat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CashierOrderHistoryScreen(db: widget.db),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.orangeLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.orangeBorder),
                ),
                child: Text(
                  '${activeOrders.length} Tagihan Aktif',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Box
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: context.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderSubtle),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: TextStyle(fontSize: 13, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cari Meja atau Nama Tamu...',
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

          // Filter Tab Pilihan: Semua, Menunggu Bayar, Sedang Dimasak
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(0, 'Semua (${activeOrders.length})'),
                const SizedBox(width: 6),
                _buildFilterChip(1, 'Menunggu Bayar (${unpaidOrders.length})', isHighlight: unpaidOrders.isNotEmpty),
                const SizedBox(width: 6),
                _buildFilterChip(2, 'Sedang Dimasak (${cookingOrders.length})'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // List Items
          if (filtered.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: AppTheme.statusGreen.withValues(alpha: 0.7)),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Tidak ada pesanan cocok dengan pencarian'
                          : 'Tidak ada antrean pesanan pada filter ini',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = filtered[index];
                  final isSelected = _selectedOrder?.idOrder == order.idOrder;
                  final isQris = order.metodePembayaran?.toUpperCase() == 'QRIS';

                  return InkWell(
                    onTap: () => _selectOrder(order),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.orangeLight : context.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.orangePrimary : context.borderSubtle,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Meja & Tag Status
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
                                  // Badge Metode Pembayaran
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: isQris ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: isQris ? const Color(0xFFFFEDD5) : const Color(0xFFBBF7D0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isQris ? Icons.qr_code_2_rounded : Icons.payments_outlined,
                                          size: 12,
                                          color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          isQris ? 'QRIS' : 'TUNAI',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusBadge.fromStatus(order.status.label),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Tamu & Waktu
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
                                DateFormat('HH:mm').format(order.tanggal),
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Item count & Total
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${order.totalItem} item hidangan',
                                style: TextStyle(fontSize: 12, color: context.textSecondary),
                              ),
                              Text(
                                _currencyFormat.format(order.grandTotalSetelahDiskon),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.orangePrimary,
                                ),
                              ),
                            ],
                          ),

                          // Indikator QRIS Lunas / Belum
                          if (isQris) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: order.isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    order.isPaid ? Icons.check_circle : Icons.schedule,
                                    size: 12,
                                    color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.isPaid ? 'QRIS Sudah Dibayar (Lunas)' : 'QRIS Belum Dibayar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, {bool isHighlight = false}) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: isHighlight ? const Color(0xFFEA580C) : AppTheme.orangePrimary,
      backgroundColor: isHighlight ? const Color(0xFFFFF7ED) : null,
      side: isHighlight && !isSelected ? const BorderSide(color: Color(0xFFFFEDD5)) : null,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected || isHighlight ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : isHighlight
                ? const Color(0xFFC2410C)
                : context.textPrimary,
      ),
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
    );
  }

  // ── TERMINAL PEMBAYARAN KASIR ──
  Widget _buildPaymentPanel() {
    if (_selectedOrder == null) {
      return Container(
        color: context.surfaceCard,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.point_of_sale_rounded, size: 54, color: AppTheme.textMuted),
              SizedBox(height: 14),
              Text(
                'Pilih meja dari antrean kasir untuk memproses pembayaran',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final order = _selectedOrder!;
    final isQris = order.metodePembayaran?.toUpperCase() == 'QRIS';
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: context.surfaceCard,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Meja & Tombol Tutup
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pembayaran ${order.noMeja}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge.fromStatus(order.status.label),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #${order.idOrder} • Tamu: ${order.namaPelanggan}',
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                  onPressed: () => setState(() => _selectedOrder = null),
                ),
              ],
            ),
            Divider(height: 22, color: context.borderSubtle),

            // Rincian Item Menu
            Text(
              'Rincian Hidangan Meja:',
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
                          _currencyFormat.format(item.subtotal),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Kotak Rincian Tagihan & Total Bersih
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.isDarkMode ? const Color(0xFF7C2D12).withValues(alpha: 0.25) : AppTheme.orangeLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.isDarkMode ? const Color(0xFF7C2D12) : AppTheme.orangeBorder),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Subtotal Menu (${order.totalItem} item):',
                          style: TextStyle(fontSize: 13, color: context.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_currencyFormat.format(order.totalHarga), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                    ],
                  ),
                  if (order.diskonMember > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Diskon Langganan (VIP 10%):',
                            style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('- ${_currencyFormat.format(order.diskonMember)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'TOTAL TAGIHAN:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currencyFormat.format(order.grandTotalSetelahDiskon),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.orangePrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── METODE PEMBAYARAN: SESUAI YANG DIKIRIM WAITER & TIDAK DAPAT DIUBAH ──
            Text('Metode Pembayaran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isQris ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isQris ? const Color(0xFFFFEDD5) : const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isQris ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isQris ? Icons.qr_code_2_rounded : Icons.payments_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isQris ? 'QRIS (Nirsentuh)' : 'TUNAI (Cash)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isQris ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.lock_outline, size: 14, color: AppTheme.textMuted),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ditetapkan oleh pelayan/waiter saat pemesanan meja (Terkunci & Tidak dapat diubah).',
                          style: TextStyle(fontSize: 11, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── JIKA PESANAN SUDAH LUNAS & SEDANG DIMASAK ──
            if (order.isPaid) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pembayaran Lunas • Sedang Dimasak',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pesanan otomatis diterima dan diteruskan ke dapur koki untuk proses memasak.',
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: context.borderSubtle),
                      ),
                      icon: const Icon(Icons.receipt_outlined, size: 18),
                      label: const Text('Cetak Ulang Struk'),
                      onPressed: () {
                        final trx = widget.db.transactions.where((t) => t.order.idOrder == order.idOrder).firstOrNull;
                        if (trx != null) {
                          showDialog(
                            context: context,
                            builder: (_) => ReceiptDialog(transaction: trx, allowPrint: true),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.table_restaurant_rounded, size: 18),
                      label: const Text('Selesaikan Meja'),
                      onPressed: () {
                        widget.db.updateOrderStatus(order.idOrder, OrderStatus.selesai);
                        widget.db.updateTableStatus(order.noMeja, TableStatus.kosong);
                        setState(() => _selectedOrder = null);
                      },
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ── JIKA METODE PEMBAYARAN: QRIS ──
              if (isQris) ...[
                // Kotak Status Pembayaran QRIS: Sudah Bayar atau Belum
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: order.isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: order.isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                order.isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                                color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                order.isPaid ? 'STATUS: SUDAH DIBAYAR (LUNAS)' : 'STATUS: BELUM DIBAYAR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: order.isPaid ? const Color(0xFF15803D) : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: order.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              order.isPaid ? 'Lunas' : 'Menunggu',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.isPaid
                            ? 'Pembayaran QRIS telah diverifikasi lunas. Kasir dapat langsung menekan tombol di bawah untuk menyelesaikan transaksi dan mencetak struk resmi.'
                            : 'Pelanggan belum membayar via QRIS. Berikan QRIS ke meja tamu atau periksa status pembayaran jika pelanggan sudah melakukan transfer.',
                        style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol-tombol Khusus QRIS: Cetak QRIS, Tampilkan QRIS, Cek/Konfirmasi Status
                Row(
                  children: [
                    // Tombol Cetak QRIS
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isPrintingQris
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.print_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Cetak Lembar QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                        onPressed: _isPrintingQris ? null : () => _printQris(order),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tombol Tampilkan QRIS di Layar
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          side: const BorderSide(color: Color(0xFFEA580C)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Buka QRIS Layar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                        onPressed: () => _showQrisModal(order),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tombol Konfirmasi / Cek Pembayaran
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: order.isPaid ? const Color(0xFF475569) : const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(order.isPaid ? Icons.undo_rounded : Icons.verified_rounded, size: 18),
                    label: Text(
                      order.isPaid ? 'Ubah Status ke Belum Bayar' : 'Konfirmasi / Tandai Sudah Bayar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () => _toggleQrisPayment(order),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ── JIKA METODE PEMBAYARAN: TUNAI ──
              if (!isQris) ...[
                Text('Nominal Uang Diterima:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
                const SizedBox(height: 8),

                // Input Nominal Uang Tunai dengan format ribuan otomatis
                TextField(
                  controller: _bayarController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    ThousandsSeparatorInputFormatter(),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Jumlah Uang Diterima dari Pelanggan',
                    hintText: 'Contoh: 100.000',
                    prefixText: 'Rp ',
                    prefixIcon: const Icon(Icons.payments_outlined, color: AppTheme.orangePrimary),
                    suffixIcon: _bayarController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _bayarController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Kotak Perhitungan: Uang Kembalian atau Uang Kurang
                Builder(
                  builder: (context) {
                    final total = order.grandTotalSetelahDiskon;
                    final bayar = _parsedBayar;

                    if (bayar <= 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.surfaceBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Masukkan nominal uang yang diberikan oleh pelanggan.',
                                style: TextStyle(fontSize: 12, color: context.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final isCukup = bayar >= total;
                    final diff = isCukup ? (bayar - total) : (total - bayar);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isCukup ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCukup ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCukup ? Icons.check_circle_outline : Icons.error_outline,
                                size: 18,
                                color: isCukup ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isCukup ? 'Uang Kembalian:' : 'Uang Kurang:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCukup ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _currencyFormat.format(diff),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: isCukup ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],

              // ── TOMBOL UTAMA: BAYAR & PROSES MEMASAK ──
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isPaymentValid ? _processPayment : null,
                  icon: const Icon(Icons.restaurant_rounded, size: 20, color: Colors.white),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isQris
                          ? (order.isPaid ? 'Selesaikan Transaksi & Cetak Struk' : 'Menunggu Pembayaran QRIS (Belum Lunas)')
                          : (_parsedBayar <= 0
                              ? 'Masukkan Uang Pembayaran'
                              : (_isPaymentValid ? 'Bayar & Selesaikan Transaksi' : 'Uang Pembayaran Masih Kurang')),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPaymentValid ? AppTheme.orangePrimary : AppTheme.textMuted,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
