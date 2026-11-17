import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/table_model.dart';
import '../services/database_service.dart';
import '../services/export_report_service.dart';
import '../theme/app_theme.dart';

/// Dialog Pemindai QR Meja (Table QR Scanner)
/// Mendukung:
/// 1. Pemindaian live camera menggunakan mobile_scanner
/// 2. Parsing format QR (URL deep link, teks Meja XX, atau kode RASANTARA_TABLE_XX)
/// 3. Fallback input / simulasi pilih meja (untuk web, emulator, atau perangkat tanpa kamera)
class TableQrScannerDialog extends StatefulWidget {
  final DatabaseService db;
  final void Function(String nomorMeja) onTableScanned;

  const TableQrScannerDialog({
    super.key,
    required this.db,
    required this.onTableScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required DatabaseService db,
    required void Function(String nomorMeja) onTableScanned,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TableQrScannerDialog(
        db: db,
        onTableScanned: onTableScanned,
      ),
    );
  }

  @override
  State<TableQrScannerDialog> createState() => _TableQrScannerDialogState();
}

class _TableQrScannerDialogState extends State<TableQrScannerDialog>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  bool _isProcessing = false;
  bool _torchOn = false;
  bool _showManualFallback = false;
  String? _selectedManualTable;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    final tables = widget.db.tables;
    if (tables.isNotEmpty) {
      _selectedManualTable = tables.first.nomorMeja;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Ekstraksi nomor meja dari hasil pembacaan QR Code
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
    var s = input.trim();
    if (s.toLowerCase().startsWith('meja')) {
      s = s.substring(4).trim();
    }
    final intNum = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    if (intNum != null) {
      final formatted = 'Meja ${intNum.toString().padLeft(2, '0')}';
      return formatted;
    }
    return input;
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final detectedTable = _parseTableFromRaw(rawValue);
        if (detectedTable != null && detectedTable.isNotEmpty) {
          _isProcessing = true;
          HapticFeedback.mediumImpact();
          _onSuccess(detectedTable);
          break;
        }
      }
    }
  }

  void _onSuccess(String tableNo) {
    Navigator.of(context).pop();
    widget.onTableScanned(tableNo);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Berhasil scan QR Meja: $tableNo. Selamat memesan!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tables = widget.db.tables;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 580),
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF00F2FE),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan QR Meja Restoran',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Pindai QR di meja Anda untuk memesan menu',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              // Scanner Area or Fallback
              Expanded(
                child: _showManualFallback
                    ? _buildManualSelector(tables)
                    : _buildLiveCameraScanner(),
              ),

              // Bottom Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF38E1FF),
                      ),
                      onPressed: () {
                        setState(() {
                          _showManualFallback = !_showManualFallback;
                        });
                      },
                      icon: Icon(
                        _showManualFallback
                            ? Icons.camera_alt_rounded
                            : Icons.touch_app_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _showManualFallback
                            ? 'Buka Kamera QR'
                            : 'Pilih Meja Manual',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup', style: TextStyle(fontSize: 12)),
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

  Widget _buildLiveCameraScanner() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: SizedBox.expand(
            child: MobileScanner(
              controller: _scannerController,
              fit: BoxFit.cover,
              onDetect: _handleBarcode,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          color: Color(0xFFEF4444),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Kamera Tidak Tersedia atau Ditolak',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Silakan gunakan fitur pilih meja manual di bawah.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F2FE),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                          onPressed: () {
                            setState(() => _showManualFallback = true);
                          },
                          icon: const Icon(Icons.touch_app_rounded, size: 16),
                          label: const Text(
                            'Pilih Meja Manual',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Darkened Mask with Center Square Cutout
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(),
            ),
          ),
        ),

        // Scanning Animation Line
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Positioned(
              top: 140 + (_animController.value * 180),
              child: Container(
                width: 220,
                height: 3,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFF00F2FE),
                      Color(0xFF38E1FF),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Camera Action Buttons
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
                icon: Icon(
                  _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _torchOn ? const Color(0xFFFBBF24) : Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  _scannerController.toggleTorch();
                  setState(() => _torchOn = !_torchOn);
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
                icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70, size: 20),
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ),

        // Helper text below scanning box
        const Positioned(
          bottom: 24,
          child: Center(
            child: Text(
              'Arahkan kotak ke stiker QR Meja Anda',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualSelector(List<TableModel> tables) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF38E1FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih nomor meja tempat Anda duduk untuk langsung memesan menu hidangan.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pilih Nomor Meja:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedManualTable,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
            items: tables.map((t) {
              final isOccupied = t.status == TableStatus.terisi;
              return DropdownMenuItem<String>(
                value: t.nomorMeja,
                child: Row(
                  children: [
                    Icon(
                      Icons.table_restaurant_rounded,
                      size: 16,
                      color: isOccupied ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${t.nomorMeja} (${t.kapasitas} Kursi) - ${t.status.label}',
                      style: TextStyle(
                        color: isOccupied ? const Color(0xFFFDE68A) : Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedManualTable = val);
              }
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orangePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_selectedManualTable != null) {
                _onSuccess(_selectedManualTable!);
              }
            },
            icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
            label: const Text(
              'Buka Menu Pesanan Meja Ini',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter untuk bingkai panduan scan QR dengan sudut glowing
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const scanBoxSize = 240.0;
    final left = (size.width - scanBoxSize) / 2;
    final top = (size.height - scanBoxSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanBoxSize, scanBoxSize);

    // Darkened Background Mask
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(18)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    // Glowing Corners
    final cornerPaint = Paint()
      ..color = const Color(0xFF00F2FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    final r = scanRect;

    // Top-Left
    canvas.drawLine(Offset(r.left, r.top + cornerLength), Offset(r.left, r.top + 10), cornerPaint);
    canvas.drawLine(Offset(r.left, r.top + 10), Offset(r.left + 10, r.top), cornerPaint);
    canvas.drawLine(Offset(r.left + 10, r.top), Offset(r.left + cornerLength, r.top), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(r.right - cornerLength, r.top), Offset(r.right - 10, r.top), cornerPaint);
    canvas.drawLine(Offset(r.right - 10, r.top), Offset(r.right, r.top + 10), cornerPaint);
    canvas.drawLine(Offset(r.right, r.top + 10), Offset(r.right, r.top + cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLength), Offset(r.left, r.bottom - 10), cornerPaint);
    canvas.drawLine(Offset(r.left, r.bottom - 10), Offset(r.left + 10, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.left + 10, r.bottom), Offset(r.left + cornerLength, r.bottom), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(r.right - cornerLength, r.bottom), Offset(r.right - 10, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right - 10, r.bottom), Offset(r.right, r.bottom - 10), cornerPaint);
    canvas.drawLine(Offset(r.right, r.bottom - 10), Offset(r.right, r.bottom - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dialog untuk Menampilkan / Mencetak QR Meja Restoran (Untuk Admin, Waiter, & Pelanggan)
class TableQrViewerDialog extends StatefulWidget {
  final DatabaseService db;
  final String? initialTableNo;

  const TableQrViewerDialog({
    super.key,
    required this.db,
    this.initialTableNo,
  });

  static Future<void> show(
    BuildContext context, {
    required DatabaseService db,
    String? initialTableNo,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => TableQrViewerDialog(
        db: db,
        initialTableNo: initialTableNo,
      ),
    );
  }

  @override
  State<TableQrViewerDialog> createState() => _TableQrViewerDialogState();
}

class _TableQrViewerDialogState extends State<TableQrViewerDialog> {
  late String _currentTable;

  @override
  void initState() {
    super.initState();
    _currentTable = widget.initialTableNo ??
        (widget.db.tables.isNotEmpty ? widget.db.tables.first.nomorMeja : 'Meja 01');
  }

  @override
  Widget build(BuildContext context) {
    final tables = widget.db.tables;
    final currentTableObj = tables.firstWhere(
      (t) => t.nomorMeja == _currentTable,
      orElse: () => TableModel(idMeja: 1, nomorMeja: _currentTable, kapasitas: 4),
    );

    final qrData = 'https://rasantara.app/order?table=$_currentTable';

    return Dialog(
      backgroundColor: context.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: AppTheme.orangePrimary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'QR Code Meja',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currentTable,
              decoration: const InputDecoration(
                labelText: 'Pilih Meja untuk QR',
                prefixIcon: Icon(Icons.table_restaurant_rounded),
              ),
              items: tables.map((t) {
                return DropdownMenuItem(
                  value: t.nomorMeja,
                  child: Text('${t.nomorMeja} (${t.kapasitas} Orang)'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _currentTable = val);
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentTable,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Kapasitas: ${currentTableObj.kapasitas} Tamu • Table Service',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Pelanggan dapat memindai QR Code ini menggunakan kamera ponsel mereka untuk langsung membuka menu dan memesan makanan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      try {
                        final path = await ExportReportService.downloadTableQrImagePng(currentTableObj);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(path != null
                                        ? 'Gambar QR ${currentTableObj.nomorMeja}.png disimpan di folder Downloads!'
                                        : 'Gambar QR ${currentTableObj.nomorMeja}.png berhasil diunduh!'),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal mengunduh gambar: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text('Unduh PNG'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orangePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      try {
                        final path = await ExportReportService.downloadTableQrStickerPdf(currentTableObj);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(path != null
                                        ? 'Stiker PDF ${currentTableObj.nomorMeja} disimpan di folder Downloads!'
                                        : 'Stiker PDF ${currentTableObj.nomorMeja} siap dicetak!'),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal membuat stiker PDF: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Cetak / PDF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
