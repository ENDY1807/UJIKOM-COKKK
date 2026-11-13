import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

/// Komponen Visual Diagram & Grafik Analisis Restoran Rasantara
/// SELURUH DATA DIHITUNG SECARA DINAMIS DAN MURNI DARI DATABASE SUPABASE / POSTGRESQL.
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
    final totalOmzet = widget.db.totalOmzet;
    final totalTrx = transactions.length;
    final role = widget.db.currentUser?.role ?? UserRole.owner;

    // Jika belum ada data transaksi sama sekali di database
    if (transactions.isEmpty && orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: context.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderSubtle),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: const Icon(
                Icons.insights_rounded,
                size: 32,
                color: Color(0xFFEA580C),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Data Transaksi di Database',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Diagram analitik dihitung secara otomatis dan real-time dari data transaksi yang tersimpan di database Supabase / PostgreSQL. Selesaikan transaksi kasir atau import data seed SQL untuk melihat visualisasi data.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
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
    final revenueList = <_PeriodRevenue>[];
    String periodSubtitle = '';

    if (_periodFilter == RevenuePeriodFilter.perMinggu) {
      periodSubtitle = '7 Hari Terakhir';
      for (int i = 6; i >= 0; i--) {
        final targetDate = today.subtract(Duration(days: i));
        final nextDate = targetDate.add(const Duration(days: 1));

        final total = transactions.where((t) {
          return !t.tanggal.isBefore(targetDate) && t.tanggal.isBefore(nextDate);
        }).fold<int>(0, (sum, t) => sum + t.totalBayar);

        revenueList.add(_PeriodRevenue(
          date: targetDate,
          label: _getDayName(targetDate.weekday),
          revenue: total,
        ));
      }
    } else if (_periodFilter == RevenuePeriodFilter.perBulan) {
      periodSubtitle = '4 Minggu Terakhir';
      for (int w = 3; w >= 0; w--) {
        final startWeek = today.subtract(Duration(days: (w + 1) * 7 - 1));
        final endWeek = today.subtract(Duration(days: w * 7)).add(const Duration(days: 1));

        final total = transactions.where((t) {
          return !t.tanggal.isBefore(startWeek) && t.tanggal.isBefore(endWeek);
        }).fold<int>(0, (sum, t) => sum + t.totalBayar);

        revenueList.add(_PeriodRevenue(
          date: startWeek,
          label: 'Mgg ${4 - w}',
          revenue: total,
        ));
      }
    } else {
      periodSubtitle = '12 Bulan Terakhir';
      for (int m = 11; m >= 0; m--) {
        final monthDate = DateTime(now.year, now.month - m, 1);
        final nextMonthDate = DateTime(now.year, now.month - m + 1, 1);

        final total = transactions.where((t) {
          return !t.tanggal.isBefore(monthDate) && t.tanggal.isBefore(nextMonthDate);
        }).fold<int>(0, (sum, t) => sum + t.totalBayar);

        revenueList.add(_PeriodRevenue(
          date: monthDate,
          label: _getMonthName(monthDate.month),
          revenue: total,
        ));
      }
    }

    final maxRevenue = revenueList.fold<int>(
      0,
      (max, d) => d.revenue > max ? d.revenue : max,
    );

    final filteredTotalRevenue = revenueList.fold<int>(0, (sum, d) => sum + d.revenue);

    // ── 2. Hitung Distribusi Metode Pembayaran dari Database ──
    int qrisCount = 0;
    int tunaiCount = 0;
    int ewalletCount = 0;
    int debitCount = 0;

    for (final t in transactions) {
      final method = t.metodePembayaran.trim().toLowerCase();
      if (method.contains('qris')) {
        qrisCount++;
      } else if (method.contains('tunai') || method.contains('cash')) {
        tunaiCount++;
      } else if (method.contains('wallet') || method.contains('gopay') || method.contains('dana') || method.contains('ovo')) {
        ewalletCount++;
      } else {
        debitCount++;
      }
    }

    final qrisShare = totalTrx > 0 ? (qrisCount / totalTrx) : 0.0;
    final tunaiShare = totalTrx > 0 ? (tunaiCount / totalTrx) : 0.0;
    final ewalletShare = totalTrx > 0 ? (ewalletCount / totalTrx) : 0.0;
    final debitShare = totalTrx > 0 ? (debitCount / totalTrx) : 0.0;

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
    final maxSold = topMenus.isNotEmpty ? topMenus.first.value : 0;

    // ── WIDGETS KARTU ──

    // Card 1: Diagram Batang Penghasilan dengan Tombol Perminggu / Perbulan / Pertahun
    final revenueCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;

              final titleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Diagram Penghasilan ($periodSubtitle)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Periode: ${currencyFmt.format(filteredTotalRevenue)} • Keseluruhan: ${currencyFmt.format(totalOmzet)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEA580C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );

              final filterToggles = Container(
                decoration: BoxDecoration(
                  color: context.fillSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderSubtle),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: RevenuePeriodFilter.values.map((filter) {
                    final isSelected = _periodFilter == filter;
                    return InkWell(
                      onTap: () {
                        setState(() => _periodFilter = filter);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.orangePrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.orangePrimary.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          filter.label,
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

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: 12),
                    filterToggles,
                  ],
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
          ),
          const SizedBox(height: 24),

          // Visual Bar Chart Dinamis dari Database
          SizedBox(
            height: 180,
            child: _buildRealRevenueBarChart(revenueList, maxRevenue),
          ),
        ],
      ),
    );

    // Card 2: Diagram Donat Metode Pembayaran (Hanya Kasir, Owner, Admin)
    final paymentCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Diagram Metode Pembayaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Pembagian transaksi dari $totalTrx transaksi selesai di database',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              // Donut Chart Custom Painter Dinamis
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _PaymentDonutPainter(
                    qrisShare: qrisShare,
                    cashShare: tunaiShare,
                    ewalletShare: ewalletShare,
                    debitShare: debitShare,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalTrx',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          'Transaksi',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Legends dengan Data Nyata (QRIS, Tunai Kasir, E-Wallet, Kartu Debit)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(
                      'QRIS',
                      '${(qrisShare * 100).toStringAsFixed(0)}% ($qrisCount trx)',
                      const Color(0xFFEA580C),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      'Tunai Kasir',
                      '${(tunaiShare * 100).toStringAsFixed(0)}% ($tunaiCount trx)',
                      const Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      'E-Wallet (GoPay/DANA)',
                      '${(ewalletShare * 100).toStringAsFixed(0)}% ($ewalletCount trx)',
                      const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem(
                      'Kartu Debit / EDC',
                      '${(debitShare * 100).toStringAsFixed(0)}% ($debitCount trx)',
                      const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    // Card 3: Menu Best Seller (Menu Terlaris)
    final bestSellerCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
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
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Laporan Menu Best Seller',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Urutan menu masakan yang paling sering dipesan oleh pelanggan',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),

          if (topMenus.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Belum ada data menu yang terjual di database.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...topMenus.take(5).toList().asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final item = entry.value;
              final ratio = maxSold > 0 ? (item.value / maxSold) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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

    // ── STRUKTUR TAMPILAN BERDASARKAN ROLE PENGGUNA ──
    // Waiter: Menu Best Seller, Penghasilan (tanpa metode pembayaran & tanpa distribusi layanan)
    // Kasir / Owner / Admin: Penghasilan (dengan tombol filter waktu), Metode Pembayaran, Menu Best Seller
    if (role == UserRole.waiter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bestSellerCard,
          const SizedBox(height: 16),
          revenueCard,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        revenueCard,
        const SizedBox(height: 16),
        paymentCard,
        const SizedBox(height: 16),
        bestSellerCard,
      ],
    );
  }

  Widget _buildRealRevenueBarChart(List<_PeriodRevenue> periodData, int maxAmount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: periodData.map((d) {
        final ratio = maxAmount > 0 ? (d.revenue / maxAmount) : 0.0;
        final isMax = maxAmount > 0 && d.revenue == maxAmount;
        final barHeight = math.max(6.0, 110.0 * ratio);

        String displayAmount;
        if (d.revenue >= 1000000) {
          displayAmount = '${(d.revenue / 1000000).toStringAsFixed(1)}M';
        } else if (d.revenue >= 1000) {
          displayAmount = '${(d.revenue / 1000).round()}k';
        } else if (d.revenue > 0) {
          displayAmount = '${d.revenue}';
        } else {
          displayAmount = '0';
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    displayAmount,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                      color: isMax
                          ? const Color(0xFFEA580C)
                          : (d.revenue > 0 ? const Color(0xFF334155) : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: d.revenue > 0
                        ? LinearGradient(
                            colors: isMax
                                ? [const Color(0xFFFF7300), const Color(0xFFEA580C)]
                                : [const Color(0xFFFED7AA), const Color(0xFFFB923C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    color: d.revenue == 0 ? const Color(0xFFF1F5F9) : null,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: isMax
                        ? const [
                            BoxShadow(
                              color: Color(0x33EA580C),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    d.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isMax ? FontWeight.bold : FontWeight.w500,
                      color: isMax
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem(String label, String percent, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          percent,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
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
    Color rankColor = const Color(0xFF64748B);
    Color rankBg = const Color(0xFFF1F5F9);
    if (rank == 1) {
      rankColor = const Color(0xFFD97706);
      rankBg = const Color(0xFFFEF3C7);
    } else if (rank == 2) {
      rankColor = const Color(0xFF475569);
      rankBg = const Color(0xFFE2E8F0);
    } else if (rank == 3) {
      rankColor = const Color(0xFFB45309);
      rankBg = const Color(0xFFFFEDD5);
    }

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: rankBg,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: rankColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 6,
                  color: context.borderSubtle,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(color: const Color(0xFFEA580C)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          sales,
          style: TextStyle(
            fontSize: 11,
            color: context.textSecondary,
            fontWeight: FontWeight.w500,
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
        return 'Agu';
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

class _PeriodRevenue {
  final DateTime date;
  final String label;
  final int revenue;

  _PeriodRevenue({
    required this.date,
    required this.label,
    required this.revenue,
  });
}

/// Custom Painter Donut Chart Metode Pembayaran (Presisi Matematika Sudut)
class _PaymentDonutPainter extends CustomPainter {
  final double qrisShare;
  final double cashShare;
  final double ewalletShare;
  final double debitShare;

  _PaymentDonutPainter({
    required this.qrisShare,
    required this.cashShare,
    required this.ewalletShare,
    required this.debitShare,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Lingkaran abu latar jika tidak ada transaksi
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final total = qrisShare + cashShare + ewalletShare + debitShare;
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

    // Gambar segmen warna metode pembayaran
    drawSegment(qrisShare, const Color(0xFFEA580C));
    drawSegment(cashShare, const Color(0xFF16A34A));
    drawSegment(ewalletShare, const Color(0xFFD97706));
    drawSegment(debitShare, const Color(0xFF64748B));
  }

  @override
  bool shouldRepaint(covariant _PaymentDonutPainter oldDelegate) {
    return oldDelegate.qrisShare != qrisShare ||
        oldDelegate.cashShare != cashShare ||
        oldDelegate.ewalletShare != ewalletShare ||
        oldDelegate.debitShare != debitShare;
  }
}
