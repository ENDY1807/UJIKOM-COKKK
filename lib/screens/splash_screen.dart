import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onFinish;

  const SplashScreen({
    super.key,
    required this.db,
    required this.onFinish,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  String _loadingStatus = 'Menyiapkan sistem kasir...';
  int _statusStep = 0;
  Timer? _statusTimer;

  final List<String> _steps = [
    'Menyiapkan sistem kasir...',
    'Memuat katalog menu & meja...',
    'Menyelaraskan data lokal...',
    'Siap menyajikan pesanan...',
  ];

  @override
  void initState() {
    super.initState();

    _mainAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _mainAnimController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _mainAnimController, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _mainAnimController, curve: Curves.easeOutCubic),
    );

    _mainAnimController.forward();

    // Rotasi status persiapan
    _statusTimer = Timer.periodic(const Duration(milliseconds: 380), (timer) {
      if (!mounted) return;
      if (_statusStep < _steps.length - 1) {
        setState(() {
          _statusStep++;
          _loadingStatus = _steps[_statusStep];
        });
      }
    });

    // Durasi inisialisasi yang responsif dan smooth
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      _statusTimer?.cancel();
      widget.onFinish();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _mainAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAF9);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryOrange = AppTheme.orangePrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo Card Container dengan Efek Depth Artisanal
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryOrange.withValues(alpha: 0.16),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: primaryOrange,
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Brand Title & Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rasantara',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: primaryOrange.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'POS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: primaryOrange,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Brand Subtitle
                    Text(
                      'Sistem Kasir & Pemesanan Restoran Modern',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 36),

                    // Interactive Custom Loader Bar
                    Container(
                      width: 180,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final progress = (_statusStep + 1) / _steps.length;
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.clamp(0.15, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF97316),
                                    primaryOrange,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Dynamic Status Text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _loadingStatus,
                        key: ValueKey<String>(_loadingStatus),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Modern Micro-Footer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sistem Operasional Aktif • v3.0',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
