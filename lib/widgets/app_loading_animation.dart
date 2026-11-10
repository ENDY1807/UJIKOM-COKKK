import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Komponen animasi loading interaktif terinspirasi aplikasi Gojek & Rasantara
/// Menampilkan cincin rotasi aksen ganda dengan denyut (pulse) halus ikon kuliner
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
    this.primaryColor = const Color(0xFF00AA13), // Gojek Green
    this.secondaryColor = const Color(0xFFEA580C), // Rasantara Orange
    this.icon = Icons.restaurant_menu_rounded,
  });

  /// Dialog loading modal dengan animasi Gojek-style
  static void show(BuildContext context, {String message = 'Memproses...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLoadingAnimation(size: 60),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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

class _AppLoadingAnimationState extends State<AppLoadingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.15).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 0.85).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  // Cincin rotasi luar dengan aksen gradient Gojek Green & Rasantara Orange
                  Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _GojekRingPainter(
                        primaryColor: widget.primaryColor,
                        secondaryColor: widget.secondaryColor,
                      ),
                    ),
                  ),

                  // Ikon tengah yang berdenyut (Pulse & Bounce)
                  Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.size * 0.52,
                      height: widget.size * 0.52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.primaryColor.withAlpha(80),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: widget.size * 0.30,
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _GojekRingPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _GojekRingPainter({
    required this.primaryColor,
    required this.secondaryColor,
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
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.6;
    canvas.drawOval(rect, bgPaint);

    // Busur utama 1 (Gojek Green)
    final mainPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(rect, 0, 1.8 * math.pi * 0.65, false, mainPaint);

    // Busur kedua (Rasantara Orange accent)
    final secPaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.85;
    canvas.drawArc(rect, math.pi, math.pi * 0.35, false, secPaint);
  }

  @override
  bool shouldRepaint(covariant _GojekRingPainter oldDelegate) => false;
}

