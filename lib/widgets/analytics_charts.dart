import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

/// Opsi Filter Waktu untuk Diagram Laporan Penghasilan
enum RevenuePeriodFilter {
  perMinggu('Perminggu'),
  perBulan('Perbulan'),
  perTahun('Pertahun');

  final String label;
  const RevenuePeriodFilter(this.label);
}

/// Data Titik Grafik Per Periode Waktu
class PeriodRevenueData {
  final DateTime date;
  final String label;
  final int revenue;
  final int orderCount;
  final int qrisRevenue;
  final int cashRevenue;

  PeriodRevenueData({
    required this.date,
    required this.label,
    required this.revenue,
    this.orderCount = 0,
    this.qrisRevenue = 0,
    this.cashRevenue = 0,
  });
}

/// Data Titik untuk Diagram Garis & Area
class ChartDataPoint {
  final String label;
  final double value;
  final double secondaryValue;

  const ChartDataPoint({
    required this.label,
    required this.value,
    this.secondaryValue = 0.0,
  });
}

/// Helper Format Angka & Mata Uang Ringkas untuk Sumbu Sumbu Grafik
String _formatCompactCurrency(double val) {
  if (val >= 1000000000) {
    final m = val / 1000000000.0;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
  } else if (val >= 1000000) {
    final jt = val / 1000000.0;
    return '${jt.toStringAsFixed(jt.truncateToDouble() == jt ? 0 : 1)}jt';
  } else if (val >= 1000) {
    final rb = val / 1000.0;
    return '${rb.toStringAsFixed(rb.truncateToDouble() == rb ? 0 : 0)}rb';
  }
  return val.toInt().toString();
}

/// Komponen Visual Diagram & Grafik Analisis Restoran Rasantara
/// SELURUH DATA DIHITUNG SECARA DINAMIS DAN MURNI DARI DATABASE SUPABASE / POSTGRESQL.
/// Desain Simple, Bersih, Oranye-Putih (Tanpa Warna Neon).
class AnalyticsChartsWidget extends StatefulWidget {
  final DatabaseService db;

  const AnalyticsChartsWidget({super.key, required this.db});

  @override
  State<AnalyticsChartsWidget> createState() => _AnalyticsChartsWidgetState();
}

class _AnalyticsChartsWidgetState extends State<AnalyticsChartsWidget> {
  RevenuePeriodFilter _periodFilter = RevenuePeriodFilter.perMinggu;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final transactions = widget.db.transactions;
    final orders = widget.db.orders;
    final totalTrx = transactions.length;
    final role = widget.db.currentUser?.role ?? UserRole.owner;

