import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/analytics_charts.dart';
import '../../services/order_simulation_service.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService db;
  final Function(int tabIndex) onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.db,
    required this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _cardAnimations = List.generate(4, (i) {
      return CurvedAnimation(
        parent: _entryController,
        curve: Interval(i * 0.1, 0.6 + i * 0.1, curve: Curves.easeOutCubic),
      );
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final user = widget.db.currentUser;
    final role = user?.role ?? UserRole.pelanggan;

    final occupiedTables = widget.db.tables
        .where((t) => t.status == TableStatus.terisi)
        .length;
    final emptyTables = widget.db.tables
        .where((t) => t.status == TableStatus.kosong)
        .length;
    final reservedTables = widget.db.tables
        .where((t) => t.status == TableStatus.reservasi)
        .length;
    final activeOrders = widget.db.orders
        .where(
          (o) =>
              o.status != OrderStatus.selesai &&
              o.status != OrderStatus.dibatalkan,
        )
        .toList();

    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Selamat Pagi'
        : now.hour < 17
        ? 'Selamat Siang'
        : 'Selamat Malam';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F3),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Header ──
            _buildHeroHeader(user, role, greeting),
            const SizedBox(height: 20),

            // ── Metric Cards ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 750;
                final isMedium = constraints.maxWidth > 480;

                final metrics = [
                  _MetricData(
                    title: 'Meja Terisi',
                    value: '$occupiedTables/${widget.db.tables.length}',
                    sub: '$emptyTables kosong · $reservedTables reservasi',
                    icon: Icons.table_restaurant_rounded,
                    color: AppTheme.orangePrimary,
                    gradient: const [Color(0xFFFF7300), Color(0xFFEA580C)],
                    index: 0,
                  ),
                  _MetricData(
                    title: 'Pesanan Aktif',
                    value: '${activeOrders.length}',
                    sub: 'Menunggu & dimasak',
                    icon: Icons.soup_kitchen_rounded,
                    color: const Color(0xFFD97706),
                    gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                    index: 1,
                  ),
                  _MetricData(
                    title: 'Transaksi Lunas',
                    value: '${widget.db.totalTransaksiCount}',
                    sub: 'Tagihan dibayar',
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF16A34A),
                    gradient: const [Color(0xFF22C55E), Color(0xFF16A34A)],
                    index: 2,
                  ),
                  _MetricData(
                    title: 'Total Omzet',
                    value: fmt.format(widget.db.totalOmzet),
                    sub: 'Pendapatan tercatat',
                    icon: Icons.payments_rounded,
                    color: const Color(0xFF2563EB),
                    gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    index: 3,
                  ),
                ];

                Widget grid;
                if (isWide) {
                  grid = Row(
                    children: metrics
                        .map(
                          (m) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: _buildMetricCard(m),
                            ),
                          ),
                        )
                        .toList(),
                  );
                } else if (isMedium) {
                  grid = Column(
                    children: [
                      Row(
                        children: [metrics[0], metrics[1]]
                            .map(
                              (m) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: _buildMetricCard(m),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [metrics[2], metrics[3]]
                            .map(
                              (m) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: _buildMetricCard(m),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                } else {
                  // Mobile Layout: 2x2 Grid for compact and balanced viewing without endless scroll
                  grid = Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6, bottom: 8),
                              child: _buildMetricCard(metrics[0]),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6, bottom: 8),
                              child: _buildMetricCard(metrics[1]),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildMetricCard(metrics[2]),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _buildMetricCard(metrics[3]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return grid;
              },
            ),
            const SizedBox(height: 20),

            // ── Menu Best Seller & Rekomendasi + Antrean Pesanan / Proses Pesanan ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final queueWidget = role == UserRole.pelanggan
                    ? _buildCustomerOrderTracker(activeOrders, fmt)
                    : _buildOrderQueue(activeOrders, role, fmt);
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildBestSellerSection(role, fmt),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: queueWidget,
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildBestSellerSection(role, fmt),
                    const SizedBox(height: 16),
                    queueWidget,
                  ],
                );
              },
            ),
            if (role != UserRole.pelanggan) ...[
              const SizedBox(height: 20),
              AnalyticsChartsWidget(db: widget.db),
            ],
          ],
        ),
      ),
    );
  }

  // ── Hero Header ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(dynamic user, UserRole role, String greeting) {
    return FadeTransition(
      opacity: _cardAnimations[0],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.1),
          end: Offset.zero,
        ).animate(_cardAnimations[0]),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7300), Color(0xFFEA580C), Color(0xFFCC4A0B)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background shape
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 60,
                bottom: -50,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Row(
                children: [
                  // Avatar
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        (user?.namaUser ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting,',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          user?.namaUser ?? 'Pengguna',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            '${role.label} · Restoran Rasantara',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Metric Card ────────────────────────────────────────────────────────────
  Widget _buildMetricCard(_MetricData m) {
    return AnimatedBuilder(
      animation: _cardAnimations[m.index],
      builder: (context, child) {
        return FadeTransition(
          opacity: _cardAnimations[m.index],
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(_cardAnimations[m.index]),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon with gradient
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: m.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(m.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              m.value,
              style: TextStyle(
                fontSize: m.value.length > 10 ? 16 : 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1A1A2E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              m.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              m.sub,
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Menu Best Seller & Rekomendasi ──────────────────────────────────────────
  Widget _buildBestSellerSection(UserRole role, NumberFormat fmt) {
    final topSellingNames = widget.db.topSellingMenus.map((e) => e.key.toLowerCase()).toList();
    final allMenus = widget.db.menus;

    final sortedMenus = List<MenuModel>.from(allMenus);
    sortedMenus.sort((a, b) {
      final aIdx = topSellingNames.indexOf(a.namaMasakan.toLowerCase());
      final bIdx = topSellingNames.indexOf(b.namaMasakan.toLowerCase());
      if (aIdx != -1 && bIdx != -1) return aIdx.compareTo(bIdx);
      if (aIdx != -1) return -1;
      if (bIdx != -1) return 1;
      return 0;
    });

    final displayMenus = sortedMenus.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 20),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Menu Best Seller & Rekomendasi',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Paling banyak dipesan pelanggan Rasantara',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => widget.onNavigateToTab(1),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFEA580C)),
                  label: const Text(
                    'Lihat Menu',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (displayMenus.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text('Belum ada menu masakan tersedia', style: TextStyle(color: Color(0xFF64748B))),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: displayMenus.length,
                itemBuilder: (context, i) {
                  final menu = displayMenus[i];
                  final rank = i + 1;
                  final badgeLabel = rank == 1
                      ? '🔥 #1 Terlaris'
                      : rank == 2
                          ? '⭐ #2 Favorit'
                          : rank == 3
                              ? '👍 #3 Rekomendasi'
                              : 'Menu Pilihan';

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto Menu & Badge Rank
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                              child: SizedBox(
                                width: double.infinity,
                                height: 95,
                                child: menu.gambarUrl.isNotEmpty
                                    ? Image.network(
                                        menu.gambarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => _menuPlaceholder(),
                                      )
                                    : _menuPlaceholder(),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: rank <= 3 ? const Color(0xFFEA580C) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeLabel,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      menu.namaMasakan,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      fmt.format(menu.harga),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFEA580C)),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 26,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFF7ED),
                                      foregroundColor: const Color(0xFFEA580C),
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: const BorderSide(color: Color(0xFFFFEDD5)),
                                      ),
                                    ),
                                    onPressed: () => widget.onNavigateToTab(1),
                                    child: const Text('Pesan Sekarang', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  Widget _menuPlaceholder() {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C), size: 28),
      ),
    );
  }

  // ── Customer Live Order Tracker (Proses Pesanan Anda) ─────────────────────
  Widget _buildCustomerOrderTracker(List<dynamic> activeOrders, NumberFormat fmt) {
    final currentUser = widget.db.currentUser;
    // Ambil pesanan milik user pelanggan yang sedang aktif atau yang paling baru
    final userOrders = activeOrders.where((o) =>
      (currentUser != null && o.idUser == currentUser.idUser) ||
      (currentUser != null && o.namaPelanggan.toString().toLowerCase().trim() == currentUser.namaUser.toLowerCase().trim())
    ).toList();

    dynamic targetOrder = userOrders.isNotEmpty ? userOrders.first : null;
    if (targetOrder == null && currentUser != null) {
      final allUserOrders = widget.db.orders.where((o) =>
        o.idUser == currentUser.idUser ||
        o.namaPelanggan.toString().toLowerCase().trim() == currentUser.namaUser.toLowerCase().trim()
      ).toList();
      if (allUserOrders.isNotEmpty) {
        targetOrder = allUserOrders.first;
      }
    }
    // Fallback ke pesanan aktif pertama jika pelanggan belum ada pesanan atas namanya
    targetOrder ??= activeOrders.isNotEmpty ? activeOrders.first : null;

    final simService = OrderSimulationService();
    simService.attachDatabase(widget.db);

    return ListenableBuilder(
      listenable: simService,
      builder: (context, _) {
        final progress = (targetOrder != null && targetOrder is OrderModel)
            ? simService.getOrCreateProgress(targetOrder)
            : null;
        final currentStep = progress?.currentStep ??
            (targetOrder?.status == OrderStatus.selesai
                ? 4
                : (targetOrder?.status == OrderStatus.diproses ? 2 : 1));

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.timeline_rounded, color: Color(0xFFEA580C), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Proses Pesanan Anda',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (targetOrder != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Text(
                        '#${targetOrder.idOrder}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      targetOrder != null
                          ? '${targetOrder.noMeja} · Status bergerak real-time'
                          : 'Pantau status hidangan Anda secara real-time',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (targetOrder != null && currentStep < 4) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => simService.advanceStep(targetOrder.idOrder),
                      icon: const Icon(Icons.fast_forward_rounded, size: 14, color: Color(0xFFEA580C)),
                      label: const Text(
                        'Percepat',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                      ),
                    ),
                  ] else if (targetOrder != null && currentStep >= 4) ...[
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => simService.restartSimulation(targetOrder.idOrder),
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF16A34A)),
                      label: const Text(
                        'Ulangi',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

          if (targetOrder == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 32,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Belum ada pesanan aktif saat ini',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pindai QR meja atau pesan hidangan untuk memantau status secara langsung.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => widget.onNavigateToTab(1),
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                      label: const Text('Buka Menu Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Ringkasan item pesanan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.dinner_dining_rounded, color: Color(0xFFEA580C), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${targetOrder.items.length} Menu Dipesan (${targetOrder.totalItem} porsi)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          (targetOrder.items as List).map((i) => '${i.jumlah}x ${i.menu.namaMasakan}').join(', '),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmt.format(targetOrder.totalHarga),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Catatan estimasi acak (mengapa lebih cepat/lama)
            if (progress != null && progress.reasonNote.isNotEmpty && currentStep < 4) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
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

            // 4-Stage Stepper:
            _buildTimelineStep(
              stepNumber: 1,
              title: 'Pesanan Diterima Kasir',
              subtitle: 'Pesanan telah masuk antrean kasir dan diteruskan ke dapur.',
              icon: Icons.receipt_long_rounded,
              isCompleted: currentStep > 1,
              isActive: currentStep == 1,
              isLast: false,
              durationInfo: currentStep == 1 ? '${progress?.remainingSecondsInStep ?? 0}s lagi' : null,
              progressValue: currentStep == 1 ? progress?.stepProgress : null,
            ),
            _buildTimelineStep(
              stepNumber: 2,
              title: 'Sedang Dimasak di Dapur',
              subtitle: 'Koki dan tim dapur sedang menyiapkan dan memasak hidangan.',
              icon: Icons.soup_kitchen_rounded,
              isCompleted: currentStep > 2,
              isActive: currentStep == 2,
              isLast: false,
              durationInfo: currentStep == 2 ? '${progress?.remainingSecondsInStep ?? 0}s lagi' : null,
              progressValue: currentStep == 2 ? progress?.stepProgress : null,
            ),
            _buildTimelineStep(
              stepNumber: 3,
              title: targetOrder.noMeja.toString().toLowerCase().contains('take away')
                  ? 'Sedang Diantar Kurir'
                  : 'Sedang Diantar ke Meja',
              subtitle: targetOrder.noMeja.toString().toLowerCase().contains('take away')
                  ? 'Pesanan dalam perjalanan pengantaran menuju lokasi Anda.'
                  : 'Pelayan sedang membawakan hidangan hangat langsung ke meja Anda.',
              icon: targetOrder.noMeja.toString().toLowerCase().contains('take away')
                  ? Icons.delivery_dining_rounded
                  : Icons.room_service_rounded,
              isCompleted: currentStep > 3,
              isActive: currentStep == 3,
              isLast: false,
              durationInfo: currentStep == 3 ? '${progress?.remainingSecondsInStep ?? 0}s lagi' : null,
              progressValue: currentStep == 3 ? progress?.stepProgress : null,
            ),
            _buildTimelineStep(
              stepNumber: 4,
              title: 'Selesai Diterima Pelanggan',
              subtitle: 'Pesanan telah selesai dinikmati. Selamat menikmati hidangan!',
              icon: Icons.check_circle_rounded,
              isCompleted: currentStep >= 4,
              isActive: currentStep >= 4,
              isLast: true,
              durationInfo: currentStep >= 4 ? 'Selesai dinikmati' : null,
              progressValue: null,
            ),
          ],
        ],
      ),
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
          // Step Indicator Column
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

          // Step Content
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

  // ── Order Queue ────────────────────────────────────────────────────────────
  Widget _buildOrderQueue(
    List<dynamic> activeOrders,
    UserRole role,
    NumberFormat fmt,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Antrean Pesanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      '${activeOrders.length} pesanan berjalan',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                if (role.canProcessTransactions)
                  GestureDetector(
                    onTap: () => widget.onNavigateToTab(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7300), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.point_of_sale,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Kasir',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (activeOrders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 40,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada pesanan aktif',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(activeOrders.length, 6),
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey[100], thickness: 1),
                itemBuilder: (context, i) {
                  final order = activeOrders[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF7300), Color(0xFFEA580C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.room_service_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    '${order.noMeja} · #${order.idOrder}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  StatusBadge.fromStatus(order.status.label),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order.namaPelanggan} · ${order.totalItem} item',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          fmt.format(order.totalHarga),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.orangePrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            if (activeOrders.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '+ ${activeOrders.length - 6} pesanan lainnya',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.orangePrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final int index;

  const _MetricData({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.index,
  });
}
