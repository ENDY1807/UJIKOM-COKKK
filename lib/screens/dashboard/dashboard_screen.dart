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
import '../../widgets/order_tracker_sheet.dart';

enum TableFilterType {
  all('Semua Meja'),
  kosong('Meja Kosong'),
  terisi('Meja Terisi');

  final String label;
  const TableFilterType(this.label);
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/Rasantara Cloche App Icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFFEA580C),
                          size: 28,
                        ),
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
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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

  // ── Filter Bar Denah Meja ──
  Widget _buildTableFilterBar({
    required int totalCount,
    required int emptyCount,
    required int occupiedCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          ],
        ),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Container(
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
            ),
          ),
        ),
      ],
    );
  }

  // ── Papan Nomor Meja Cepat (Speed-Dial Grid) ──
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

        if (constraints.maxWidth >= 1000) {
          crossAxisCount = 6;
          childAspectRatio = 1.05;
        } else if (constraints.maxWidth >= 650) {
          crossAxisCount = 4;
          childAspectRatio = 1.02;
        } else {
          crossAxisCount = 3;
          childAspectRatio = 0.95;
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

            return _buildQuickTileTable(
              table: table,
              isOccupied: isOccupied,
              order: matchingOrder,
              role: role,
            );
          },
        );
      },
    );
  }

  Widget _buildQuickTileTable({
    required TableModel table,
    required bool isOccupied,
    required OrderModel? order,
    required UserRole role,
  }) {
    final borderColor = isOccupied
        ? AppTheme.orangePrimary
        : context.borderSubtle;
    final bgColor = isOccupied
        ? (context.isDarkMode ? const Color(0xFF20130E) : const Color(0xFFFFF7ED))
        : context.surfaceCard;

    final numStr = table.nomorMeja.replaceAll(RegExp(r'[^0-9]'), '');

    return InkWell(
      onTap: () {
        if (order != null) {
          showOrderTrackerModal(
            context,
            db: widget.db,
            order: order,
            onNavigateToTab: (idx) => widget.onNavigateToTab(idx, tableNo: table.nomorMeja),
          );
        } else if (isOccupied) {
          final tabIndex = role.canProcessTransactions ? (role == UserRole.administrator ? 2 : 1) : 1;
          widget.onNavigateToTab(tabIndex, tableNo: table.nomorMeja);
        } else if (role.canCreateOrder) {
          widget.onNavigateToTab(1, tableNo: table.nomorMeja);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isOccupied ? 1.6 : 1.0,
          ),
          boxShadow: isOccupied
              ? [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Baris Atas: Label M & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'MEJA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isOccupied ? const Color(0xFFEA580C) : context.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isOccupied
                        ? const Color(0xFFEA580C).withValues(alpha: 0.15)
                        : const Color(0xFF16A34A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOccupied ? 'TERISI' : 'KOSONG',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),

            // Nomor Meja Utama (Besar & Kontras)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                numStr.isNotEmpty ? numStr : table.nomorMeja,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isOccupied ? const Color(0xFFEA580C) : context.textPrimary,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // Info Bawah: Tagihan/Tamu atau Kapasitas Kursi
            if (isOccupied && order != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _currencyFmt.format(order.totalHarga),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEA580C),
                  ),
                  maxLines: 1,
                ),
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${table.kapasitas} Kursi',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                  maxLines: 1,
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
