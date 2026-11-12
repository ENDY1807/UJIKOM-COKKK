import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/analytics_charts.dart';

enum TableFilterType {
  all('Semua Meja'),
  kosong('Meja Kosong'),
  terisi('Meja Terisi');

  final String label;
  const TableFilterType(this.label);
}

enum TableDesignMode {
  floorPlan('Denah Visual', Icons.table_restaurant_rounded),
  cardModern('Kartu POS', Icons.grid_view_rounded),
  quickTile('Papan Cepat', Icons.view_comfy_rounded);

  final String label;
  final IconData icon;
  const TableDesignMode(this.label, this.icon);
}

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
  TableFilterType _selectedFilter = TableFilterType.all;
  TableDesignMode _selectedDesignMode = TableDesignMode.floorPlan;
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

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
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
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

    // Filter meja sesuai pilihan
    final filteredTables = tables.where((t) {
      if (_selectedFilter == TableFilterType.kosong) {
        return t.status == TableStatus.kosong;
      } else if (_selectedFilter == TableFilterType.terisi) {
        return t.status == TableStatus.terisi;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: RefreshIndicator(
        color: const Color(0xFFEA580C),
        onRefresh: () async {
          widget.db.syncTableStatusWithOrders();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Header Ringkasan Operasional Restoran ──
              _buildHeaderCard(user, role),
              const SizedBox(height: 16),

              // ── 2. Metric Cards Table Service ──
              _buildTableMetricCards(
                totalTables: tables.length,
                emptyCount: emptyCount,
                occupiedCount: occupiedCount,
                activeOrdersCount: activeOrders.length,
              ),
              const SizedBox(height: 20),

              // ── 3. Filter Bar Denah Meja ──
              _buildTableFilterBar(
                totalCount: tables.length,
                emptyCount: emptyCount,
                occupiedCount: occupiedCount,
              ),
              const SizedBox(height: 14),

              // ── 4. Peta Denah Meja Interaktif (Interactive Table Map Grid) ──
              _buildInteractiveTableGrid(filteredTables, activeOrders, role),
              const SizedBox(height: 24),

              // ── 5. Antrean Pesanan Meja Berjalan (Kitchen & Table Queue) ──
              _buildActiveOrdersQueueSection(activeOrders, role),

              // ── 6. Laporan Grafik untuk Owner / Admin ──
              if (role == UserRole.owner || role == UserRole.administrator) ...[
                const SizedBox(height: 24),
                AnalyticsChartsWidget(db: widget.db),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header Card Restoran Table Service ──
  Widget _buildHeaderCard(UserModel? user, UserRole role) {
    String formattedDate;
    try {
      formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime);
    } catch (_) {
      try {
        formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);
      } catch (_) {
        formattedDate = '${_currentTime.year}-${_currentTime.month.toString().padLeft(2, '0')}-${_currentTime.day.toString().padLeft(2, '0')}';
      }
    }
    final timeFormat = DateFormat('HH:mm:ss');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/kasirnih_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.table_restaurant_rounded,
                        color: Color(0xFFEA580C),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Rasantara',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: context.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'POS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Table Service & Kasir',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeFormat.format(_currentTime),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (isCompact) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: context.borderSubtle),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 11, color: context.textSecondary),
                    ),
                    Text(
                      timeFormat.format(_currentTime),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
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

  // ── Filter Bar & Pilihan Desain Meja ──
  Widget _buildTableFilterBar({
    required int totalCount,
    required int emptyCount,
    required int occupiedCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;

        final filterPills = Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.fillSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: TableFilterType.values.map((f) {
              final isSelected = _selectedFilter == f;
              String countLabel = '';
              if (f == TableFilterType.all) countLabel = '$totalCount';
              if (f == TableFilterType.kosong) countLabel = '$emptyCount';
              if (f == TableFilterType.terisi) countLabel = '$occupiedCount';

              String shortLabel = f == TableFilterType.all ? 'Semua' : (f == TableFilterType.kosong ? 'Kosong' : 'Terisi');

              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$shortLabel ($countLabel)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : context.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

        final designSwitcher = Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.fillSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: TableDesignMode.values.map((mode) {
              final isSelected = _selectedDesignMode == mode;
              return Tooltip(
                message: mode.label,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDesignMode = mode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEA580C) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          mode.icon,
                          size: 14,
                          color: isSelected ? Colors.white : context.textSecondary,
                        ),
                        if (!isNarrow) ...[
                          const SizedBox(width: 4),
                          Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : context.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.table_restaurant_rounded, size: 18, color: Color(0xFFEA580C)),
                const SizedBox(width: 6),
                Text(
                  'Denah Meja',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                filterPills,
              ],
            ),
            designSwitcher,
          ],
        );
      },
    );
  }

  // ── Peta Denah Meja Interaktif Sesuai Mode Desain ──
  Widget _buildInteractiveTableGrid(
    List<TableModel> tables,
    List<OrderModel> activeOrders,
    UserRole role,
  ) {
    if (tables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.table_restaurant_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Tidak ada meja pada filter ini',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        double childAspectRatio;

        switch (_selectedDesignMode) {
          case TableDesignMode.floorPlan:
            if (constraints.maxWidth >= 1000) {
              crossAxisCount = 4;
              childAspectRatio = 1.05;
            } else if (constraints.maxWidth >= 650) {
              crossAxisCount = 3;
              childAspectRatio = 1.0;
            } else {
              crossAxisCount = 2;
              childAspectRatio = 0.92;
            }
            break;

          case TableDesignMode.cardModern:
            if (constraints.maxWidth >= 1000) {
              crossAxisCount = 4;
              childAspectRatio = 1.25;
            } else if (constraints.maxWidth >= 650) {
              crossAxisCount = 3;
              childAspectRatio = 1.15;
            } else {
              crossAxisCount = 2;
              childAspectRatio = 1.05;
            }
            break;

          case TableDesignMode.quickTile:
            if (constraints.maxWidth >= 1000) {
              crossAxisCount = 6;
              childAspectRatio = 1.08;
            } else if (constraints.maxWidth >= 650) {
              crossAxisCount = 4;
              childAspectRatio = 1.02;
            } else {
              crossAxisCount = 3;
              childAspectRatio = 0.95;
            }
            break;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            final matchingOrder = activeOrders.where(
              (o) => o.noMeja.toLowerCase() == table.nomorMeja.toLowerCase(),
            ).firstOrNull;

            final isOccupied = table.status == TableStatus.terisi || matchingOrder != null;

            switch (_selectedDesignMode) {
              case TableDesignMode.floorPlan:
                return _buildFloorPlanTable(
                  table: table,
                  isOccupied: isOccupied,
                  order: matchingOrder,
                  role: role,
                );
              case TableDesignMode.cardModern:
                return _buildCardModernTable(
                  table: table,
                  isOccupied: isOccupied,
                  order: matchingOrder,
                  role: role,
                );
              case TableDesignMode.quickTile:
                return _buildQuickTileTable(
                  table: table,
                  isOccupied: isOccupied,
                  order: matchingOrder,
                  role: role,
                );
            }
          },
        );
      },
    );
  }

  // ── DESAIN 1: Denah Restoran Visual dengan Kursi Melingkari Meja ──
  Widget _buildFloorPlanTable({
    required TableModel table,
    required bool isOccupied,
    required OrderModel? order,
    required UserRole role,
  }) {
    final borderColor = isOccupied
        ? const Color(0xFFEA580C)
        : (context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final bgColor = isOccupied
        ? (context.isDarkMode ? const Color(0xFF431407).withValues(alpha: 0.25) : const Color(0xFFFFF7ED))
        : context.surfaceCard;
    final chairColor = isOccupied
        ? const Color(0xFFEA580C)
        : const Color(0xFF16A34A).withValues(alpha: 0.4);

    return InkWell(
      onTap: () {
        if (isOccupied) {
          final tabIndex = role.canProcessTransactions ? (role == UserRole.administrator ? 2 : 1) : 1;
          widget.onNavigateToTab(tabIndex, tableNo: table.nomorMeja);
        } else if (role.canCreateOrder) {
          widget.onNavigateToTab(1, tableNo: table.nomorMeja);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isOccupied ? 1.5 : 1,
          ),
          boxShadow: isOccupied
              ? [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Kursi Bagian Atas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 6,
                  decoration: BoxDecoration(
                    color: chairColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (table.kapasitas > 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 6,
                    decoration: BoxDecoration(
                      color: chairColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // Bagian Tengah: Kursi Kiri + Permukaan Meja Utama + Kursi Kanan
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 22,
                    decoration: BoxDecoration(
                      color: chairColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOccupied
                            ? const Color(0xFFEA580C)
                            : (context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isOccupied
                              ? const Color(0xFFC2410C)
                              : (context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            table.nomorMeja.replaceAll('Meja ', 'M-'),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: isOccupied ? Colors.white : context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (isOccupied && order != null) ...[
                            Text(
                              order.namaPelanggan.isNotEmpty ? order.namaPelanggan : 'Tamu',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _currencyFmt.format(order.totalHarga),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFEDD5),
                              ),
                            ),
                          ] else ...[
                            Text(
                              '${table.kapasitas} Kursi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  Container(
                    width: 6,
                    height: 22,
                    decoration: BoxDecoration(
                      color: chairColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Kursi Bagian Bawah
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 6,
                  decoration: BoxDecoration(
                    color: chairColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (table.kapasitas > 2) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 6,
                    decoration: BoxDecoration(
                      color: chairColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Status Badge & Aksi Cepat
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? const Color(0xFFEA580C).withValues(alpha: 0.15)
                        : const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isOccupied ? 'TERISI' : 'KOSONG',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
                Text(
                  isOccupied ? 'Lihat →' : '+ Order',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── DESAIN 2: Kartu Minimalis Modern POS ──
  Widget _buildCardModernTable({
    required TableModel table,
    required bool isOccupied,
    required OrderModel? order,
    required UserRole role,
  }) {
    final borderColor = isOccupied
        ? const Color(0xFFEA580C)
        : (context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final bgColor = isOccupied
        ? (context.isDarkMode ? const Color(0xFF431407).withValues(alpha: 0.25) : const Color(0xFFFFF7ED))
        : context.surfaceCard;

    return InkWell(
      onTap: () {
        if (isOccupied) {
          final tabIndex = role.canProcessTransactions ? (role == UserRole.administrator ? 2 : 1) : 1;
          widget.onNavigateToTab(tabIndex, tableNo: table.nomorMeja);
        } else if (role.canCreateOrder) {
          widget.onNavigateToTab(1, tableNo: table.nomorMeja);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isOccupied ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOccupied ? const Color(0xFFEA580C) : context.fillSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        table.nomorMeja.replaceAll('Meja ', 'M-'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isOccupied ? Colors.white : context.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      table.nomorMeja,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            if (isOccupied && order != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.namaPelanggan.isNotEmpty ? order.namaPelanggan : 'Pelanggan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _currencyFmt.format(order.totalHarga),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.chair_alt_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${table.kapasitas} Kursi • Siap',
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                ],
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOccupied ? 'Sedang Dilayani' : 'Tersedia',
                  style: TextStyle(
                    fontSize: 10,
                    color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isOccupied ? 'Bayar' : '+ Pesan',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── DESAIN 3: Papan Nomor Meja Cepat / Speed-Dial ──
  Widget _buildQuickTileTable({
    required TableModel table,
    required bool isOccupied,
    required OrderModel? order,
    required UserRole role,
  }) {
    final borderColor = isOccupied
        ? const Color(0xFFEA580C)
        : (context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0));
    final bgColor = isOccupied
        ? const Color(0xFFEA580C)
        : context.surfaceCard;

    final numStr = table.nomorMeja.replaceAll(RegExp(r'[^0-9]'), '');

    return InkWell(
      onTap: () {
        if (isOccupied) {
          final tabIndex = role.canProcessTransactions ? (role == UserRole.administrator ? 2 : 1) : 1;
          widget.onNavigateToTab(tabIndex, tableNo: table.nomorMeja);
        } else if (role.canCreateOrder) {
          widget.onNavigateToTab(1, tableNo: table.nomorMeja);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isOccupied ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'M',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isOccupied ? Colors.white.withValues(alpha: 0.8) : context.textSecondary,
                letterSpacing: 1,
              ),
            ),
            Text(
              numStr.isNotEmpty ? numStr : table.nomorMeja,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isOccupied ? Colors.white : context.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isOccupied
                    ? Colors.black.withValues(alpha: 0.2)
                    : const Color(0xFF16A34A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isOccupied ? 'TERISI' : '${table.kapasitas}K',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: isOccupied ? Colors.white : const Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ),
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
            Row(
              children: [
                const Icon(Icons.soup_kitchen_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Text(
                  'Pesanan Berjalan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
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

    return Container(
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
                    Text(
                      order.namaPelanggan.isNotEmpty ? order.namaPelanggan : 'Pelanggan Meja',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
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
    );
  }
}
