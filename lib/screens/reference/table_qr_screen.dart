import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
import '../../services/export_report_service.dart';
import '../../theme/app_theme.dart';

/// Layar Pembuatan dan Pencetakan QR Code Meja Restoran Rasantara.
/// Dapat diakses oleh Admin, Kasir, dan Owner untuk menghasilkan standing card meja.
class TableQrScreen extends StatefulWidget {
  final DatabaseService db;

  const TableQrScreen({super.key, required this.db});

  @override
  State<TableQrScreen> createState() => _TableQrScreenState();
}

class _TableQrScreenState extends State<TableQrScreen> {
  String? _selectedTableNo;
  final TextEditingController _newTableNoController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    if (widget.db.tables.isNotEmpty) {
      _selectedTableNo = widget.db.tables.first.nomorMeja;
    }
  }

  @override
  void dispose() {
    _newTableNoController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _addNewTable() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_business_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Tambah Meja Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newTableNoController,
              decoration: const InputDecoration(
                labelText: 'Nomor / Nama Meja',
                hintText: 'Masukkan Nomor Meja',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _capacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kapasitas Kursi',
                hintText: 'Masukkan Kapasitas Kursi',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            onPressed: () {
              final no = _newTableNoController.text.trim();
              final cap = int.tryParse(_capacityController.text.trim()) ?? 4;
              if (no.isNotEmpty) {
                widget.db.addTable(no, cap);
                setState(() => _selectedTableNo = no);
                Navigator.of(ctx).pop();
                _newTableNoController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF16A34A),
                    content: Text('✓ $no berhasil ditambahkan & siap cetak QR!'),
                  ),
                );
              }
            },
            child: const Text('Simpan Meja'),
          ),
        ],
      ),
    );
  }

  void _showPrintPreviewDialog(String tableNo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Kartu Fisik Standing Tent Card Preview
              _buildQrPrintCard(tableNo),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Cetak Dokumen'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF16A34A),
                          content: Text('✓ Menyiapkan & mengunduh berkas QR Card $tableNo...'),
                        ),
                      );
                      await ExportReportService.exportTableQrPdf(
                        tableNo: tableNo,
                        restaurantName: 'Rasantara Restoran',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrPrintCard(String tableNo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo & Nama Restoran
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'RASANTARA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'KULINER KHAS NUSANTARA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),

          // Label Meja Menonjol
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: Text(
              tableNo.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEA580C),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Komponen QR Code Aktual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: QrImageView(
              data: tableNo,
              version: QrVersions.auto,
              size: 160.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1E293B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Instruksi Pemesan
          const Text(
            'Pindai QR ini dengan kamera HP\nuntuk memesan menu langsung dari meja.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          // Info Fasilitas WiFi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 12, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Text(
                  'WiFi: Rasantara-Guest (Pass: rasasenang)',
                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tables = widget.db.tables;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFFEA580C), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola & Cetak QR Meja',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        Text(
                          'Cetak QR standing acrylic untuk setiap meja makan',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: const Color(0xFFFFF7ED),
                      foregroundColor: const Color(0xFFEA580C),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Tambah Meja', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _addNewTable,
                  ),
                ],
              ),
            ),

            // Content Area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 760;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left List of Tables
                        SizedBox(
                          width: 320,
                          child: _buildTableSelectionList(tables),
                        ),
                        const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                        // Right Live Card Preview & Print Action
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedTableNo != null) ...[
                                    _buildQrPrintCard(_selectedTableNo!),
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFEA580C),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.print_rounded, size: 18),
                                      label: Text(
                                        'Cetak QR Stand ($_selectedTableNo)',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      onPressed: () => _showPrintPreviewDialog(_selectedTableNo!),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile View
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Active selected QR preview
                      if (_selectedTableNo != null) ...[
                        _buildQrPrintCard(_selectedTableNo!),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: Text(
                            'Cetak QR Card ($_selectedTableNo)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showPrintPreviewDialog(_selectedTableNo!),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const Text(
                        'Daftar Seluruh Meja Restoran:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 8),
                      ...tables.map((t) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedTableNo == t.nomorMeja
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.table_bar_rounded, color: Color(0xFFEA580C)),
                              title: Text(t.nomorMeja, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${t.kapasitas} Kursi · Status: ${t.status.label}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.print_outlined, color: Color(0xFFEA580C)),
                                tooltip: 'Cetak QR',
                                onPressed: () {
                                  setState(() => _selectedTableNo = t.nomorMeja);
                                  _showPrintPreviewDialog(t.nomorMeja);
                                },
                              ),
                              onTap: () => setState(() => _selectedTableNo = t.nomorMeja),
                            ),
                          )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableSelectionList(List<TableModel> tables) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
      itemBuilder: (ctx, idx) {
        final t = tables[idx];
        final isSelected = _selectedTableNo == t.nomorMeja;

        return InkWell(
          onTap: () => setState(() => _selectedTableNo = t.nomorMeja),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFFEA580C) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 20,
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.nomorMeja,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? const Color(0xFFEA580C) : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '${t.kapasitas} Kursi',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.print_outlined, size: 18),
                  color: isSelected ? const Color(0xFFEA580C) : const Color(0xFF64748B),
                  onPressed: () {
                    setState(() => _selectedTableNo = t.nomorMeja);
                    _showPrintPreviewDialog(t.nomorMeja);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

