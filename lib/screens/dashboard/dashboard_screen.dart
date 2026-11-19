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
import '../../widgets/table_qr_scanner_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final DatabaseService db;
  final void Function(
    int tabIndex, {
    MenuCategory? category,
    String? searchQuery,
    String? couponCode,
    String? tableNo,
    String? target,
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

  int _selectedTableFilter = 0; // 0: Semua Meja, 1: Meja Kosong, 2: Meja Terisi
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    widget.db.addListener(_onDbChanged);
    // Sinkronkan status meja dengan pesanan berjalan saat dashboard dimuat
    widget.db.syncTableStatusWithOrders();
    // Refresh visual setiap 5 detik agar countdown jeda 5 menit transisi mulus
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onDbChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    widget.db.removeListener(_onDbChanged);
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

    final occupiedCount = tables
        .where((t) => t.status == TableStatus.terisi || widget.db.isTableTemporarilyOccupied(t.nomorMeja))
        .length;
    final emptyCount = tables
        .where((t) => t.status == TableStatus.kosong && !widget.db.isTableTemporarilyOccupied(t.nomorMeja))
        .length;

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

                // ── 2. SISTEM DENAH & PILIH MEJA RESTORAN (KETERSEDIAAN KOSONG VS TERISI) ──
                _buildTableGridSection(tables, activeOrders, role),
                const SizedBox(height: 20),

                // ── 3. Aksi Cepat Operasional Restoran (QR Meja) ──
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
                    'Anda mendapatkan diskon otomatis ${widget.db.memberDiscountPercent}% untuk setiap pesanan hidangan di meja!',
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
                  'Dapatkan diskon ${widget.db.memberDiscountPercent}% setiap kali bersantap di Rasantara.',
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
                  content: Text(
                    'Tamu dapat mendaftar akun mandiri melalui tab "Daftar Akun Baru" pada layar login aplikasi di smartphone mereka. '
                    'Waiter memandu tamu mengaktifkan opsi Member VIP saat pendaftaran untuk mendapatkan diskon langsung ${widget.db.memberDiscountPercent}% setiap pemesanan.',
                    style: const TextStyle(fontSize: 13, height: 1.5),
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

  // ── 2. SISTEM DENAH & PILIH MEJA RESTORAN (KETERSEDIAAN KOSONG VS TERISI) ──
  Widget _buildTableGridSection(List<TableModel> tables, List<OrderModel> activeOrders, UserRole role) {
    // Filter meja sesuai chip terpilih
    final filteredTables = tables.where((t) {
      final isOcc = t.status == TableStatus.terisi || widget.db.isTableTemporarilyOccupied(t.nomorMeja);
      if (_selectedTableFilter == 1) return !isOcc && t.status != TableStatus.reservasi;
      if (_selectedTableFilter == 2) return isOcc;
      return true;
    }).toList();

    final occupiedCount = tables
        .where((t) => t.status == TableStatus.terisi || widget.db.isTableTemporarilyOccupied(t.nomorMeja))
        .length;
    final emptyCount = tables
        .where((t) => t.status == TableStatus.kosong && !widget.db.isTableTemporarilyOccupied(t.nomorMeja))
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
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
                      child: const Icon(Icons.table_restaurant_rounded, color: AppTheme.orangePrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pilih Meja',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Semua Meja (${tables.length})',
                  isSelected: _selectedTableFilter == 0,
                  onTap: () => setState(() => _selectedTableFilter = 0),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Meja Kosong ($emptyCount)',
                  isSelected: _selectedTableFilter == 1,
                  dotColor: const Color(0xFF16A34A),
                  onTap: () => setState(() => _selectedTableFilter = 1),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Meja Terisi ($occupiedCount)',
                  isSelected: _selectedTableFilter == 2,
                  dotColor: const Color(0xFFEA580C),
                  onTap: () => setState(() => _selectedTableFilter = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Grid Kartu Meja
          if (filteredTables.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.surfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderSubtle),
                // card border
              ),
              child: Center(
                child: Text(
                  'Tidak ada meja pada filter ini',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = 2;
                if (constraints.maxWidth >= 1050) {
                  crossAxisCount = 4;
                } else if (constraints.maxWidth >= 680) {
                  crossAxisCount = 3;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredTables.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: constraints.maxWidth >= 680 ? 1.7 : 1.45,
                  ),
                  itemBuilder: (context, index) {
                    final table = filteredTables[index];
                    final activeOrder = activeOrders
                        .where((o) => o.noMeja.toLowerCase() == table.nomorMeja.toLowerCase())
                        .firstOrNull;
                    return _buildTableCard(table, activeOrder, role);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? dotColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (dotColor ?? AppTheme.orangePrimary).withValues(alpha: 0.12)
              : context.surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (dotColor ?? AppTheme.orangePrimary)
                : context.borderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (dotColor ?? AppTheme.orangePrimary)
                    : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(TableModel table, OrderModel? activeOrder, UserRole role) {
    final isTempOccupied = widget.db.isTableTemporarilyOccupied(table.nomorMeja);
    final isOccupied = table.status == TableStatus.terisi || activeOrder != null || isTempOccupied;
    final isReserved = table.status == TableStatus.reservasi && !isTempOccupied;
    final isDark = context.isDarkMode;

    Color cardBg;
    Color cardBorder;
    Color statusColor;
    Color statusBg;
    Color titleColor;
    String statusLabel;

    if (isOccupied) {
      statusLabel = 'Terisi';
      if (isDark) {
        cardBg = const Color(0xFF381504);
        cardBorder = const Color(0xFFEA580C).withValues(alpha: 0.65);
        statusColor = const Color(0xFFFDBA74);
        statusBg = const Color(0xFFEA580C).withValues(alpha: 0.3);
        titleColor = const Color(0xFFFFEDD5);
      } else {
        cardBg = const Color(0xFFFFF7ED); // Warna oranye lembut untuk meja terisi
        cardBorder = const Color(0xFFFDBA74);
        statusColor = const Color(0xFFC2410C);
        statusBg = const Color(0xFFFFEDD5);
        titleColor = const Color(0xFF9A3412);
      }
    } else if (isReserved) {
      statusLabel = 'Reservasi';
      if (isDark) {
        cardBg = const Color(0xFF0F1F38);
        cardBorder = const Color(0xFF3B82F6).withValues(alpha: 0.65);
        statusColor = const Color(0xFF93C5FD);
        statusBg = const Color(0xFF1D4ED8).withValues(alpha: 0.3);
        titleColor = const Color(0xFFDBEAFE);
      } else {
        cardBg = const Color(0xFFEFF6FF); // Warna biru lembut untuk meja reservasi
        cardBorder = const Color(0xFF93C5FD);
        statusColor = const Color(0xFF1D4ED8);
        statusBg = const Color(0xFFDBEAFE);
        titleColor = const Color(0xFF1E40AF);
      }
    } else {
      statusLabel = 'Kosong';
      if (isDark) {
        cardBg = context.surfaceCard;
        cardBorder = const Color(0xFF166534).withValues(alpha: 0.5);
        statusColor = const Color(0xFF86EFAC);
        statusBg = const Color(0xFF166534).withValues(alpha: 0.3);
        titleColor = context.textPrimary;
      } else {
        cardBg = Colors.white; // Putih bersih untuk meja kosong
        cardBorder = const Color(0xFFBBF7D0);
        statusColor = const Color(0xFF15803D);
        statusBg = const Color(0xFFDCFCE7);
        titleColor = context.textPrimary;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (role == UserRole.kasir && isOccupied && activeOrder != null) {
            widget.onNavigateToTab(1, tableNo: table.nomorMeja, target: 'cashier');
          } else {
            widget.onNavigateToTab(1, tableNo: table.nomorMeja, target: 'order');
          }
        },
        onLongPress: () => _showTableDetailModal(context, table, activeOrder, role),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── BAGIAN ATAS KANAN: STATUS MEJA ──
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),

              // ── BAGIAN TENGAH: TULISAN MEJA (NO) ──
              Center(
                child: Text(
                  table.nomorMeja,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Penyeimbang bawah
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showTableDetailModal(
    BuildContext context,
    TableModel table,
    OrderModel? activeOrder,
    UserRole role,
  ) {
    final isOccupied = table.status == TableStatus.terisi ||
        activeOrder != null ||
        widget.db.isTableTemporarilyOccupied(table.nomorMeja);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Modal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isOccupied ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.table_restaurant_rounded,
                    color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.nomorMeja,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'Kapasitas: ${table.kapasitas} Kursi · Status: ${isOccupied ? "Terisi" : "Kosong (Tersedia)"}',
                        style: TextStyle(fontSize: 12.5, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOccupied ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOccupied ? 'TERISI' : 'KOSONG',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Konten Detail
            if (isOccupied && activeOrder != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pesanan Aktif #${activeOrder.idOrder}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: context.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      activeOrder.status.label.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tamu: ${activeOrder.namaPelanggan.isNotEmpty ? activeOrder.namaPelanggan : "Tamu Meja"} · ${DateFormat("HH:mm, dd MMM yyyy", "id_ID").format(activeOrder.tanggal.toLocal())}',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: activeOrder.items.length,
                  separatorBuilder: (c, i) => const Divider(height: 8),
                  itemBuilder: (c, i) {
                    final item = activeOrder.items[i];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.jumlah}x ${item.menu.namaMasakan}',
                            style: TextStyle(fontSize: 12.5, color: context.textPrimary),
                          ),
                        ),
                        Text(
                          _currencyFmt.format(item.subtotal),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Tagihan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    _currencyFmt.format(activeOrder.grandTotalSetelahDiskon),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tombol Tindakan Cepat Terisi
              Row(
                children: [
                  if (role == UserRole.kasir || role == UserRole.administrator) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onNavigateToTab(1, tableNo: table.nomorMeja, target: 'cashier');
                        },
                        icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                        label: const Text('Proses Bayar Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (role == UserRole.waiter || role == UserRole.administrator) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.orangePrimary,
                          side: const BorderSide(color: AppTheme.orangeBorder),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onNavigateToTab(1, tableNo: table.nomorMeja, target: 'order');
                        },
                        icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                        label: const Text('Tambah Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ],
              ),
            ] else if (isOccupied) ...[
              // Meja Terisi (Jeda setelah pembayaran kasir / sedang bersantap)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFFEA580C), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pesanan telah diterima & diselesaikan oleh kasir. Meja berstatus terisi dan akan otomatis kembali kosong dalam jeda 5 menit.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF9A3412), height: 1.4),
                      ),
                    ),
                  ],
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
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onNavigateToTab(1, tableNo: table.nomorMeja, target: 'order');
                      },
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                      label: const Text('Mulai Pesanan Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.db.updateTableStatus(table.nomorMeja, TableStatus.kosong);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('Kosongkan Sekarang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ] else ...[
              // Meja Kosong
              Text(
                'Meja ini saat ini kosong dan siap digunakan oleh tamu restoran. Waiter dapat langsung memilih meja ini untuk mencatat pesanan tamu baru.',
                style: TextStyle(fontSize: 13, color: context.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orangePrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onNavigateToTab(1, tableNo: table.nomorMeja, target: 'order');
                      },
                      icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                      label: const Text('Mulai Entri Order Meja Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      TableQrViewerDialog.show(context, db: widget.db);
                    },
                    child: const Icon(Icons.qr_code_2_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ],
        ),
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

        final cardTotal = _buildSingleMetricCard(
          title: 'Total Meja',
          value: '$totalTables',
          icon: Icons.table_restaurant_rounded,
          color: const Color(0xFF0F172A),
          accentColor: const Color(0xFF64748B),
        );
        final cardEmpty = _buildSingleMetricCard(
          title: 'Meja Kosong',
          value: '$emptyCount',
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF16A34A),
          accentColor: const Color(0xFF16A34A),
        );
        final cardOccupied = _buildSingleMetricCard(
          title: 'Meja Terisi',
          value: '$occupiedCount',
          icon: Icons.restaurant_rounded,
          color: const Color(0xFFEA580C),
          accentColor: const Color(0xFFEA580C),
        );
        final cardActiveOrders = _buildSingleMetricCard(
          title: 'Pesanan Aktif',
          value: '$activeOrdersCount',
          icon: Icons.soup_kitchen_rounded,
          color: const Color(0xFF2563EB),
          accentColor: const Color(0xFF2563EB),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: cardTotal)),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: cardEmpty)),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: cardOccupied)),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: cardActiveOrders)),
            ],
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardTotal),
                  const SizedBox(width: 8),
                  Expanded(child: cardEmpty),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: cardOccupied),
                  const SizedBox(width: 8),
                  Expanded(child: cardActiveOrders),
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
                        'QR Code Meja',
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
    final timeStr = DateFormat('HH:mm').format(order.tanggal.toLocal());

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
