import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/receipt_dialog.dart';
import '../../widgets/status_badge.dart';

class CustomerOrderHistoryScreen extends StatefulWidget {
  final DatabaseService db;

  const CustomerOrderHistoryScreen({super.key, required this.db});

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  String _filter = 'semua'; // 'semua', 'aktif', 'selesai'

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.db.currentUser?.idUser;
    final currentUserName = widget.db.currentUser?.namaUser.toLowerCase() ?? '';

    // Filter orders belonging to this user or created in this session
    final userOrders = widget.db.orders.where((o) {
      if (currentUserId != null && o.idUser == currentUserId) return true;
      if (currentUserName.isNotEmpty &&
          o.namaPelanggan.toLowerCase().contains(currentUserName)) {
        return true;
      }
      return false;
    }).toList();

    // Fallback if list is empty but orders exist in session
    final displayOrders = userOrders.isNotEmpty
        ? userOrders
        : widget.db.orders;

    final filtered = displayOrders.where((o) {
      if (_filter == 'aktif') {
        return o.status == OrderStatus.menunggu ||
            o.status == OrderStatus.diproses;
      } else if (_filter == 'selesai') {
        return o.status == OrderStatus.selesai;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      appBar: AppBar(
        title: const Text(
          'Riwayat Pesanan Saya',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('Semua', 'semua'),
                const SizedBox(width: 8),
                _buildFilterChip('Sedang Diproses', 'aktif'),
                const SizedBox(width: 8),
                _buildFilterChip('Selesai', 'selesai'),
              ],
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum Ada Riwayat Pesanan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pesanan yang Anda buat akan tercatat otomatis di sini.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final order = filtered[i];
                return _buildOrderCard(order);
              },
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.orangePrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final matchingTrx = widget.db.transactions
        .where((t) => t.order.idOrder == order.idOrder)
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: Color(0xFFEA580C),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.noMeja,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '#ORDER-${order.idOrder}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              StatusBadge.fromStatus(order.status.label),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Items summary
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.jumlah}x ${item.menu.namaMasakan}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  Text(
                    _currencyFmt.format(item.subtotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateFmt.format(order.tanggal),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFmt.format(order.totalHarga),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
              if (matchingTrx != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEA580C),
                    side: const BorderSide(color: Color(0xFFEA580C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_rounded, size: 16),
                  label: const Text('Lihat Struk'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ReceiptDialog(transaction: matchingTrx),
                    );
                  },
                )
              else if (order.status == OrderStatus.menunggu ||
                  order.status == OrderStatus.diproses)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sedang Disiapkan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

