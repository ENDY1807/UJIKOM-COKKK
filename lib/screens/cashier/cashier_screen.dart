import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/qris_payment_dialog.dart';

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
  String _selectedPaymentMethod = 'Tunai';
  String _searchQuery = '';

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
      _bayarController.text = '${order.grandTotalSetelahDiskon}';
    });
  }

  int get _parsedBayar {
    final text = _bayarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(text) ?? 0;
  }

  int get _kembalian {
    if (_selectedOrder == null) return 0;
    final diff = _parsedBayar - _selectedOrder!.grandTotalSetelahDiskon;
    return diff > 0 ? diff : 0;
  }

  bool get _isPaymentValid {
    if (_selectedOrder == null) return false;
    if (_selectedPaymentMethod != 'Tunai') return true;
    return _parsedBayar >= _selectedOrder!.grandTotalSetelahDiskon;
  }

  void _quickCash(int amount) {
    setState(() {
      _bayarController.text = '$amount';
    });
  }

  void _processPayment() {
    if (_selectedOrder == null) return;

    if (_selectedPaymentMethod == 'QRIS') {
      QrisPaymentDialog.show(
        context,
        order: _selectedOrder!,
        totalAmount: _selectedOrder!.grandTotalSetelahDiskon,
        db: widget.db,
        onPaymentSuccess: () {
          setState(() {
            _selectedOrder = null;
            _bayarController.clear();
          });
        },
      );
      return;
    }

    final tenderAmount = _selectedPaymentMethod == 'Tunai'
        ? _parsedBayar
        : _selectedOrder!.grandTotalSetelahDiskon;

    final transaction = widget.db.processTransaction(
      order: _selectedOrder!,
      jumlahBayar: tenderAmount,
      metodePembayaran: _selectedPaymentMethod,
    );

    setState(() {
      _selectedOrder = null;
      _bayarController.clear();
    });

    // Buka dialog struk transaksi resmi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = widget.db.orders
        .where((o) => o.status != OrderStatus.selesai && o.status != OrderStatus.dibatalkan)
        .toList();

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 820;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kolom Kiri: Antrean Pesanan Meja Belum Bayar
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
  }

  // ── DAFTAR ANTREAN PESANAN MEJA ──
  Widget _buildOrderList(List<OrderModel> activeOrders) {
    var filtered = activeOrders;
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
          // Search box
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
          const SizedBox(height: 12),
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
                          : 'Semua tagihan pesanan telah selesai dibayar',
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

                  return InkWell(
                    onTap: () => _selectOrder(order),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
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
                              StatusBadge.fromStatus(order.status.label),
                            ],
                          ),
                          const SizedBox(height: 6),
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
        ],
      ),
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

    return Container(
      color: context.surfaceCard,
      padding: const EdgeInsets.all(20),
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
                      Text(
                        'Pembayaran ${order.noMeja}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
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
                  if (order.diskonEvent > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Diskon Event Promo:',
                            style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('- ${_currencyFormat.format(order.diskonEvent)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ],
                  if (order.diskonKupon > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Diskon Kupon:',
                            style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('- ${_currencyFormat.format(order.diskonKupon)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
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

            // Metode Pembayaran
            Text('Pilih Metode Pembayaran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: ['Tunai', 'QRIS', 'Debit', 'Transfer'].map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return ChoiceChip(
                  label: Text(method),
                  selected: isSelected,
                  selectedColor: AppTheme.orangePrimary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : context.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _selectedPaymentMethod = method),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Input Uang Diterima & Tombol Pecahan Cepat (Untuk Tunai)
            if (_selectedPaymentMethod == 'Tunai') ...[
              TextField(
                controller: _bayarController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Jumlah Uang Diterima',
                  hintText: 'Masukkan nominal pembayaran',
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Uang Pas'),
                    onPressed: () => _quickCash(order.grandTotalSetelahDiskon),
                  ),
                  ActionChip(
                    label: const Text('Rp 50.000'),
                    onPressed: () => _quickCash(50000),
                  ),
                  ActionChip(
                    label: const Text('Rp 100.000'),
                    onPressed: () => _quickCash(100000),
                  ),
                  ActionChip(
                    label: const Text('Rp 200.000'),
                    onPressed: () => _quickCash(200000),
                  ),
                  ActionChip(
                    label: const Text('Rp 500.000'),
                    onPressed: () => _quickCash(500000),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Kotak Kembalian
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isPaymentValid ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isPaymentValid ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPaymentValid ? 'Uang Kembalian:' : 'Uang Kurang:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isPaymentValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                    Text(
                      _isPaymentValid
                          ? _currencyFormat.format(_kembalian)
                          : _currencyFormat.format(order.grandTotalSetelahDiskon - _parsedBayar),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: _isPaymentValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Tombol Utama Bayar & Cetak Struk
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isPaymentValid ? _processPayment : null,
                icon: const Icon(Icons.receipt_rounded, size: 20, color: Colors.white),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _selectedPaymentMethod == 'QRIS'
                        ? 'Tampilkan Barcode QRIS & Verifikasi'
                        : 'Bayar & Cetak Struk Resmi',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orangePrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tombol Void / Batalkan Pesanan Meja
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Batalkan Pesanan Meja (Void)'),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: context.surfaceCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Konfirmasi Pembatalan (Void)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    content: Text('Yakin ingin membatalkan pesanan #${order.idOrder} untuk ${order.noMeja}? Meja akan dikosongkan.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                        onPressed: () {
                          widget.db.deleteOrder(order.idOrder);
                          widget.db.updateTableStatus(order.noMeja, TableStatus.kosong);
                          Navigator.pop(ctx);
                          setState(() => _selectedOrder = null);
                        },
                        child: const Text('Ya, Batalkan Meja', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
