import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/order_tracker_sheet.dart';
import '../../widgets/table_qr_scanner_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService db;
  final void Function(
    int tabIndex, {
    MenuCategory? category,
    String? searchQuery,
    String? couponCode,
    String? tableNo,
  }) onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.db,
    required this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    // Sinkronkan status meja dengan pesanan berjalan saat dashboard dimuat
    widget.db.syncTableStatusWithOrders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.db.currentUser;
    final role = user?.role ?? UserRole.pelanggan;
    final tables = widget.db.tables;
    final activeOrders = widget.db.orders
        .where((o) => o.status != OrderStatus.selesai && o.status != OrderStatus.dibatalkan)
        .toList();

    final occupiedCount = tables.where((t) => t.status == TableStatus.terisi).length;
    final emptyCount = tables.where((t) => t.status == TableStatus.kosong).length;

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: RefreshIndicator(
        color: const Color(0xFFEA580C),
        onRefresh: () async {
          await widget.db.initSupabase();
          if (mounted) setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TAMPILAN KHUSUS PELANGGAN ──
              if (role == UserRole.pelanggan) ...[
                _buildPelangganHeroQrCard(),
                const SizedBox(height: 18),
                _buildPelangganSubscriptionCard(user),
                const SizedBox(height: 20),
                _buildActiveOrdersQueueSection(activeOrders, role),
              ] else ...[
                // ── TAMPILAN STAFF (ADMIN, WAITER, KASIR, OWNER) ──
                if (role == UserRole.waiter) ...[
                  _buildWaiterAssistanceCard(),
                  const SizedBox(height: 16),
                ],

                // ── 1. Metric Cards Table Service ──
                _buildTableMetricCards(
                  totalTables: tables.length,
                  emptyCount: emptyCount,
                  occupiedCount: occupiedCount,
                  activeOrdersCount: activeOrders.length,
                ),
                const SizedBox(height: 20),

                // ── 2. Aksi Cepat Operasional Restoran (QR Meja) ──
                _buildQuickOperationalBar(),
                const SizedBox(height: 20),

                // ── 4. Antrean Pesanan Meja Berjalan (Kitchen & Table Queue) ──
                _buildActiveOrdersQueueSection(activeOrders, role),

                // ── 5. Laporan Grafik untuk Owner (Beranda Admin Tidak Menampilkan Laporan) ──
                if (role == UserRole.owner) ...[
                  const SizedBox(height: 24),
                  AnalyticsChartsWidget(db: widget.db),
                ],
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── KARTU HERO SCAN QR MEJA KHUSUS PELANGGAN ──
  Widget _buildPelangganHeroQrCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF00F2FE),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TABLE SERVICE RESTORAN',
                        style: TextStyle(
                          color: Color(0xFF38E1FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pesan Makanan Lewat QR Meja',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Scan stiker QR Code yang tertera pada meja makan Anda menggunakan kamera HP atau scanner aplikasi untuk langsung membuka daftar hidangan dan memesan menu ke dapur.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFCBD5E1),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orangePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    TableQrScannerDialog.show(
                      context,
                      db: widget.db,
                      onTableScanned: (tableNo) {
                        widget.onNavigateToTab(1, tableNo: tableNo);
                      },
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: const Text(
                    'Pindai QR Meja Sekarang',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── KARTU STATUS BERLANGGANAN VIP PELANGGAN ──
  Widget _buildPelangganSubscriptionCard(UserModel? user) {
    final isVip = user?.isSubscribed ?? false;

    if (isVip) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFD97706),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_membership_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Member Berlangganan VIP Aktif',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.verified_rounded, size: 16, color: Color(0xFFD97706)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Anda mendapatkan diskon otomatis 10% untuk setiap pesanan hidangan di meja!',
                    style: TextStyle(fontSize: 12, color: Colors.brown.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.orangeBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.orangeLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.card_membership_rounded, color: AppTheme.orangePrimary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingin Berlangganan VIP Restoran?',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  'Dapatkan diskon 10% setiap kali bersantap di Rasantara.',
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.orangePrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (user != null) {
                widget.db.updateUser(
                  user.idUser,
                  user.namaUser,
                  user.password,
                  user.role,
                  isSubscribed: true,
                );
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Selamat! Akun Anda kini aktif sebagai Member VIP Berlangganan!'),
                    backgroundColor: Color(0xFF16A34A),
                  ),
                );
              }
            },
            child: const Text('Aktivasi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── KARTU PANDUAN BANTUAN WAITER UNTUK PELANGGAN ──
  Widget _buildWaiterAssistanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF16A34A), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Panduan Waiter: Membantu Pelanggan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pelanggan dapat mendaftar mandiri via aplikasi. Jika pelanggan menemui kendala saat registrasi atau berlangganan, pandu tamu atau daftarkan akun mereka langsung.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              side: const BorderSide(color: Color(0xFF16A34A)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.surfaceCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Text('Panduan Tamu & Langganan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  content: const Text(
                    'Tamu dapat mendaftar akun mandiri melalui tab "Daftar Akun Baru" pada layar login aplikasi di smartphone mereka. '
                    'Waiter memandu tamu mengaktifkan opsi Member VIP saat pendaftaran untuk mendapatkan diskon langsung 10% setiap pemesanan.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Lihat Panduan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Metric Cards Ringkasan Meja ──
  Widget _buildTableMetricCards({
    required int totalTables,
    required int emptyCount,
    required int occupiedCount,
    required int activeOrdersCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        final metrics = [
          _buildSingleMetricCard(
            title: 'Total Meja',
            value: '$totalTables',
            icon: Icons.table_restaurant_rounded,
            color: const Color(0xFF0F172A),
            accentColor: const Color(0xFF64748B),
          ),
          _buildSingleMetricCard(
            title: 'Meja Kosong',
            value: '$emptyCount',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF16A34A),
            accentColor: const Color(0xFF16A34A),
          ),
          _buildSingleMetricCard(
            title: 'Meja Terisi',
            value: '$occupiedCount',
            icon: Icons.restaurant_rounded,
            color: const Color(0xFFEA580C),
            accentColor: const Color(0xFFEA580C),
          ),
          _buildSingleMetricCard(
            title: 'Pesanan Aktif',
            value: '$activeOrdersCount',
            icon: Icons.soup_kitchen_rounded,
            color: const Color(0xFF2563EB),
            accentColor: const Color(0xFF2563EB),
          ),
        ];

        if (isWide) {
          return Row(
            children: metrics
                .map((m) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: m,
                      ),
                    ))
                .toList(),
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: metrics[0]),
                  const SizedBox(width: 8),
                  Expanded(child: metrics[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: metrics[2]),
                  const SizedBox(width: 8),
                  Expanded(child: metrics[3]),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSingleMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Aksi Cepat Operasional Restoran (QR Meja Tamu) ──
  Widget _buildQuickOperationalBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, size: 22, color: AppTheme.orangePrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR Code Meja Tamu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cetak atau tampilkan QR code stiker untuk setiap meja restoran',
                        style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orangePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            onPressed: () {
              TableQrViewerDialog.show(context, db: widget.db);
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Buka QR Meja', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Antrean Pesanan Meja Berjalan ──
  Widget _buildActiveOrdersQueueSection(List<OrderModel> activeOrders, UserRole role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.soup_kitchen_rounded, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Pesanan Berjalan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${activeOrders.length} Antrean',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (activeOrders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderSubtle),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 32, color: Color(0xFF16A34A)),
                const SizedBox(height: 6),
                Text(
                  'Semua pesanan meja telah selesai',
                  style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeOrders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              return _buildOrderQueueItem(order, role);
            },
          ),
      ],
    );
  }

  Widget _buildOrderQueueItem(OrderModel order, UserRole role) {
    final timeStr = DateFormat('HH:mm').format(order.tanggal);

    return InkWell(
      onTap: () {
        showOrderTrackerModal(
          context,
          db: widget.db,
          order: order,
          onNavigateToTab: (idx) => widget.onNavigateToTab(idx, tableNo: order.noMeja),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Icon(Icons.table_restaurant_rounded, size: 16, color: Color(0xFFEA580C)),
                  const SizedBox(height: 2),
                  Text(
                    order.noMeja,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          order.namaPelanggan.isNotEmpty ? order.namaPelanggan : 'Pelanggan Meja',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· $timeStr',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.items.map((i) => '${i.jumlah}x ${i.menu.namaMasakan}').join(', '),
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFmt.format(order.totalHarga),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status.label.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
