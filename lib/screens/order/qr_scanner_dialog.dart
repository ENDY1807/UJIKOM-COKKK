import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerDialog extends StatefulWidget {
  final Function(String scannedTable) onTableDetected;

  const QrScannerDialog({
    super.key,
    required this.onTableDetected,
  });

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QrScannerDialog(
        onTableDetected: (scanned) {
          Navigator.of(ctx).pop(scanned);
        },
      ),
    );
  }

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  late MobileScannerController _controller;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _cameraFacing,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        _hasScanned = true;
        final table = _parseTableCode(raw);
        widget.onTableDetected(table);
        break;
      }
    }
  }

  String _parseTableCode(String raw) {
    final lower = raw.trim().toLowerCase();
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.queryParameters.isNotEmpty) {
      if (uri.queryParameters.containsKey('table')) {
        return _formatTableNumber(uri.queryParameters['table']!);
      }
      if (uri.queryParameters.containsKey('meja')) {
        return _formatTableNumber(uri.queryParameters['meja']!);
      }
    }

    final reg = RegExp(r'(meja|table)[\s\-_:]*(\d+)', caseSensitive: false);
    final match = reg.firstMatch(lower);
    if (match != null) {
      final numStr = match.group(2) ?? '1';
      return 'Meja ${numStr.padLeft(2, '0')}';
    }

    final intOnly = int.tryParse(raw.trim());
    if (intOnly != null && intOnly > 0 && intOnly <= 99) {
      return 'Meja ${intOnly.toString().padLeft(2, '0')}';
    }

    if (lower.startsWith('meja')) {
      return raw.trim();
    }

    return 'Meja $raw';
  }

  String _formatTableNumber(String val) {
    final numVal = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
    if (numVal != null) {
      return 'Meja ${numVal.toString().padLeft(2, '0')}';
    }
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final boxSize = math.min(screenW * 0.72, 280.0);

    return Container(
      height: screenH * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFFEA580C),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pindai QR Meja Restoran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rasantara · Buka Menu & Meja Otomatis',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  child: MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (ctx, err) {
                      return Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off_outlined,
                                color: Color(0xFFEA580C),
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Kamera Belum Aktif atau Diizinkan',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Pastikan izin kamera sudah diberikan di pengaturan perangkat Anda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEA580C),
                                ),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Coba Lagi'),
                                onPressed: () {
                                  _controller.start();
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Center(
                  child: Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFEA580C), width: 4),
                                left: BorderSide(color: Color(0xFFEA580C), width: 4),
                              ),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Color(0xFFEA580C), width: 4),
                                right: BorderSide(color: Color(0xFFEA580C), width: 4),
                              ),
                              borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFEA580C), width: 4),
                                left: BorderSide(color: Color(0xFFEA580C), width: 4),
                              ),
                              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20)),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFEA580C), width: 4),
                                right: BorderSide(color: Color(0xFFEA580C), width: 4),
                              ),
                              borderRadius: BorderRadius.only(bottomRight: Radius.circular(20)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 84,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.crop_free_rounded, color: Color(0xFFEA580C), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Arahkan kamera ke QR Meja Restoran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: _isTorchOn ? const Color(0xFFEA580C) : Colors.white70,
                          ),
                          onPressed: () async {
                            await _controller.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                          tooltip: 'Lampu Senter',
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
                          onPressed: () async {
                            await _controller.switchCamera();
                            setState(() {
                              _cameraFacing = _cameraFacing == CameraFacing.back
                                  ? CameraFacing.front
                                  : CameraFacing.back;
                            });
                          },
                          tooltip: 'Ganti Kamera',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
