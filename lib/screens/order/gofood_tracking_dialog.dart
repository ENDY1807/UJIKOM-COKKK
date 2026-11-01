import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../theme/app_theme.dart';

/// Dialog Tracking Pesanan ala Gojek (GoFood)
class GoFoodTrackingDialog extends StatefulWidget {
  final OrderModel order;
  final String destinationAddress;
  final int deliveryFee;
  final String estimatedTime;

  const GoFoodTrackingDialog({
    super.key,
    required this.order,
    required this.destinationAddress,
    this.deliveryFee = 8000,
    this.estimatedTime = '20 - 30 Menit',
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required String destinationAddress,
    int deliveryFee = 8000,
    String estimatedTime = '20 - 30 Menit',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoFoodTrackingDialog(
        order: order,
        destinationAddress: destinationAddress,
        deliveryFee: deliveryFee,
        estimatedTime: estimatedTime,
      ),
    );
  }

  @override
  State<GoFoodTrackingDialog> createState() => _GoFoodTrackingDialogState();
}

class _GoFoodTrackingDialogState extends State<GoFoodTrackingDialog> {
  final int _activeStep = 1; // 0: Diterima, 1: Dimasak, 2: Driver jalan, 3: Selesai

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // GoFood Banner Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delivery_dining,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengantaran Rasantara Delivery',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'No. Order: #${widget.order.idOrder} · Estimasi: ${widget.estimatedTime}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stepper Status Pengantaran ala GoFood
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildTrackingStep(
                  isDone: true,
                  isActive: _activeStep == 0,
                  title: 'Pesanan Diterima Restoran',
                  subtitle: 'Restoran Rasantara telah menerima pesanan Anda',
                  icon: Icons.check_circle_rounded,
                ),
                _buildStepConnector(isDone: _activeStep >= 1),
                _buildTrackingStep(
                  isDone: _activeStep >= 1,
                  isActive: _activeStep == 1,
                  title: 'Koki Menyiapkan Masakan',
                  subtitle: 'Menu Nusantara sedang dimasak segar di dapur',
                  icon: Icons.soup_kitchen_rounded,
                ),
                _buildStepConnector(isDone: _activeStep >= 2),
                _buildTrackingStep(
                  isDone: _activeStep >= 2,
                  isActive: _activeStep == 2,
                  title: 'Driver Menuju Alamat Anda',
                  subtitle: 'Pesanan dibawa oleh kurir pengantar',
                  icon: Icons.two_wheeler_rounded,
                ),
                _buildStepConnector(isDone: _activeStep >= 3),
                _buildTrackingStep(
                  isDone: _activeStep >= 3,
                  isActive: _activeStep == 3,
                  title: 'Pesanan Sampai di Rumah',
                  subtitle: 'Selamat menikmati hidangan Rasantara',
                  icon: Icons.home_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kartu Driver Partner ala GoFood
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFEA580C),
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budi Santoso (Driver Rasantara)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 14,
                          ),
                          SizedBox(width: 2),
                          Text(
                            '4.9 · Honda Vario B 4821 KLO',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tombol Chat WhatsApp / Telepon
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF16A34A),
                        content: Text(
                          'Menghubungkan ke WhatsApp Driver Budi Santoso...',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Detail Alamat Tujuan
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: Color(0xFFEA580C)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Antar ke: ${widget.destinationAddress}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStep({
    required bool isDone,
    required bool isActive,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isDone}) {
    return Container(
      margin: const EdgeInsets.only(left: 15),
      width: 2,
      height: 18,
      color: isDone ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
    );
  }
}
