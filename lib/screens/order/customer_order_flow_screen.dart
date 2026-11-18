import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import 'order_entry_screen.dart';

/// Alur Khusus Pelanggan (Customer Self-Order Flow)
/// - Pelanggan TIDAK BISA membuka modul lain selain Entri Order.
/// - Tampilan awal mewajibkan Scan QR Meja terlebih dahulu.
/// - Setelah scan meja terdeteksi, menu makanan langsung terbuka untuk meja tersebut.
class CustomerOrderFlowScreen extends StatefulWidget {
  final DatabaseService db;
  final String? initialTableNo;
  final VoidCallback onLogout;

  const CustomerOrderFlowScreen({
    super.key,
    required this.db,
    this.initialTableNo,
    required this.onLogout,
  });

  @override
  State<CustomerOrderFlowScreen> createState() => _CustomerOrderFlowScreenState();
}

class _CustomerOrderFlowScreenState extends State<CustomerOrderFlowScreen> {
  String? _scannedTableNo;
  MobileScannerController? _scannerController;
  bool _isProcessing = false;
  bool _torchOn = false;

  bool get _isCameraSupportedPlatform =>
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.windows &&
          defaultTargetPlatform != TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _scannedTableNo = widget.initialTableNo;

    if (_isCameraSupportedPlatform) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  /// Ekstraksi nomor meja dari QR Code
  String? _parseTableFromRaw(String raw) {
    final clean = raw.trim();

    // 1. Cek format URL (misal: https://rasantara.app/order?table=Meja 02 atau ?meja=02)
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.hasQuery) {
      final tableParam = uri.queryParameters['table'] ??
          uri.queryParameters['meja'] ??
          uri.queryParameters['t'];
      if (tableParam != null && tableParam.isNotEmpty) {
        return _normalizeTableNumber(tableParam);
      }
    }

    // 2. Cek format kode sistem RASANTARA_TABLE_02
    if (clean.toUpperCase().startsWith('RASANTARA_TABLE_')) {
      final sub = clean.substring('RASANTARA_TABLE_'.length);
      return _normalizeTableNumber(sub);
    }

    // 3. Cek format teks langsung "Meja 01", "Meja 1", "01", "1"
    return _normalizeTableNumber(clean);
  }

  String _normalizeTableNumber(String input) {
    final clean = input.replaceAll('%20', ' ').trim();
    final match = RegExp(r'\d+').firstMatch(clean);
    if (match != null) {
      final numVal = int.tryParse(match.group(0) ?? '') ?? 1;
      return 'Meja ${numVal.toString().padLeft(2, '0')}';
    }
    return clean;
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final parsed = _parseTableFromRaw(raw);
        if (parsed != null && parsed.isNotEmpty) {
          _isProcessing = true;
          HapticFeedback.mediumImpact();

          setState(() {
            _scannedTableNo = parsed;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Berhasil terhubung ke $parsed', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );

          _isProcessing = false;
          break;
        }
      }
    }
  }

  void _showOrderSubmittedDialog(String tableNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Pesanan $tableNo Terkirim!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 8),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _scannedTableNo = null);
              },
              child: const Text('Selesai / Meja Baru'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orangePrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Pesan Tambahan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // JIKA MEJA TELAH DI-SCAN: TAMPILKAN ENTRI ORDER KHUSUS MEJA TERSEBUT
    if (_scannedTableNo != null && _scannedTableNo!.isNotEmpty) {
      return OrderEntryScreen(
        key: ValueKey('customer-order-$_scannedTableNo'),
        db: widget.db,
        initialTableNo: _scannedTableNo,
        onNavigateToTab: null,
        onRequestRescanTable: () {
          setState(() {
            _scannedTableNo = null;
          });
        },
        onOrderSubmitted: () {
          _showOrderSubmittedDialog(_scannedTableNo!);
        },
      );
    }

    // TAMPILAN AWAL PELANGGAN: SCAN QR MEJA
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Banner Informasi Scan QR Meja
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.isDarkMode
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFFFF7ED), const Color(0xFFFFFFFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.isDarkMode ? const Color(0xFF334155) : const Color(0xFFFFEDD5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.orangeBorder),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: AppTheme.orangePrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pindai QR Di Meja Anda',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Live Viewfinder Camera Scanner: Kotak kompak, border orange, garis sudut putih di dalam
              Center(
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.orangePrimary, width: 2.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: _isCameraSupportedPlatform && _scannerController != null
                            ? MobileScanner(
                                controller: _scannerController!,
                                fit: BoxFit.cover,
                                onDetect: _handleBarcode,
                                errorBuilder: (context, error) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.videocam_off_rounded,
                                            color: Color(0xFFEF4444),
                                            size: 36,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Kamera Tidak Aktif',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Izinkan akses kamera perangkat untuk memindai QR meja.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          color: Color(0xFFEA580C),
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Area Scanner QR Meja',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Kamera scanner aktif otomatis di Android & iOS.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),

                      // Garis Sudut Putih sebagai Penanda Area Scan (Tanpa Animasi)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _QrCornerFramePainter(
                              cornerColor: Colors.white,
                              cornerLength: 22.0,
                              strokeWidth: 3.0,
                              inset: 22.0,
                            ),
                          ),
                        ),
                      ),

                      // Tombol Senter / Torch & Ganti Kamera Depan / Belakang
                      if (_isCameraSupportedPlatform && _scannerController != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(32, 32),
                                ),
                                icon: Icon(
                                  _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                  color: _torchOn ? const Color(0xFFFBBF24) : Colors.white,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _scannerController?.toggleTorch();
                                  setState(() => _torchOn = !_torchOn);
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(32, 32),
                                ),
                                icon: const Icon(
                                  Icons.flip_camera_ios_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                tooltip: 'Ganti Kamera (Depan / Belakang)',
                                onPressed: () => _scannerController?.switchCamera(),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Mode Pengujian di Desktop Windows (Simulasi Scan)
              if (!_isCameraSupportedPlatform) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.fillSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: null,
                        hint: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.desktop_windows_rounded, size: 16, color: Color(0xFFEA580C)),
                            SizedBox(width: 8),
                            Text('Simulasi Scan Meja (Desktop Dev)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        items: widget.db.tables.map((t) {
                          return DropdownMenuItem(
                            value: t.nomorMeja,
                            child: Text('${t.nomorMeja} (${t.status.label})', style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _scannedTableNo = val);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 3. Keterangan petunjuk
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.fillSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 15, color: AppTheme.orangePrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Petunjuk Pemesanan:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Posisikan QR Code meja di dalam kotak sudut putih\n• Menu makanan & minuman langsung terbuka otomatis\n• Pesanan diantar oleh Waiter, pembayaran di Kasir saat selesai',
                      style: TextStyle(fontSize: 11.5, color: context.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter untuk menggambar 4 garis sudut siku putih sebagai penanda scan
class _QrCornerFramePainter extends CustomPainter {
  final Color cornerColor;
  final double cornerLength;
  final double strokeWidth;
  final double inset;

  const _QrCornerFramePainter({
    this.cornerColor = Colors.white,
    this.cornerLength = 22.0,
    this.strokeWidth = 3.0,
    this.inset = 22.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    // Top-Left ┌
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    // Top-Right ┐
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), paint);

    // Bottom-Left └
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), paint);

    // Bottom-Right ┘
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
