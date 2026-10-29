import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';

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
  late AnimationController _pulseController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final user = widget.db.currentUser;
    final role = user?.role ?? UserRole.pelanggan;

    final occupiedTables = widget.db.tables.where((t) => t.status == TableStatus.terisi).length;
    final emptyTables = widget.db.tables.where((t) => t.status == TableStatus.kosong).length;
    final reservedTables = widget.db.tables.where((t) => t.status == TableStatus.reservasi).length;
    final activeOrders = widget.db.orders
        .where((o) => o.status != OrderStatus.selesai && o.status != OrderStatus.dibatalkan)
        .toList();

    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Selamat Pagi' : now.hour < 17 ? 'Selamat Siang' : 'Selamat Malam';

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
                        .map((m) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                child: _buildMetricCard(m),
                              ),
                            ))
                        .toList(),
                  );
                } else if (isMedium) {
                  grid = Column(
                    children: [
                      Row(
                        children: [metrics[0], metrics[1]]
                            .map((m) => Expanded(child: Padding(padding: const EdgeInsets.all(4), child: _buildMetricCard(m))))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [metrics[2], metrics[3]]
                            .map((m) => Expanded(child: Padding(padding: const EdgeInsets.all(4), child: _buildMetricCard(m))))
                            .toList(),
                      ),
                    ],
                  );
                } else {
                  grid = Column(
                    children: metrics
                        .map((m) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: _buildMetricCard(m)))
                        .toList(),
                  );
                }
                return grid;
              },
            ),
            const SizedBox(height: 20),

            // ── Floor Plan + Orders ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildFloorPlan(occupiedTables, emptyTables, reservedTables, role),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildOrderQueue(activeOrders, role, fmt),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildFloorPlan(occupiedTables, emptyTables, reservedTables, role),
                    const SizedBox(height: 16),
                    _buildOrderQueue(activeOrders, role, fmt),
                  ],
                );
              },
            ),
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
            boxShadow: [
              BoxShadow(
                color: AppTheme.orangePrimary.withValues(alpha: 0.30),
                blurRadius: 24,
                offset: const Offset(0, 10),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                '${role.label} · Restoran Nusantara',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (user?.isGoogleLinked == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Google OAuth',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.db.isSupabaseConnected
                                    ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.db.isSupabaseConnected ? Icons.cloud_done : Icons.cloud_off,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.db.isSupabaseConnected ? 'Supabase Live' : 'Lokal',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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

                  // Live indicator
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final scale = 0.85 + _pulseController.value * 0.3;
                      return Column(
                        children: [
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      );
                    },
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
              begin: Offset(0, 0.3),
              end: Offset.zero,
            ).animate(_cardAnimations[m.index]),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
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
                boxShadow: [
                  BoxShadow(
                    color: m.color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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

  // ── Floor Plan ─────────────────────────────────────────────────────────────
  Widget _buildFloorPlan(int occ, int emp, int res, UserRole role) {
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Denah Meja Restoran (Table Floor Map)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    Text(
                      'Status ketersediaan real-time',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                // Legend pills
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _legendPill('Kosong', const Color(0xFF22C55E), const Color(0xFFDCFCE7)),
                    _legendPill('Terisi', AppTheme.orangePrimary, AppTheme.orangeLight),
                    _legendPill('Reservasi', const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              itemCount: widget.db.tables.length,
              itemBuilder: (context, i) {
                final table = widget.db.tables[i];
                final isOcc = table.status == TableStatus.terisi;
                final isRes = table.status == TableStatus.reservasi;

                Color bg, border, textC, iconC;
                if (isOcc) {
                  bg = AppTheme.orangeLight;
                  border = AppTheme.orangeBorder;
                  textC = AppTheme.orangePrimary;
                  iconC = AppTheme.orangePrimary;
                } else if (isRes) {
                  bg = const Color(0xFFFEF3C7);
                  border = const Color(0xFFFDE68A);
                  textC = const Color(0xFFD97706);
                  iconC = const Color(0xFFD97706);
                } else {
                  bg = const Color(0xFFDCFCE7);
                  border = const Color(0xFFBBF7D0);
                  textC = const Color(0xFF16A34A);
                  iconC = const Color(0xFF16A34A);
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: role.canCreateOrder ? () => widget.onNavigateToTab(1) : null,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border, width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_restaurant_rounded, size: 20, color: iconC),
                          const SizedBox(height: 6),
                          Text(
                            table.nomorMeja,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: textC,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${table.kapasitas} kursi',
                            style: TextStyle(fontSize: 10, color: textC.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendPill(String label, Color text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  // ── Order Queue ────────────────────────────────────────────────────────────
  Widget _buildOrderQueue(List<dynamic> activeOrders, UserRole role, NumberFormat fmt) {
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7300), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.point_of_sale, size: 14, color: Colors.white),
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
                      Icon(Icons.restaurant_menu_rounded, size: 40, color: Colors.grey[300]),
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
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey[100],
                  thickness: 1,
                ),
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
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
