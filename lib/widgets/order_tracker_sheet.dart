import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/order_simulation_service.dart';
import 'receipt_dialog.dart';

/// Floating pill bar pesanan aktif (gaya Gojek) yang melayang di bawah layar
class FloatingOrderTrackerBar extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;
  final NumberFormat fmt;
  final String statusText;

  const FloatingOrderTrackerBar({
    super.key,
    required this.order,
    required this.onTap,
    required this.fmt,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33EA580C),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            '1',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Pesanan',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              fmt.format(order.grandTotalSetelahDiskon),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Pantau Pesanan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper fungsi untuk membuka modal bottom sheet Pantau Pesanan (Checkout Style)
void showOrderTrackerModal(
  BuildContext context, {
  required DatabaseService db,
  required OrderModel order,
  required Function(int) onNavigateToTab,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => OrderTrackerSheet(
      db: db,
      order: order,
      onNavigateToTab: onNavigateToTab,
    ),
  );
}

/// Modal Bottom Sheet Pantau Pesanan dengan tampilan Checkout & Live Tracking Gojek
class OrderTrackerSheet extends StatefulWidget {
  final DatabaseService db;
  final OrderModel order;
  final Function(int) onNavigateToTab;

  const OrderTrackerSheet({
    super.key,
    required this.db,
    required this.order,
    required this.onNavigateToTab,
  });

  @override
  State<OrderTrackerSheet> createState() => _OrderTrackerSheetState();
}

class _OrderTrackerSheetState extends State<OrderTrackerSheet> {
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final simService = OrderSimulationService();
    simService.attachDatabase(widget.db);

    return ListenableBuilder(
      listenable: simService,
      builder: (context, _) {
        final progress = simService.getOrCreateProgress(widget.order);
        final currentStep = progress.currentStep;

        // Cari data transaksi terkait
        TransactionModel? matchingTrx;
        for (final t in widget.db.transactions) {
          if (t.order.idOrder == widget.order.idOrder) {
            matchingTrx = t;
            break;
          }
        }

        final statusText = currentStep >= 4
            ? 'Selesai'
            : (currentStep == 3
                ? 'Diantar'
                : (currentStep == 2 ? 'Dimasak' : 'Diterima'));

        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 24,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Sheet
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFFEA580C),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pantau Pesanan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Detail tracking #${widget.order.idOrder}',
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: currentStep >= 4
                                    ? const Color(0xFFF0FDF4)
                                    : (currentStep == 3
                                        ? const Color(0xFFEFF6FF)
                                        : const Color(0xFFFFF7ED)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: currentStep >= 4
                                      ? const Color(0xFFDCFCE7)
                                      : (currentStep == 3
                                          ? const Color(0xFFDBEAFE)
                                          : const Color(0xFFFFEDD5)),
                                ),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: currentStep >= 4
                                      ? const Color(0xFF16A34A)
                                      : (currentStep == 3
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFFEA580C)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Scrollable Body
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // ── A. Kartu Alamat & Meja (Gojek Checkout Style) ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEA580C),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      widget.order.noMeja.toString().toLowerCase().contains('take away')
                                          ? Icons.delivery_dining_rounded
                                          : Icons.table_restaurant_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                widget.order.noMeja,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF7ED),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFFFEDD5)),
                                              ),
                                              child: Text(
                                                '#${widget.order.idOrder}',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFEA580C),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Pemesan: ${widget.order.namaPelanggan}',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFFEDD5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFEA580C)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.order.keterangan.trim().isNotEmpty
                                            ? 'Instruksi: ${widget.order.keterangan}'
                                            : 'Instruksi: Disajikan hangat dan higienis ke meja',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF9A3412),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── B. Rincian Menu Dipesan (Gojek Checkout Menu Items) ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Menu yang Dipesan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              '${widget.order.items.length} menu (${widget.order.totalItem} porsi)',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        ...widget.order.items.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF7ED),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: const Color(0xFFFFEDD5)),
                                            ),
                                            child: Text(
                                              '${item.jumlah}x',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFEA580C),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.menu.namaMasakan,
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E293B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.catatan.trim().isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          item.catatan,
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        fmt.format(item.subtotal),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEA580C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    color: const Color(0xFFFFF7ED),
                                    child: item.menu.gambarUrl.isNotEmpty
                                        ? Image.network(
                                            item.menu.gambarUrl,
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, stack) => const Center(
                                              child: Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C), size: 22),
                                            ),
                                          )
                                        : const Center(
                                            child: Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C), size: 22),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),

                        // ── C. Ringkasan Pembayaran (Gojek Checkout Summary) ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ringkasan pembayaran',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Harga (${widget.order.totalItem} porsi)',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    fmt.format(widget.order.totalHarga),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                              if (widget.order.totalDiskon > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Diskon & Kupon Promosi',
                                      style: TextStyle(fontSize: 12, color: Color(0xFFEA580C)),
                                    ),
                                    Text(
                                      '- ${fmt.format(widget.order.totalDiskon)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Biaya Layanan & Penanganan',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  Text(
                                    'Rp 0 (Gratis)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(color: Color(0xFFE2E8F0), height: 1),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total pembayaran',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    fmt.format(widget.order.grandTotalSetelahDiskon),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        matchingTrx != null
                                            ? 'Metode: ${matchingTrx.metodePembayaran} · Lunas'
                                            : 'Metode: Tunai / Verifikasi Kasir',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                      ),
                                    ),
                                    if (matchingTrx != null)
                                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── D. Status Perjalanan / Live Tracker ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.route_rounded, size: 16, color: Color(0xFFEA580C)),
                                SizedBox(width: 6),
                                Text(
                                  'Status Perjalanan Hidangan',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            if (currentStep < 4)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => simService.advanceStep(widget.order.idOrder),
                                icon: const Icon(Icons.fast_forward_rounded, size: 14, color: Color(0xFFEA580C)),
                                label: const Text(
                                  'Percepat',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFDCFCE7)),
                                    ),
                                    child: Text(
                                      'Selesai (${progress.remainingSecondsUntilClear}s)',
                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      simService.dismissCompletedOrder(widget.order.idOrder);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'Tutup Sesi',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (progress.reasonNote.isNotEmpty && currentStep < 4) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 15, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    progress.reasonNote,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        _buildTimelineStep(
                          stepNumber: 1,
                          title: 'Pesanan Diterima Resto',
                          subtitle: 'Pesanan telah masuk antrean kasir dan diteruskan ke dapur.',
                          icon: Icons.receipt_long_rounded,
                          isCompleted: currentStep > 1,
                          isActive: currentStep == 1,
                          isLast: false,
                          durationInfo: currentStep == 1 ? '${progress.remainingSecondsInStep}s lagi' : null,
                          progressValue: currentStep == 1 ? progress.stepProgress : null,
                        ),
                        _buildTimelineStep(
                          stepNumber: 2,
                          title: 'Sedang Dimasak di Dapur',
                          subtitle: 'Koki dan tim dapur sedang menyiapkan hidangan hangat Anda.',
                          icon: Icons.soup_kitchen_rounded,
                          isCompleted: currentStep > 2,
                          isActive: currentStep == 2,
                          isLast: false,
                          durationInfo: currentStep == 2 ? '${progress.remainingSecondsInStep}s lagi' : null,
                          progressValue: currentStep == 2 ? progress.stepProgress : null,
                        ),
                        _buildTimelineStep(
                          stepNumber: 3,
                          title: widget.order.noMeja.toString().toLowerCase().contains('take away')
                              ? 'Sedang Diantar Kurir'
                              : 'Sedang Diantar ke Meja',
                          subtitle: widget.order.noMeja.toString().toLowerCase().contains('take away')
                              ? 'Pesanan dalam perjalanan pengantaran menuju lokasi Anda.'
                              : 'Pelayan sedang membawakan hidangan langsung ke meja Anda.',
                          icon: widget.order.noMeja.toString().toLowerCase().contains('take away')
                              ? Icons.delivery_dining_rounded
                              : Icons.room_service_rounded,
                          isCompleted: currentStep > 3,
                          isActive: currentStep == 3,
                          isLast: false,
                          durationInfo: currentStep == 3 ? '${progress.remainingSecondsInStep}s lagi' : null,
                          progressValue: currentStep == 3 ? progress.stepProgress : null,
                        ),
                        _buildTimelineStep(
                          stepNumber: 4,
                          title: 'Selesai Diterima Pelanggan',
                          subtitle: 'Pesanan telah selesai disajikan. Selamat menikmati hidangan!',
                          icon: Icons.check_circle_rounded,
                          isCompleted: currentStep >= 4,
                          isActive: currentStep >= 4,
                          isLast: true,
                          durationInfo: currentStep >= 4 ? 'Selesai dinikmati' : null,
                          progressValue: null,
                        ),

                        const SizedBox(height: 16),

                        // ── E. Tombol Aksi Bawah ──
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEA580C),
                                  side: const BorderSide(color: Color(0xFFEA580C)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  final trxToShow = matchingTrx ??
                                      TransactionModel(
                                        idTransaksi: widget.order.idOrder,
                                        idUser: widget.order.idUser,
                                        namaKasir: 'Kasir Rasantara',
                                        order: widget.order,
                                        tanggal: widget.order.tanggal,
                                        totalBayar: widget.order.grandTotalSetelahDiskon,
                                        jumlahBayar: widget.order.grandTotalSetelahDiskon,
                                        kembalian: 0,
                                        metodePembayaran: 'Pembayaran Kasir',
                                        diskonEvent: widget.order.diskonEvent,
                                        diskonKupon: widget.order.diskonKupon,
                                        potonganPoin: widget.order.potonganPoin,
                                        kodeKupon: widget.order.kodeKupon,
                                      );
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => ReceiptDialog(transaction: trxToShow),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                label: const Text(
                                  'Lihat Struk',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA580C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onNavigateToTab(1);
                                },
                                icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                                label: const Text(
                                  'Pesan Lagi',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
    String? durationInfo,
    double? progressValue,
  }) {
    final stepColor = isCompleted
        ? const Color(0xFF16A34A)
        : (isActive ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFF16A34A)
                      : (isActive ? const Color(0xFFEA580C) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(color: stepColor, width: 2),
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : icon,
                  size: 16,
                  color: (isCompleted || isActive) ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (isActive || isCompleted) ? FontWeight.bold : FontWeight.w600,
                          color: (isActive || isCompleted) ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (isActive && !isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                          ),
                          child: Text(
                            durationInfo != null ? 'Berlangsung · $durationInfo' : 'Berlangsung',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                          ),
                        )
                      else if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFDCFCE7)),
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: (isActive || isCompleted) ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                  if (isActive && progressValue != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressValue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEA580C)),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

