import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });

  factory StatusBadge.fromStatus(String status) {
    switch (status.toLowerCase()) {
      case 'tersedia':
      case 'kosong':
      case 'selesai':
      case 'disajikan':
        return StatusBadge(
          label: status,
          textColor: AppTheme.statusGreen,
          backgroundColor: AppTheme.statusGreenBg,
        );
      case 'terisi':
      case 'diproses':
      case 'dimasak':
        return StatusBadge(
          label: status,
          textColor: AppTheme.orangePrimary,
          backgroundColor: AppTheme.orangeLight,
        );
      case 'reservasi':
      case 'menunggu':
        return StatusBadge(
          label: status,
          textColor: AppTheme.statusAmber,
          backgroundColor: AppTheme.statusAmberBg,
        );
      case 'habis':
      case 'dibatalkan':
      default:
        return StatusBadge(
          label: status,
          textColor: AppTheme.statusRed,
          backgroundColor: AppTheme.statusRedBg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