    // Jika belum ada data transaksi sama sekali di database
    if (transactions.isEmpty && orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.orangeLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.orangeBorder),
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 28,
                color: AppTheme.orangePrimary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Belum Ada Data Transaksi di Database',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Diagram analitik dihitung otomatis dari transaksi kasir. Selesaikan transaksi kasir atau import data seed SQL untuk melihat grafik.',
              style: TextStyle(
                fontSize: 12.5,
                color: context.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ── 1. Hitung Omset Berdasarkan Filter Waktu (Perminggu, Perbulan, Pertahun) ──
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final revenueList = <PeriodRevenueData>[];
    String periodSubtitle = '';

    if (_periodFilter == RevenuePeriodFilter.perMinggu) {
      periodSubtitle = '7 Hari Terakhir';
      for (int i = 6; i >= 0; i--) {
        final targetDate = today.subtract(Duration(days: i));

        final matched = transactions.where((t) {
          final tl = t.tanggal.toLocal();
          return tl.year == targetDate.year &&
              tl.month == targetDate.month &&
              tl.day == targetDate.day;
        }).toList();

        final total = matched.fold<int>(0, (sum, t) => sum + t.totalBayar);
        final qris = matched
            .where(
              (t) => t.metodePembayaran.trim().toLowerCase().contains('qris'),
            )
            .fold<int>(0, (sum, t) => sum + t.totalBayar);
        final cash = matched
            .where(
              (t) => !t.metodePembayaran.trim().toLowerCase().contains('qris'),
            )
            .fold<int>(0, (sum, t) => sum + t.totalBayar);

        revenueList.add(
          PeriodRevenueData(
            date: targetDate,
            label: _getDayName(targetDate.weekday),
            revenue: total,
            orderCount: matched.length,
            qrisRevenue: qris,
            cashRevenue: cash,
          ),
        );
      }
    } else if (_periodFilter == RevenuePeriodFilter.perBulan) {
      periodSubtitle = '4 Minggu Terakhir';
      for (int w = 3; w >= 0; w--) {
        final startWeek = today.subtract(Duration(days: (w + 1) * 7 - 1));
        final endWeek = today.subtract(Duration(days: w * 7));

        final matched = transactions.where((t) {
          final tl = t.tanggal.toLocal();
          final tDate = DateTime(tl.year, tl.month, tl.day);
          return !tDate.isBefore(startWeek) && !tDate.isAfter(endWeek);
        }).toList();

        final total = matched.fold<int>(0, (sum, t) => sum + t.totalBayar);
        final qris = matched
            .where(
              (t) => t.metodePembayaran.trim().toLowerCase().contains('qris'),
            )
            .fold<int>(0, (sum, t) => sum + t.totalBayar);
        final cash = matched
            .where(
              (t) => !t.metodePembayaran.trim().toLowerCase().contains('qris'),
            )
            .fold<int>(0, (sum, t) => sum + t.totalBayar);

        revenueList.add(
          PeriodRevenueData(
            date: startWeek,
            label: 'Mgg ${4 - w}',
            revenue: total,
            orderCount: matched.length,
            qrisRevenue: qris,
            cashRevenue: cash,
          ),
        );
      }
    } else {
      periodSubtitle = '12 Bulan Terakhir';
      for (int m = 11; m >= 0; m--) {
        final monthDate = DateTime(now.year, now.month - m, 1);

        final matched = transactions.where((t) {
          final tl = t.tanggal.toLocal();
          return tl.year == monthDate.year && tl.month == monthDate.month;
        }).toList();

        final total = matched.fold<int>(0, (sum, t) => sum + t.totalBayar);
        final qris = matched
            .where(
              (t) => t.metodePembayaran.trim().toLowerCase().contains('qris'),
            )
            .fold<int>(0, (sum, t) => sum + t.totalBayar);
        final cash = matched
            .where(
              (t) => !t.metodePembayaran.trim().toLowerCase().contains('qris'),
            )
            .fold<int>(0, (sum, t) => sum + t.totalBayar);

        revenueList.add(
          PeriodRevenueData(
            date: monthDate,
            label: _getMonthName(monthDate.month),
            revenue: total,
            orderCount: matched.length,
            qrisRevenue: qris,
            cashRevenue: cash,
          ),
        );
      }
    }

    final filteredTotalRevenue = revenueList.fold<int>(
      0,
      (sum, d) => sum + d.revenue,
    );

    // ── 2. Hitung Distribusi Metode Pembayaran dari Database ──
    int qrisCount = 0;
    int tunaiCount = 0;
    int qrisTotal = 0;
    int tunaiTotal = 0;

    for (final t in transactions) {
      final method = t.metodePembayaran.trim().toLowerCase();
      if (method.contains('qris')) {
        qrisCount++;
        qrisTotal += t.totalBayar;
      } else {
        tunaiCount++;
        tunaiTotal += t.totalBayar;
      }
    }

    final qrisShare = totalTrx > 0 ? (qrisCount / totalTrx) : 0.0;
    final tunaiShare = totalTrx > 0 ? (tunaiCount / totalTrx) : 0.0;

    // ── 3. Hitung Peringkat Menu Terlaris dari Database ──
    final menuSalesMap = <String, int>{};
    if (transactions.isNotEmpty) {
      for (final t in transactions) {
        for (final item in t.order.items) {
          final name = item.menu.namaMasakan;
          menuSalesMap[name] = (menuSalesMap[name] ?? 0) + item.jumlah;
        }
      }
    } else {
      for (final o in orders) {
        for (final item in o.items) {
          final name = item.menu.namaMasakan;
          menuSalesMap[name] = (menuSalesMap[name] ?? 0) + item.jumlah;
        }
      }
    }

    final topMenus = menuSalesMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxSold = topMenus.isNotEmpty ? topMenus.first.value : 1;

    // ── 4. Card Header Filter Waktu ──
    final headerFilterSection = LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.show_chart_rounded,
                  color: AppTheme.orangePrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Laporan Grafik & Analitik',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Periode $periodSubtitle • Total Omzet: ${currencyFmt.format(filteredTotalRevenue)}',
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          ],
        );

        final filterToggles = Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: context.fillSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: RevenuePeriodFilter.values.map((f) {
              final isSelected = _periodFilter == f;
              return GestureDetector(
                onTap: () => setState(() => _periodFilter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.orangePrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    f.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected ? Colors.white : context.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleSection, const SizedBox(height: 12), filterToggles],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleSection),
            const SizedBox(width: 8),
            filterToggles,
          ],
        );
      },
    );

    // ── 5. Data Titik Omzet dari Database Sesuai Filter Waktu ──
    final revenuePoints = revenueList.map((d) {
      return ChartDataPoint(label: d.label, value: d.revenue.toDouble());
    }).toList();

    // Kartu Laporan Penghasilan (Area Chart Oranye Bersih)
    final cardPenghasilan = RasantaraAreaChartCard(
      title: 'Laporan Penghasilan',
      subtitle: currencyFmt.format(filteredTotalRevenue),
      dataPoints: revenuePoints,
      primaryColor: const Color(0xFFEA580C),
      height: 190,
      valueFormatter: (v) => _formatCompactCurrency(v),
    );

    // ── 6. Kartu Metode Pembayaran (Ditempatkan Bersebelahan dengan Laporan Penghasilan) ──
    Widget buildDonutContent() {
      return Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _PaymentDonutPainter(
                qrisShare: qrisShare,
                cashShare: tunaiShare,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalTrx',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      'Transaksi',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem(
                  'QRIS',
                  '${(qrisShare * 100).toStringAsFixed(0)}% • ${currencyFmt.format(qrisTotal)}',
                  const Color(0xFFEA580C),
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  'Tunai',
                  '${(tunaiShare * 100).toStringAsFixed(0)}% • ${currencyFmt.format(tunaiTotal)}',
                  const Color(0xFF2563EB),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget buildPaymentCard({required bool isExpanded}) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.pie_chart_outline_rounded,
                  color: AppTheme.orangePrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Proporsi dari $totalTrx transaksi kasir',
              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
            ),
            const SizedBox(height: 12),

            if (isExpanded)
              Expanded(
                child: Center(
                  child: buildDonutContent(),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: buildDonutContent(),
              ),
          ],
        ),
      );
    }

    // Section 2 Kolom: Laporan Penghasilan (Kiri) & Metode Pembayaran (Kanan)
    // Menggunakan IntrinsicHeight & CrossAxisAlignment.stretch agar kedua card memiliki tinggi yang SAMA PERSIS
    final revenueAndPaymentSection = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 780) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: cardPenghasilan),
                const SizedBox(width: 14),
                Expanded(flex: 10, child: buildPaymentCard(isExpanded: true)),
              ],
            ),
          );
        }

        return Column(
          children: [
            cardPenghasilan,
            const SizedBox(height: 14),
            buildPaymentCard(isExpanded: false),
          ],

        );
      },
    );

    // ── 7. Card Menu Best Seller ──
    final bestSellerCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.military_tech_rounded,
                color: AppTheme.orangePrimary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Menu Paling Laris (Best Seller)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Peringkat menu masakan berdasarkan frekuensi pesanan tamu',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 16),

          if (topMenus.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Belum ada data menu yang terjual di database.',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ),
            )
          else
            ...topMenus.take(5).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final ratio = maxSold > 0 ? (item.value / maxSold) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildTopMenuItem(
                  rank,
                  item.key,
                  '${item.value} Porsi Terjual',
                  ratio,
                ),
              );
            }),
        ],
      ),
    );

    // Tampilan Berdasarkan Peran
    if (role == UserRole.waiter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bestSellerCard,
          const SizedBox(height: 16),
          headerFilterSection,
          const SizedBox(height: 14),
          revenueAndPaymentSection,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerFilterSection,
        const SizedBox(height: 14),
        revenueAndPaymentSection,
        const SizedBox(height: 16),
        bestSellerCard,
      ],
    );
  }

  Widget _buildLegendItem(String label, String percent, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          percent,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTopMenuItem(
    int rank,
    String name,
    String sales,
    double progress,
  ) {
    Color rankColor = const Color(0xFF94A3B8);
    if (rank == 1) rankColor = const Color(0xFFEAB308);
    if (rank == 2) rankColor = const Color(0xFF94A3B8);
    if (rank == 3) rankColor = const Color(0xFFB45309);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              sales,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.orangePrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.05, 1.0),
            backgroundColor: context.fillSubtle,
            color: rank == 1 ? AppTheme.orangePrimary : const Color(0xFFFB923C),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Sen';
      case DateTime.tuesday:
        return 'Sel';
      case DateTime.wednesday:
        return 'Rab';
      case DateTime.thursday:
        return 'Kam';
      case DateTime.friday:
        return 'Jum';
      case DateTime.saturday:
        return 'Sab';
      case DateTime.sunday:
        return 'Min';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'Mei';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Ags';
      case 9:
        return 'Sep';
      case 10:
        return 'Okt';
      case 11:
        return 'Nov';
      case 12:
        return 'Des';
      default:
        return '$month';
    }
  }
}

