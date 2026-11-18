import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
import '../../services/export_report_service.dart';
import '../../services/order_simulation_service.dart';
import '../../services/payment_gateway_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/status_badge.dart';
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
  String _paymentMethod = 'Tunai'; // 'Tunai' atau 'QRIS' (ditentukan kasir saat transaksi)
  final _bayarController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Semua, 1: Menunggu Bayar, 2: Sedang Dimasak

  // Midtrans QRIS State
  String? _midtransQrString;
  bool _isLoadingMidtransQris = false;
  int? _loadedMidtransOrderId;

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
      _paymentMethod = 'Tunai';
      _bayarController.clear();
      _midtransQrString = null;
      _loadedMidtransOrderId = null;
    });
  }

  Future<void> _fetchMidtransQris(OrderModel order) async {
    if (_loadedMidtransOrderId == order.idOrder && _midtransQrString != null) {
      return;
    }
    setState(() {
      _isLoadingMidtransQris = true;
      _loadedMidtransOrderId = order.idOrder;
    });

    try {
      final res = await PaymentGatewayService.generateQris(
        orderId: 'RSN-${order.idOrder}-${DateTime.now().millisecondsSinceEpoch % 100000}',
        amount: order.grandTotalSetelahDiskon,
      );
      if (mounted && _selectedOrder?.idOrder == order.idOrder) {
        setState(() {
          _midtransQrString = res.qrString;
          _isLoadingMidtransQris = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMidtransQris = false;
        });
      }
    }
  }

  int get _parsedBayar {
    final text = _bayarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(text) ?? 0;
  }

  bool get _isPaymentValid {
    if (_selectedOrder == null) return false;
    if (_paymentMethod == 'QRIS') {
      return true;
    }
    return _parsedBayar >= _selectedOrder!.grandTotalSetelahDiskon && _parsedBayar > 0;
  }

  void _showTransferTableCashierDialog(OrderModel order) {
    final availableTables = widget.db.tables
        .where((t) => t.nomorMeja.toLowerCase() != order.noMeja.toLowerCase())
        .toList();

    final emptyList = availableTables.where((t) => t.status == TableStatus.kosong);
    String? selectedTarget = emptyList.isNotEmpty
        ? emptyList.first.nomorMeja
        : (availableTables.isNotEmpty ? availableTables.first.nomorMeja : null);

    if (selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada meja lain yang tersedia untuk dipindahkan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: context.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Pindah ${order.noMeja} (Order #${order.idOrder})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih meja tujuan baru untuk memindahkan seluruh pesanan tamu "${order.namaPelanggan}":',
                style: TextStyle(fontSize: 12.5, color: context.textSecondary),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedTarget,
                decoration: InputDecoration(
                  labelText: 'Meja Tujuan Baru',
                  prefixIcon: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0284C7)),
                  filled: true,
                  fillColor: context.surfaceBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: availableTables.map((t) {
                  final isKosong = t.status == TableStatus.kosong;
                  return DropdownMenuItem(
                    value: t.nomorMeja,
                    child: Text(
                      '${t.nomorMeja} (${t.status.label})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isKosong ? FontWeight.bold : FontWeight.normal,
                        color: isKosong ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDlgState(() => selectedTarget = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Pindahkan Meja'),
              onPressed: () {
                if (selectedTarget != null) {
                  final target = selectedTarget!;
                  widget.db.transferOrderTable(
                    idOrder: order.idOrder,
                    newTableNo: target,
                  );
                  Navigator.pop(ctx);
                  final updatedOrders = widget.db.orders.where((o) => o.idOrder == order.idOrder);
                  setState(() {
                    _selectedOrder = updatedOrders.isNotEmpty ? updatedOrders.first : null;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pesanan berhasil dipindahkan dari ${order.noMeja} ke $target!'),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _processPayment({String? forceMethod}) {
    if (_selectedOrder == null) return;
    final order = _selectedOrder!;
    final method = forceMethod ?? _paymentMethod;
    final isQris = method == 'QRIS';

    final tenderAmount = isQris ? order.grandTotalSetelahDiskon : _parsedBayar;

    // 1. Simpan Transaksi Pembayaran Kasir
    final transaction = widget.db.processTransaction(
      order: order,
      jumlahBayar: tenderAmount,
      metodePembayaran: method,
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
                return PopScope(
                  canPop: _selectedOrder == null,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    if (_selectedOrder != null) {
                      setState(() => _selectedOrder = null);
                    }
                  },
                  child: _selectedOrder == null
                      ? _buildOrderList(activeOrders)
                      : _buildPaymentPanel(),
                );
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
                icon: const Icon(Icons.history_rounded, size: 15),
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
              const SizedBox(width: 10),
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
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Kembali ke Antrean',
                  onPressed: () => setState(() => _selectedOrder = null),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Pembayaran ${order.noMeja}',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
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

            // Rincian Item Menu & Aksi Pindah Meja
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rincian Hidangan Meja:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Pindah Meja', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showTransferTableCashierDialog(order),
                ),
              ],
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
            Text('Pilihan Pembayaran di Meja Kasir:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
            const SizedBox(height: 8),

            // Tab Pilihan Metode Pembayaran: Tunai vs QRIS (Dipilih oleh Kasir)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'Tunai'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'Tunai'
                            ? const Color(0xFF16A34A)
                            : context.fillSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentMethod == 'Tunai'
                              ? const Color(0xFF15803D)
                              : context.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 18,
                            color: _paymentMethod == 'Tunai' ? Colors.white : context.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TUNAI',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _paymentMethod == 'Tunai' ? Colors.white : context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _paymentMethod = 'QRIS');
                      _fetchMidtransQris(order);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'QRIS'
                            ? const Color(0xFFEA580C)
                            : context.fillSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentMethod == 'QRIS'
                              ? const Color(0xFFC2410C)
                              : context.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 18,
                            color: _paymentMethod == 'QRIS' ? Colors.white : context.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'QRIS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _paymentMethod == 'QRIS' ? Colors.white : context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── JIKA PESANAN SUDAH LUNAS ──
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
                            'Pembayaran Lunas • Meja Siap Kosong',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pesanan ini telah lunas dan siap diselesaikan untuk mengosongkan meja tamu.',
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
                      label: const Text('Selesaikan & Kosongkan Meja'),
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
              if (_paymentMethod == 'QRIS') ...[
                Builder(
                  builder: (context) {
                    if (_loadedMidtransOrderId != order.idOrder && !_isLoadingMidtransQris) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _selectedOrder?.idOrder == order.idOrder) {
                          _fetchMidtransQris(order);
                        }
                      });
                    }

                    final fallbackPayload = PaymentGatewayService.generateAspiEmvCoQris(
                      orderId: 'ORDER-${order.idOrder}',
                      amount: order.grandTotalSetelahDiskon,
                      merchantName: PaymentGatewayConfig.defaultMerchantName,
                      city: PaymentGatewayConfig.defaultCity,
                      postalCode: PaymentGatewayConfig.defaultPostalCode,
                      nmid: PaymentGatewayConfig.defaultNmid,
                    );
                    final qrisPayload = _midtransQrString ?? fallbackPayload;

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: context.surfaceCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.borderSubtle),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'RASANTARA RESTORAN • ${order.noMeja}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // QR Code Otomatis Ditampilkan dari Midtrans
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: _isLoadingMidtransQris && _midtransQrString == null
                                ? const SizedBox(
                                    width: 190,
                                    height: 190,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 32,
                                            height: 32,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
                                            ),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Memuat QRIS Midtrans...',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : QrImageView(
                                    data: qrisPayload,
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
                          const SizedBox(height: 12),

                          // Nominal Pembayaran
                          Text(
                            _currencyFormat.format(order.grandTotalSetelahDiskon),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan menggunakan DANA, BCA, GoPay, OVO, ShopeePay, atau m-Banking',
                            style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.verified_user_outlined, size: 14, color: context.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'BCA • Mandiri • BRI • BNI • GoPay • OVO • DANA • ShopeePay',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Tombol Konfirmasi Transaksi QRIS
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _processPayment(forceMethod: 'QRIS'),
                    icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                    label: const Text(
                      'Konfirmasi transaksi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // ── JIKA METODE PEMBAYARAN: TUNAI (CASH) ──
              if (_paymentMethod == 'Tunai') ...[
                Text(
                  'Nominal Uang Diterima:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _bayarController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    ThousandsSeparatorInputFormatter(),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Masukan Nominal Uang',
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF16A34A)),
                    prefixText: _bayarController.text.isNotEmpty ? 'Rp ' : null,
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

                // Kotak Perhitungan Kembalian
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
                                'Masukkan nominal uang tunai yang diserahkan pelanggan.',
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

                // Tombol Selesaikan Pembayaran Tunai
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isPaymentValid ? () => _processPayment(forceMethod: 'Tunai') : null,
                    icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _parsedBayar <= 0
                            ? 'Masukkan Uang Pembayaran'
                            : (_isPaymentValid
                                ? 'Konfirmasi transaksi'
                                : 'Uang Pembayaran Masih Kurang'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPaymentValid ? const Color(0xFF16A34A) : AppTheme.textMuted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
