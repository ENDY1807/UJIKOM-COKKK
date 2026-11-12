import 'dart:async';
import 'dart:math' as math;
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
  late AnimationController _entranceController;
  late AnimationController _orbitController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  String _loadingStatus = 'Menyiapkan terminal kasir...';
  int _statusIndex = 0;
  Timer? _statusTimer;

  final List<String> _steps = [
    'Menyiapkan terminal kasir...',
    'Memuat katalog menu & denah meja...',
    'Sinkronisasi sistem transaksi...',
    'Sistem Rasantara siap digunakan!',
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 380), (timer) {
      if (!mounted) return;
      if (_statusIndex < _steps.length - 1) {
        setState(() {
          _statusIndex++;
          _loadingStatus = _steps[_statusIndex];
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      _statusTimer?.cancel();
      widget.onFinish();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _entranceController.dispose();
    _orbitController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = isDark
        ? const RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFF1E1B18),
              Color(0xFF0F172A),
              Color(0xFF090D16),
            ],
            stops: [0.0, 0.55, 1.0],
          )
        : const RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.25,
            colors: [
              Color(0xFFFFF7ED),
              Color(0xFFF8FAFC),
              Color(0xFFF1F5F9),
            ],
            stops: [0.0, 0.6, 1.0],
          );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),

                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_orbitController, _glowController]),
                          builder: (context, child) {
                            final glow = _glowController.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppTheme.orangePrimary.withValues(
                                          alpha: 0.18 + (glow * 0.16),
                                        ),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.4, 1.0],
                                    ),
                                  ),
                                ),

                                CustomPaint(
                                  size: const Size(160, 160),
                                  painter: _CulinaryOrbitPainter(
                                    rotation: _orbitController.value * 2 * math.pi,
                                    pulse: glow,
                                    primaryColor: AppTheme.orangePrimary,
                                    secondaryColor: const Color(0xFFF59E0B),
                                  ),
                                ),

                                Container(
                                  width: 108,
                                  height: 108,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.3 : 0.06,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Image.asset(
                                    'assets/images/Rasantara Cloche App Icon.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(
                                        Icons.restaurant_rounded,
                                        size: 46,
                                        color: AppTheme.orangePrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rasantara',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.orangePrimary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'POS RESTO',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Platform Kasir & Manajemen Meja Cerdas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 34),

                      Container(
                        width: 200,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedBuilder(
                          animation: _glowController,
                          builder: (context, child) {
                            final factor = ((_statusIndex + 1) / _steps.length)
                                .clamp(0.2, 1.0);
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: factor,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppTheme.orangePrimary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: Row(
                          key: ValueKey<String>(_loadingStatus),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: AppTheme.orangePrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _loadingStatus,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 3),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1A2234)
                              : Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.04,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Terminal Siap • Standar UJIKOM Nasional',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _CulinaryOrbitPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final Color primaryColor;
  final Color secondaryColor;

  _CulinaryOrbitPainter({
    required this.rotation,
    required this.pulse,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    final trackPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint1 = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor,
        ],
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      rotation,
      math.pi * 0.8,
      false,
      arcPaint1,
    );

    final orbitX = center.dx + radius * math.cos(rotation);
    final orbitY = center.dy + radius * math.sin(rotation);
    final dotPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(orbitX, orbitY), 3.5 + (pulse * 1.5), dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CulinaryOrbitPainter oldDelegate) => true;
}