/// Custom Painter Donut Chart Metode Pembayaran (Presisi Matematika Sudut)
class _PaymentDonutPainter extends CustomPainter {
  final double qrisShare;
  final double cashShare;

  _PaymentDonutPainter({required this.qrisShare, required this.cashShare});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final total = qrisShare + cashShare;
    if (total <= 0) return;

    double startAngle = -math.pi / 2;

    void drawSegment(double share, Color color) {
      if (share <= 0) return;
      final sweepAngle = (share / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    drawSegment(qrisShare, const Color(0xFFEA580C));
    drawSegment(cashShare, const Color(0xFF2563EB));
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter oldDelegate) {
    return oldDelegate.qrisShare != qrisShare ||
        oldDelegate.cashShare != cashShare;
  }
}

/// ══════════════════════════════════════════════════════════════════════════════
/// KARTU GRAFIK AREA SIMPLE ORANYE-PUTIH (SESUAI GAMBAR REFERENSI PENGGUNA)
/// ══════════════════════════════════════════════════════════════════════════════
/// Menampilkan:
/// - Judul kartu & Subtitle tebal putih/hitam
/// - Skala nilai sumbu Y di sebelah kiri (misal: 250%, 125%, 0%)
/// - Garis grid horizontal tipis membentang ke kanan
/// - Area fill kurva di bawah garis (gradient transparan halus)
/// - Garis kurva oranye / biru tanpa neon
/// - Indikator dual series di pojok kanan atas (seperti Network pada gambar referensi)
/// - Interaktif: Sentuh untuk melihat nilai titik
class RasantaraAreaChartCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<ChartDataPoint> dataPoints;
  final bool hasSecondarySeries;
  final String? primaryLegend;
  final String? secondaryLegend;
  final Color primaryColor;
  final Color secondaryColor;
  final String Function(double value) valueFormatter;
  final double height;

