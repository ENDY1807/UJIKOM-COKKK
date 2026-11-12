import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Komponen animasi loading interaktif Rasantara
/// Menampilkan double-arc spinner artisanal dengan ikon kuliner berdenyut halus
class AppLoadingAnimation extends StatefulWidget {
  final double size;
  final String? message;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData icon;

  const AppLoadingAnimation({
    super.key,
    this.size = 56.0,
    this.message,
    this.primaryColor = const Color(0xFFEA580C), // Rasantara Orange
    this.secondaryColor = const Color(0xFFF97316), // Warm Amber
    this.icon = Icons.restaurant_rounded,
  });

  /// Dialog loading modal dengan tema terpadu (Light & Dark mode aware)
  static void show(BuildContext context, {String message = 'Memproses...'}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLoadingAnimation(size: 58),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  State<AppLoadingAnimation> createState() => _AppLoadingAnimationState();
}

class _AppLoadingAnimationState extends State<AppLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.12)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 0.88)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final innerBg = isDark ? const Color(0xFF334155) : const Color(0xFFFFF7ED);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Double Orbital Arc Spinner
                  Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _ArtisanalSpinnerPainter(
                        primaryColor: widget.primaryColor,
                        secondaryColor: widget.secondaryColor,
                        trackColor: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),

                  // Center Culinary Icon dengan Soft Pulse
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.size * 0.52,
                      height: widget.size * 0.52,
                      decoration: BoxDecoration(
                        color: innerBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.primaryColor.withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.size * 0.28,
                        color: widget.primaryColor,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ArtisanalSpinnerPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;

  _ArtisanalSpinnerPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.085;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Track latar belakang lembut
    final bgPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.55;
    canvas.drawOval(rect, bgPaint);

    // Busur utama (Primary Color - Rasantara Orange)
    final mainPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 1.7 * math.pi * 0.65, false, mainPaint);

    // Busur aksen kedua (Secondary Color - Warm Amber)
    final secPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.75;
    canvas.drawArc(rect, math.pi, math.pi * 0.40, false, secPaint);
  }

  @override
  bool shouldRepaint(covariant _ArtisanalSpinnerPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.trackColor != trackColor;
}
