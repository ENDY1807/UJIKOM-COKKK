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
  String _selectedPaymentMethod = 'Tunai';

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void dispose() {
    _bayarController.dispose();
    super.dispose();
  }

  void _selectOrder(OrderModel order) {
    setState(() {
      _selectedOrder = order;
      _bayarController.text = '${order.totalHarga}';
    });
  }

  int get _parsedBayar {
    final text = _bayarController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(text) ?? 0;
  }

  int get _kembalian {
    if (_selectedOrder == null) return 0;
    final diff = _parsedBayar - _selectedOrder!.totalHarga;
    return diff > 0 ? diff : 0;
  }

  bool get _isPaymentValid {
    if (_selectedOrder == null) return false;
    return _parsedBayar >= _selectedOrder!.totalHarga;
  }

  void _quickCash(int amount) {
    setState(() {
      _bayarController.text = '$amount';
    });
  }

  void _processPayment() {
    if (_selectedOrder == null || !_isPaymentValid) return;

    if (_selectedPaymentMethod == 'QRIS') {
      QrisPaymentDialog.show(
        context,
        order: _selectedOrder!,
        totalAmount: _selectedOrder!.totalHarga,
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

    final transaction = widget.db.processTransaction(
      order: _selectedOrder!,
      jumlahBayar: _parsedBayar,
      metodePembayaran: _selectedPaymentMethod,
    );

    setState(() {
      _selectedOrder = null;
      _bayarController.clear();
    });

    // Open receipt modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReceiptDialog(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = widget.db.orders.where((o) => o.status != OrderStatus.selesai && o.status != OrderStatus.dibatalkan).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 750;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Active Orders List
                Expanded(
                  flex: 5,
                  child: _buildOrderList(activeOrders),
                ),
                const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
                // Right: Billing & Payment Panel
                Expanded(
                  flex: 6,
                  child: _buildPaymentPanel(),
                ),
              ],
            );
          } else {
            // Mobile: Tab-like or Switch between Orders and Bill
            return Column(
              children: [
                Expanded(
                  child: _selectedOrder == null
                      ? _buildOrderList(activeOrders)
                      : _buildPaymentPanel(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> activeOrders) {
    return Container(
      color: AppTheme.surfaceBg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Antrean Pesanan Belum Dibayar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                  '${activeOrders.length} Tagihan',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeOrders.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: AppTheme.statusGreen.withValues(alpha: 0.7)),
                    const SizedBox(height: 12),
                    const Text('Semua tagihan pesanan telah lunas', style: TextStyle(color: AppTheme.textMuted)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: activeOrders.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = activeOrders[index];
                  final isSelected = _selectedOrder?.idOrder == order.idOrder;

                  return InkWell(
                    onTap: () => _selectOrder(order),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.orangeLight : AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.orangePrimary : AppTheme.borderSubtle,
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '#${order.idOrder}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                              StatusBadge.fromStatus(order.status.label),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pelanggan: ${order.namaPelanggan}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${order.totalItem} item makanan/minuman',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('HH:mm').format(order.tanggal),
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                              Text(
                                _currencyFormat.format(order.totalHarga),
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

  Widget _buildPaymentPanel() {
    if (_selectedOrder == null) {
      return Container(
        color: AppTheme.white,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.point_of_sale, size: 48, color: AppTheme.textMuted),
              SizedBox(height: 12),
              Text(
                'Pilih pesanan dari daftar antrean untuk proses pembayaran',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final order = _selectedOrder!;

    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with back button on mobile
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembayaran ${order.noMeja}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    ),
                    Text(
                      'Order #${order.idOrder} • Pelanggan: ${order.namaPelanggan}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup / Batal',
                  onPressed: () => setState(() => _selectedOrder = null),
                ),
              ],
            ),
            const Divider(height: 24, color: AppTheme.borderSubtle),

            // Itemized Bill Details
            const Text(
              'Rincian Menu:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.jumlah}x ${item.menu.namaMasakan}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                          ),
                        ),
                        Text(
                          _currencyFormat.format(item.subtotal),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Total Tagihan Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.orangeLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.orangeBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Tagihan:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                  Text(
                    _currencyFormat.format(order.totalHarga),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method Selector
            const Text('Metode Pembayaran:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 8),
            Row(
              children: ['Tunai', 'QRIS', 'Debit'].map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(method),
                    selected: isSelected,
                    selectedColor: AppTheme.orangePrimary,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.white : AppTheme.textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedPaymentMethod = method),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Cash input
            TextField(
              controller: _bayarController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Jumlah Uang Diterima',
                hintText: 'Masukkan Jumlah Uang',
                prefixText: 'Rp ',
                prefixIcon: Icon(Icons.money, color: AppTheme.orangePrimary),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Cash Chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Uang Pas'),
                  onPressed: () => _quickCash(order.totalHarga),
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
              ],
            ),
            const SizedBox(height: 16),

            // Kembalian Display
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isPaymentValid ? AppTheme.statusGreenBg : AppTheme.statusRedBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isPaymentValid ? AppTheme.statusGreen.withValues(alpha: 0.3) : AppTheme.statusRed.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isPaymentValid ? 'Kembalian:' : 'Uang Kurang:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _isPaymentValid ? AppTheme.statusGreen : AppTheme.statusRed,
                    ),
                  ),
                  Text(
                    _isPaymentValid
                        ? _currencyFormat.format(_kembalian)
                        : _currencyFormat.format(order.totalHarga - _parsedBayar),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _isPaymentValid ? AppTheme.statusGreen : AppTheme.statusRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Payment Button
            ElevatedButton.icon(
              onPressed: _isPaymentValid ? _processPayment : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Bayar & Cetak Struk'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 10),

            // Void / Batalkan Pesanan (Admin & Kasir Management)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.statusRed,
                side: const BorderSide(color: AppTheme.statusRed),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Konfirmasi Pembatalan (Void)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    content: Text('Yakin ingin membatalkan pesanan #${order.idOrder} untuk ${order.noMeja}?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                        onPressed: () {
                          widget.db.updateOrderStatus(order.idOrder, OrderStatus.dibatalkan);
                          widget.db.updateTableStatus(order.noMeja, TableStatus.kosong);
                          Navigator.of(ctx).pop();
                          setState(() {
                            _selectedOrder = null;
                            _bayarController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.statusRed,
                              content: Text('✓ Pesanan #${order.idOrder} berhasil dibatalkan (Void).'),
                            ),
                          );
                        },
                        child: const Text('Ya, Batalkan Pesanan'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Batalkan Pesanan (Void)'),
            ),
          ],
        ),
      ),
    );
  }
}
