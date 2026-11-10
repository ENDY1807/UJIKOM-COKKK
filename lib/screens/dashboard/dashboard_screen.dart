import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../models/user_model.dart';
import '../../models/event_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/analytics_charts.dart';
import '../../widgets/menu_detail_dialog.dart';
import '../../widgets/order_tracker_sheet.dart';

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
  late PageController _heroCarouselController;
  int _currentHeroIndex = 0;

  @override
  void initState() {
    super.initState();
    _heroCarouselController = PageController(initialPage: 0);
    // Sinkronkan data event terkini langsung dari Supabase saat membuka Beranda
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.db.refreshEvents();
    });
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
    _heroCarouselController.dispose();
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
      body: RefreshIndicator(
        color: const Color(0xFFEA580C),
        onRefresh: () async {
          await widget.db.refreshEvents();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero Header ──
              _buildHeroHeader(user, role, greeting),
              const SizedBox(height: 20),

              // ── Metric Cards (Khusus Role Manajemen / Staff: Admin, Waiter, Kasir, Owner. Disembunyikan untuk Pelanggan) ──
              if (role != UserRole.pelanggan) ...[
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
          ],

          // ── Menu Best Seller & Rekomendasi + Promo Voucher & Kategori / Antrean Pesanan ──
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final secondaryWidget = role == UserRole.pelanggan
                    ? _buildCustomerPromoAndCategoriesSection(fmt)
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
                        child: secondaryWidget,
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildBestSellerSection(role, fmt),
                    const SizedBox(height: 16),
                    secondaryWidget,
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
    ),
  );
}

  // ── Hero Header Carousel (TikTok-style Swipe: Ucapan Selamat -> Poin -> Event) ──────
  Widget _buildHeroHeader(dynamic user, UserRole role, String greeting) {
    final isOwner = role == UserRole.owner;
    final events = widget.db.events;
    final totalSlides = 2 + events.length + (isOwner ? 1 : 0);

    return FadeTransition(
      opacity: _cardAnimations[0],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.1),
          end: Offset.zero,
        ).animate(_cardAnimations[0]),
        child: Column(
          children: [
            SizedBox(
              height: 195,
              child: PageView(
                controller: _heroCarouselController,
                onPageChanged: (idx) {
                  setState(() => _currentHeroIndex = idx);
                },
                children: [
                  // Slide 1 (Default): Ucapan Selamat & Welcome
                  _buildWelcomeSlide(user, role, greeting),

                  // Slide 2: Poin Loyalitas & Rewards Rasantara
                  _buildPointsSlide(user),

                  // Slide 3+: Event & Promosi Restoran dari SQL
                  ...events.map((event) => _buildEventSlide(event, isOwner: isOwner)),

                  // Extra Slide jika Owner: Tombol Tambah Event
                  if (isOwner) _buildAddEventSlide(),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Indikator Titik Carousel (TikTok-style dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalSlides, (index) {
                final isActive = _currentHeroIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isActive ? 22 : 6,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Ucapan Selamat (Selamat Pagi / Siang / Malam)
  Widget _buildWelcomeSlide(dynamic user, UserRole role, String greeting) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7300), Color(0xFFEA580C), Color(0xFFCC4A0B)],
        ),
        borderRadius: BorderRadius.circular(22),
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
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        (user?.namaUser ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting,',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          user?.namaUser ?? 'Pelanggan Rasantara',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${role.label} · Rasantara Resto',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe_rounded, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Geser untuk Poin & Event >',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFEA580C),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => widget.onNavigateToTab(1),
                    child: const Text('Buka Menu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 2: Poin Loyalitas & Rewards Rasantara
  Widget _buildPointsSlide(dynamic user) {
    final points = (widget.db.orders.where((o) => o.idUser == user?.idUser).length * 150) + 250;
    final rupiahDiscount = points * 100;
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'POIN KULINER RASANTARA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.white, size: 11),
                    SizedBox(width: 3),
                    Text('Member Aktif', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$points Poin',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                'Setara ${fmt.format(rupiahDiscount)} potongan transaksi pesanan Anda',
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_task_rounded, size: 14, color: Color(0xFF38BDF8)),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '+150 Poin / transaksi',
                        style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF16A34A),
                      content: Text('Poin Anda dapat langsung dipotongkan saat memesan makanan! (Saldo Poin: $points)'),
                    ),
                  );
                  widget.onNavigateToTab(1);
                },
                child: const Text('Gunakan Poin', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 3+: Event & Promosi Restoran dari SQL
  Widget _buildEventSlide(EventModel event, {required bool isOwner}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C1D95), Color(0xFF5B21B6), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'EVENT RESTORAN AKTIF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Diskon ${event.diskonPersen}%',
                  style: const TextStyle(color: Color(0xFF4C1D95), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.judulEvent,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                event.deskripsi,
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (event.kodePromo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    'KODE: ${event.kodePromo}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              else
                const SizedBox(),
              Row(
                children: [
                  if (isOwner)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 18),
                      tooltip: 'Hapus Event (Owner)',
                      onPressed: () => widget.db.deleteEvent(event.idEvent),
                    ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4C1D95),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => widget.onNavigateToTab(1),
                    child: const Text('Klaim Promo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Slide Tambah Event (Khusus Owner)
  Widget _buildAddEventSlide() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_circle_outline_rounded, size: 32, color: Color(0xFFEA580C)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kelola & Buat Event Baru',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),
          const Text(
            'Khusus Owner: Terbitkan promo & diskon baru ke seluruh pelanggan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Event Baru', style: TextStyle(fontSize: 11.5)),
            onPressed: () => _showCreateEventDialog(context),
          ),
        ],
      ),
    );
  }

  // Modal Dialog Pembuatan Event Baru (Khusus Owner)
  void _showCreateEventDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final promoCtrl = TextEditingController();
    int discountPct = 15;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Text('Buat Event Restoran Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hanya akun Owner yang memiliki otoritas untuk menerbitkan event & promosi ke beranda seluruh pelanggan.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul Event *',
                    hintText: 'Misal: Promo Spesial Weekend',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Event & Ketentuan *',
                    hintText: 'Potongan 20% untuk semua masakan olahan sapi...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: promoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Kode Promo',
                    hintText: 'Misal: WEEKENDHEMAT',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Besaran Diskon:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('$discountPct%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFEA580C))),
                  ],
                ),
                Slider(
                  value: discountPct.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  activeColor: const Color(0xFFEA580C),
                  onChanged: (val) => setDlgState(() => discountPct = val.round()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                  return;
                }
                final newEvent = EventModel(
                  idEvent: 0,
                  judulEvent: titleCtrl.text.trim(),
                  deskripsi: descCtrl.text.trim(),
                  kodePromo: promoCtrl.text.trim().toUpperCase(),
                  diskonPersen: discountPct,
                  tanggalMulai: DateTime.now(),
                  tanggalSelesai: DateTime.now().add(const Duration(days: 14)),
                  createdBy: 'owner',
                );
                final success = await widget.db.addEvent(newEvent);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      content: Text(success ? 'Event promosi berhasil diterbitkan ke Beranda!' : 'Gagal membuat event.'),
                    ),
                  );
                }
              },
              child: const Text('Terbitkan Event'),
            ),
          ],
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
                      ? '#1 Terlaris'
                      : rank == 2
                          ? '#2 Favorit'
                          : rank == 3
                              ? '#3 Rekomendasi'
                              : 'Menu Pilihan';
                  final badgeIcon = rank == 1
                      ? Icons.local_fire_department_rounded
                      : rank == 2
                          ? Icons.star_rounded
                          : rank == 3
                              ? Icons.thumb_up_rounded
                              : Icons.verified_rounded;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        MenuDetailDialog.show(
                          context,
                          menu: menu,
                          onConfirm: (quantity, note) {
                            widget.onNavigateToTab(1);
                          },
                        );
                      },
                      child: Container(
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(badgeIcon, size: 10, color: Colors.white),
                                        const SizedBox(width: 3),
                                        Text(
                                          badgeLabel,
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
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
                                        onPressed: () {
                                          MenuDetailDialog.show(
                                            context,
                                            menu: menu,
                                            onConfirm: (quantity, note) {
                                              widget.onNavigateToTab(1);
                                            },
                                          );
                                        },
                                        child: const Text('Detail & Pesan', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  Widget _menuPlaceholder() {
    return Container(
      color: const Color(0xFFFFF7ED),
      child: const Center(
        child: Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C), size: 28),
      ),
    );
  }

  // ── Voucher Promo & Kategori Kuliner (Pengganti Pantau Pesanan di Beranda) ──
  Widget _buildCustomerPromoAndCategoriesSection(NumberFormat fmt) {
    final vouchers = [
      {
        'tag': '30% OFF',
        'title': 'Pesta Rasa Akhir Pekan',
        'desc': 'Min. transaksi Rp 40.000',
        'code': 'RASANTARA30',
        'bg': const Color(0xFFFFF7ED),
        'border': const Color(0xFFFFEDD5),
        'tagColor': const Color(0xFFEA580C),
      },
      {
        'tag': 'Rp 15RB',
        'title': 'Diskon Pelanggan Setia',
        'desc': 'Min. transaksi Rp 30.000',
        'code': 'HEMAT15K',
        'bg': const Color(0xFFFFF7ED),
        'border': const Color(0xFFFFEDD5),
        'tagColor': const Color(0xFFEA580C),
      },
      {
        'tag': 'GRATIS',
        'title': 'Bebas Ongkir Pengantaran',
        'desc': 'Min. transaksi Rp 20.000',
        'code': 'BEBASONGKIR',
        'bg': const Color(0xFFF0FDF4),
        'border': const Color(0xFFDCFCE7),
        'tagColor': const Color(0xFF16A34A),
      },
    ];

    final categories = [
      {
        'title': 'Aneka Nasi & Lauk',
        'desc': 'Rendang, Ayam Goreng, Nasi Uduk',
        'icon': Icons.rice_bowl_rounded,
      },
      {
        'title': 'Olahan Mie & Bakso',
        'desc': 'Mie Goreng Jawa, Bakso Sapi Kuah',
        'icon': Icons.ramen_dining_rounded,
      },
      {
        'title': 'Minuman Tradisional',
        'desc': 'Es Cendol, Es Kelapa, Teh Tarik',
        'icon': Icons.local_cafe_rounded,
      },
      {
        'title': 'Camilan & Gorengan',
        'desc': 'Pisang Crispy, Tahu Gejrot, Tempe Mendoan',
        'icon': Icons.bakery_dining_rounded,
      },
    ];

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
          // ── Header Voucher Promo ──
          Row(
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
                        Icons.confirmation_num_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Voucher & Kupon Hemat',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Klaim voucher spesial pesanan Anda',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
              InkWell(
                onTap: () => widget.onNavigateToTab(1),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Lihat Menu',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── List Voucher Hemat ──
          ...vouchers.map((v) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: v['bg'] as Color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: v['border'] as Color),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: v['border'] as Color),
                    ),
                    child: Text(
                      v['tag'] as String,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: v['tagColor'] as Color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v['title'] as String,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${v['desc']} · Kode: ${v['code']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Kupon ${v['code']} siap digunakan pada pesanan Anda!'),
                          backgroundColor: const Color(0xFFEA580C),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      widget.onNavigateToTab(1);
                    },
                    child: const Text(
                      'Pakai',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: Color(0xFFE2E8F0)),
          ),

          // ── Header Kategori Pilihan ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kategori Menu Pilihan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Jelajahi beragam cita rasa kuliner Nusantara',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Grid / List Kategori ──
          ...categories.map((c) {
            return InkWell(
              onTap: () => widget.onNavigateToTab(1),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        c['icon'] as IconData,
                        color: const Color(0xFFEA580C),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['title'] as String,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c['desc'] as String,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (activeOrders.isNotEmpty && activeOrders.first is OrderModel) {
                          showOrderTrackerModal(
                            context,
                            db: widget.db,
                            order: activeOrders.first as OrderModel,
                            onNavigateToTab: widget.onNavigateToTab,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak ada antrean pesanan aktif saat ini.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.receipt_long_rounded,
                        size: 14,
                        color: Color(0xFFEA580C),
                      ),
                      label: const Text(
                        'Pantau Pesanan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                    if (role.canProcessTransactions) ...[
                      const SizedBox(width: 6),
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
                  ],
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