  const RasantaraAreaChartCard({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.dataPoints,
    this.hasSecondarySeries = false,
    this.primaryLegend,
    this.secondaryLegend,
    this.primaryColor = const Color(0xFFEA580C),
    this.secondaryColor = const Color(0xFF2563EB),
    required this.valueFormatter,
    this.height = 155,
  });

  @override
  State<RasantaraAreaChartCard> createState() => _RasantaraAreaChartCardState();
}

class _RasantaraAreaChartCardState extends State<RasantaraAreaChartCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Nilai aktif yang ditampilkan pada subtitle
    String displaySubtitle = widget.subtitle;
    if (_hoveredIndex != null &&
        _hoveredIndex! >= 0 &&
        _hoveredIndex! < widget.dataPoints.length) {
      final p = widget.dataPoints[_hoveredIndex!];
      if (widget.hasSecondarySeries) {
        displaySubtitle =
            '${p.label}: ${widget.valueFormatter(p.value)} (${widget.primaryLegend ?? 'QRIS'}) • ${widget.valueFormatter(p.secondaryValue)} (${widget.secondaryLegend ?? 'Tunai'})';
      } else {
        displaySubtitle = '${p.label}: ${widget.valueFormatter(p.value)}';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderSubtle),
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
          // Baris Header: Judul & Indikator Pojok Kanan Atas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              if (widget.hasSecondarySeries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.primaryLegend ?? 'QRIS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: widget.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.secondaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.secondaryLegend ?? 'Tunai',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: widget.secondaryColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            displaySubtitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _hoveredIndex != null
                  ? AppTheme.orangePrimary
                  : context.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Area Canvas Grafik
          GestureDetector(
            onPanUpdate: (details) => _updateTouch(details.localPosition),
            onPanDown: (details) => _updateTouch(details.localPosition),
            onPanEnd: (_) => setState(() => _hoveredIndex = null),
            onPanCancel: () => setState(() => _hoveredIndex = null),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _SimpleAreaChartPainter(
                  points: widget.dataPoints,
                  hasSecondarySeries: widget.hasSecondarySeries,
                  primaryColor: widget.primaryColor,
                  secondaryColor: widget.secondaryColor,
                  valueFormatter: widget.valueFormatter,
                  isDark: isDark,
                  selectedIndex: _hoveredIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateTouch(Offset pos) {
    if (widget.dataPoints.isEmpty) return;
    const leftMargin = 52.0;
    const rightMargin = 10.0;
    final totalWidth = context.size?.width ?? 300.0;
    final chartWidth = totalWidth - leftMargin - rightMargin;

    if (chartWidth <= 0) return;

    final xRatio = ((pos.dx - leftMargin) / chartWidth).clamp(0.0, 1.0);
    final idx = (xRatio * (widget.dataPoints.length - 1)).round();
    setState(() {
      _hoveredIndex = idx;
    });
  }
}

/// CustomPainter untuk Grafik Simple Area Sesuai Model Gambar Referensi
class _SimpleAreaChartPainter extends CustomPainter {
  final List<ChartDataPoint> points;
  final bool hasSecondarySeries;
  final Color primaryColor;
  final Color secondaryColor;
  final String Function(double value) valueFormatter;
  final bool isDark;
  final int? selectedIndex;

  _SimpleAreaChartPainter({
    required this.points,
    required this.hasSecondarySeries,
    required this.primaryColor,
    required this.secondaryColor,
    required this.valueFormatter,
    required this.isDark,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftMargin = 52.0;
    const rightMargin = 12.0;
    const topMargin = 28.0;
    const bottomMargin = 22.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // 1. Hitung Nilai Tertinggi
    double maxVal = 0.0;
    for (final p in points) {
      if (p.value > maxVal) maxVal = p.value;
      if (hasSecondarySeries && p.secondaryValue > maxVal) {
        maxVal = p.secondaryValue;
      }
    }
    if (maxVal <= 0) maxVal = 100.0;

    // 2. Garis Grid Horizontal & Label Sumbu Y (3 level: Max, Mid, 0)
    final gridLinePaint = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withValues(alpha: 0.5)
          : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final yAxisLabelStyle = TextStyle(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
    );

    final steps = [1.0, 0.5, 0.0];
    for (final step in steps) {
      final y = topMargin + chartHeight * (1.0 - step);

      // Garis grid horizontal
      canvas.drawLine(
        const Offset(leftMargin, 0).translate(0, y),
        Offset(size.width - rightMargin, y),
        gridLinePaint,
      );

      // Label teks di sebelah kiri garis
      final labelVal = maxVal * step;
      final labelText = valueFormatter(labelVal);
      final textPainter = TextPainter(
        text: TextSpan(text: labelText, style: yAxisLabelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Fungsi koordinat titik X dan Y
    final n = points.length;
    double getX(int i) {
      if (n <= 1) return leftMargin + chartWidth / 2;
      return leftMargin + (i / (n - 1)) * chartWidth;
    }

    double getY(double val) {
      final ratio = (val / maxVal).clamp(0.0, 1.0);
      return topMargin + chartHeight * (1.0 - ratio);
    }

    final baseline = topMargin + chartHeight;

    // Helper untuk menggambar area fill & garis kurva
    void drawSeries(List<double> vals, Color strokeColor) {
      final offsets = <Offset>[];
      for (int i = 0; i < vals.length; i++) {
        offsets.add(Offset(getX(i), getY(vals[i])));
      }

      if (offsets.isEmpty) return;

      final path = Path();
      path.moveTo(offsets[0].dx, offsets[0].dy);

      for (int i = 0; i < offsets.length - 1; i++) {
        final p0 = i > 0 ? offsets[i - 1] : offsets[i];
        final p1 = offsets[i];
        final p2 = offsets[i + 1];
        final p3 = i < offsets.length - 2 ? offsets[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
        double cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
        double cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;

        // Cegah kurva melengkung ke bawah menembus garis dasar 0 (Overshoot / sag)
        if (vals[i] == 0 && vals[i + 1] == 0) {
          cp1y = baseline;
          cp2y = baseline;
        } else {
          cp1y = cp1y.clamp(topMargin, baseline);
          cp2y = cp2y.clamp(topMargin, baseline);
        }

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }

      // Gradient Fill Area di bawah kurva
      final fillPath = Path.from(path)
        ..lineTo(offsets.last.dx, topMargin + chartHeight)
        ..lineTo(offsets.first.dx, topMargin + chartHeight)
        ..close();

      final fillPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                strokeColor.withValues(alpha: isDark ? 0.30 : 0.20),
                strokeColor.withValues(alpha: 0.01),
              ],
            ).createShader(
              Rect.fromLTWH(leftMargin, topMargin, chartWidth, chartHeight),
            );

      canvas.drawPath(fillPath, fillPaint);

      // Garis Stroke Kurva
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, strokePaint);
    }

    // Gambar Secondary Series terlebih dahulu jika ada (seperti Network pada referensi)
    if (hasSecondarySeries) {
      final secondaryVals = points.map((p) => p.secondaryValue).toList();
      drawSeries(secondaryVals, secondaryColor);
    }

    // Gambar Primary Series
    final primaryVals = points.map((p) => p.value).toList();
    drawSeries(primaryVals, primaryColor);

    // 3. Titik (Data Point Dots) & Label Nilai Penghasilan Permanen (Sudah Ada Tanpa Harus Ditekan)
    final dotBgPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white;
    final primaryDotPaint = Paint()..color = primaryColor;
    final secondaryDotPaint = Paint()..color = secondaryColor;

    final valTextStyle = TextStyle(
      color: isDark ? const Color(0xFFFFEDD5) : const Color(0xFFC2410C),
      fontSize: 8.5,
      fontWeight: FontWeight.bold,
    );

    for (int i = 0; i < points.length; i++) {
      final x = getX(i);
      final val = points[i].value;
      final y = getY(val);

      // Gambar titik untuk secondary series jika ada
      if (hasSecondarySeries) {
        final secY = getY(points[i].secondaryValue);
        canvas.drawCircle(Offset(x, secY), 3.5, dotBgPaint);
        canvas.drawCircle(Offset(x, secY), 2.0, secondaryDotPaint);
      }

      // Gambar titik data utama (primary series)
      final isHovered = selectedIndex == i;
      final dotRadius = isHovered ? 5.5 : 4.0;
      final innerRadius = isHovered ? 3.5 : 2.5;

      // Efek halo saat disentuh
      if (isHovered) {
        final haloPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.25);
        canvas.drawCircle(Offset(x, y), 8.5, haloPaint);
      }

      // Lingkaran luar (border) & lingkaran dalam (isi)
      canvas.drawCircle(Offset(x, y), dotRadius, dotBgPaint);
      canvas.drawCircle(Offset(x, y), innerRadius, primaryDotPaint);

      // ── Badge / Label Nilai Penghasilan di Atas Titik (Permanen Tanpa Ditekan) ──
      final valFormatted = valueFormatter(val);
      final textPainter = TextPainter(
        text: TextSpan(text: valFormatted, style: valTextStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      const pillPaddingH = 4.0;
      const pillPaddingV = 1.5;
      final pillWidth = textPainter.width + pillPaddingH * 2;
      final pillHeight = textPainter.height + pillPaddingV * 2;

      // Letakkan badge di atas titik secara konsisten
      double pillY = y - pillHeight - 5;
      if (pillY < 4) {
        pillY = 4;
      }
      final double pillX = (x - pillWidth / 2).clamp(
        leftMargin - 2,
        size.width - rightMargin - pillWidth + 2,
      );

      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
        const Radius.circular(4),
      );

      final pillBgPaint = Paint()
        ..color = isDark
            ? (isHovered
                ? const Color(0xFF9A3412)
                : const Color(0xFF1E293B).withValues(alpha: 0.92))
            : (isHovered
                ? const Color(0xFFFFEDD5)
                : Colors.white.withValues(alpha: 0.95));

      final pillBorderPaint = Paint()
        ..color = isHovered
            ? primaryColor
            : primaryColor.withValues(alpha: isDark ? 0.45 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? 1.0 : 0.6;

      canvas.drawRRect(pillRect, pillBgPaint);
      canvas.drawRRect(pillRect, pillBorderPaint);

      textPainter.paint(
        canvas,
        Offset(pillX + pillPaddingH, pillY + pillPaddingV),
      );
    }

    // 4. Label Sumbu X di Bawah (Hari / Tanggal / Bulan)
    final xAxisLabelStyle = TextStyle(
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i < points.length; i++) {
      final x = getX(i);
      final textPainter = TextPainter(
        text: TextSpan(text: points[i].label, style: xAxisLabelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, topMargin + chartHeight + 4),
      );
    }

    // 5. Highlight Posisi Sentuh (Selected Index Vertical Guide Line)
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final x = getX(selectedIndex!);

      final indicatorPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, topMargin + chartHeight),
        indicatorPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleAreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

/// Backward compatibility widget untuk kode yang memanggil NeonSplineRevenueChart
/// Kini dirender menggunakan desain Simple Oren-Putih Rasantara tanpa warna neon.
class NeonSplineRevenueChart extends StatelessWidget {
  final List<PeriodRevenueData> periodData;
  final NumberFormat currencyFmt;
  final String title;
  final String subtitle;

  const NeonSplineRevenueChart({
    super.key,
    required this.periodData,
    required this.currencyFmt,
    this.title = 'Laporan Omzet',
    this.subtitle = 'Tren Penjualan Restoran',
  });

  @override
  Widget build(BuildContext context) {
    final points = periodData.map((d) {
      return ChartDataPoint(
        label: d.label,
        value: d.revenue.toDouble(),
        secondaryValue: d.cashRevenue.toDouble(),
      );
    }).toList();

    return RasantaraAreaChartCard(
      title: title,
      subtitle: subtitle,
      dataPoints: points,
      valueFormatter: (val) => _formatCompactCurrency(val),
    );
  }
}
