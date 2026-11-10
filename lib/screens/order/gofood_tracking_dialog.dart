import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../theme/app_theme.dart';

/// Dialog Tracking Pengantaran Driver ala GoFood / GrabFood dengan Live Map
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
    this.estimatedTime = '15 - 25 Menit',
  });

  static Future<void> show(
    BuildContext context, {
    required OrderModel order,
    required String destinationAddress,
    int deliveryFee = 8000,
    String estimatedTime = '15 - 25 Menit',
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
  int _activeStep = 2; // 0: Diterima, 1: Dimasak, 2: Driver jalan, 3: Selesai

  // Koordinat Restoran Rasantara (Pusat Kuliner)
  static const LatLng _restoPos = LatLng(-6.2088, 106.8456);
  // Koordinat Alamat Tujuan Pelanggan
  static const LatLng _custPos = LatLng(-6.2220, 106.8580);

  // Posisi Driver Dinamis (Bergerak sepanjang rute)
  late LatLng _driverPos;
  double _progress = 0.35; // 0.0 (di resto) s/d 1.0 (di rumah pelanggan)
  Timer? _movementTimer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _updateDriverLocation();

    // Simulasi pergerakan driver real-time
    _movementTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 0.08;
        if (_progress >= 1.0) {
          _progress = 1.0;
          _activeStep = 3;
          timer.cancel();
        }
        _updateDriverLocation();
      });
    });
  }

  void _updateDriverLocation() {
    final lat = _restoPos.latitude + (_custPos.latitude - _restoPos.latitude) * _progress;
    final lng = _restoPos.longitude + (_custPos.longitude - _restoPos.longitude) * _progress;
    _driverPos = LatLng(lat, lng);
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  Future<void> _chatDriverWhatsApp() async {
    const driverPhone = '6281298765432';
    final text = 'Halo Mas Budi Santoso (Driver Rasantara), saya pemesan Order #${widget.order.idOrder}. Lokasi saya di ${widget.destinationAddress}. Terima kasih!';
    final url = Uri.parse('https://wa.me/$driverPhone?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final remainingKm = ((1.0 - _progress) * 2.4).clamp(0.1, 2.4);
    final remainingMins = ((1.0 - _progress) * 18).round().clamp(1, 25);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pelacakan Driver Take Away',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Order #${widget.order.idOrder} • Sisa ${remainingKm.toStringAsFixed(1)} km (~$remainingMins mnt)',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── TAMPILAN PETA GOOGLE MAPS / OSM REAL-TIME ──
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(
                              (_restoPos.latitude + _custPos.latitude) / 2,
                              (_restoPos.longitude + _custPos.longitude) / 2,
                            ),
                            initialZoom: 14.5,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.rasantara.app',
                            ),
                            // Garis Rute Perjalanan
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [_restoPos, _driverPos, _custPos],
                                  strokeWidth: 4.0,
                                  color: const Color(0xFFEA580C),
                                ),
                              ],
                            ),
                            // Marker Peta
                            MarkerLayer(
                              markers: [
                                // 1. Restoran Rasantara
                                Marker(
                                  point: _restoPos,
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEA580C),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.restaurant, color: Colors.white, size: 18),
                                  ),
                                ),
                                // 2. Driver Bergerak
                                Marker(
                                  point: _driverPos,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                                    ),
                                    child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                                  ),
                                ),
                                // 3. Rumah Pelanggan
                                Marker(
                                  point: _custPos,
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                    ),
                                    child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Overlay Banner Status Driver di Peta
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: context.surfaceCard.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _progress >= 1.0
                                        ? 'Driver telah tiba di alamat tujuan!'
                                        : 'Driver sedang mengantar (${remainingKm.toStringAsFixed(1)} km lagi)',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: context.textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${(_progress * 100).toInt()}% Rute',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Kartu Info Driver & WhatsApp Contact
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFFEA580C),
                          child: Icon(Icons.person, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Budi Santoso (Driver Rasantara)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                  SizedBox(width: 2),
                                  Text(
                                    '4.9 • Honda Vario B 4821 KLO',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.chat_bubble_outline, size: 14),
                          label: const Text('Chat WA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _chatDriverWhatsApp,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stepper Status Pengantaran
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
                          title: 'Driver Mengantar Pesanan',
                          subtitle: 'Kurir sedang dalam perjalanan menuju alamat Anda',
                          icon: Icons.two_wheeler_rounded,
                        ),
                        _buildStepConnector(isDone: _activeStep >= 3),
                        _buildTrackingStep(
                          isDone: _activeStep >= 3,
                          isActive: _activeStep == 3,
                          title: 'Pesanan Sampai di Tujuan',
                          subtitle: 'Selamat menikmati sajian lezat Rasantara',
                          icon: Icons.home_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Detail Alamat Tujuan
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.fillSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Color(0xFFEA580C)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Alamat Pengantaran:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: context.textPrimary)),
                              const SizedBox(height: 2),
                              Text(
                                widget.destinationAddress,
                                style: TextStyle(fontSize: 11, color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                  color: isActive ? const Color(0xFFEA580C) : const Color(0xFF1E293B),
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
      height: 16,
      color: isDone ? const Color(0xFFEA580C) : const Color(0xFFCBD5E1),
    );
  }
}
