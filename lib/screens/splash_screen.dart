import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../widgets/app_loading_animation.dart';

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

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Panggil onFinish setelah animasi splash selesai (2.2 detik)
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      widget.onFinish();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      body: Stack(
        children: [
          // Background subtle warm glow circles
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEA580C).withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEA580C).withValues(alpha: 0.04),
              ),
            ),
          ),

          // Central Animated Branding
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'RASANTARA',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cita Rasa Kuliner Nusantara',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: Color(0xFFEA580C),
                  ),
                ),
                const SizedBox(height: 36),

                // Animasi Loading Interaktif Gojek & Rasantara Style
                const AppLoadingAnimation(
                  size: 42,
                  primaryColor: Color(0xFF00AA13),
                  secondaryColor: Color(0xFFEA580C),
                ),
              ],
            ),
          ),

          // Bottom Footer
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Digital Restaurant Ecosystem • v2.4.0',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
