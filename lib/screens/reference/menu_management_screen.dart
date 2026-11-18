import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/menu_model.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
import '../../services/export_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';

class MenuManagementScreen extends StatefulWidget {
  final DatabaseService db;

  const MenuManagementScreen({super.key, required this.db});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditMenuDialog([MenuModel? existing]) {
    final nameController = TextEditingController(text: existing?.namaMasakan ?? '');
    final priceController = TextEditingController(text: existing != null ? '${existing.harga}' : '');
    final descController = TextEditingController(text: existing?.deskripsi ?? '');
    final imageController = TextEditingController(text: existing?.gambarUrl ?? '');
    var selectedCat = existing?.kategori ?? MenuCategory.makanan;
    var selectedStatus = existing?.status ?? MenuStatus.tersedia;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                existing == null ? 'Tambah Menu Restoran' : 'Edit Menu Restoran',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Masakan / Minuman',
                        hintText: 'Masukkan Nama Masakan',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MenuCategory>(
                      initialValue: selectedCat,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [MenuCategory.makanan, MenuCategory.minuman, MenuCategory.paket, MenuCategory.addon].map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCat = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga (Rp)',
                        hintText: 'Masukkan Harga',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: imageController,
                      decoration: const InputDecoration(
                        labelText: 'URL Foto Hidangan (Opsional)',
                        hintText: 'https://images.unsplash.com/...',
                        prefixIcon: Icon(Icons.image_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (existing != null) ...[
                      DropdownButtonFormField<MenuStatus>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(labelText: 'Status Ketersediaan'),
                        items: MenuStatus.values.map((st) {
                          return DropdownMenuItem(value: st, child: Text(st.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedStatus = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi Singkat',
                        hintText: 'Masukkan Deskripsi',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = int.tryParse(priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    if (name.isEmpty || price <= 0) {
                      return;
                    }

                    final imgUrl = imageController.text.trim().isNotEmpty
                        ? imageController.text.trim()
                        : MenuModel.defaultImageForMenu(name, selectedCat);

                    if (existing == null) {
                      widget.db.addMenu(name, selectedCat, price, descController.text.trim(), gambarUrl: imgUrl);
                    } else {
                      widget.db.updateMenu(
                        existing.idMasakan,
                        name,
                        selectedCat,
                        price,
                        selectedStatus,
                        descController.text.trim(),
                        gambarUrl: imgUrl,
                      );
                    }
                    Navigator.of(ctx).pop();
                    setState(() {});
                  },
                  child: Text(existing == null ? 'Simpan' : 'Perbarui'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEditTableDialog([TableModel? existing]) {
    final tableNoController = TextEditingController(
      text: existing?.nomorMeja ?? 'Meja 0${widget.db.tables.length + 1}',
    );
    final capacityController = TextEditingController(
      text: existing != null ? '${existing.kapasitas}' : '4',
    );
    var selectedStatus = existing?.status ?? TableStatus.kosong;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                existing == null ? 'Tambah Meja Restoran' : 'Edit Meja Restoran',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: tableNoController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor / Nama Meja',
                      hintText: 'Masukkan Nomor Meja',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kapasitas (Kursi)',
                      hintText: 'Masukkan Kapasitas',
                    ),
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TableStatus>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status Meja'),
                      items: TableStatus.values.map((st) {
                        return DropdownMenuItem(value: st, child: Text(st.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStatus = val);
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFEDD5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: Color(0xFFEA580C), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'QR Code Meja Otomatis Dihasilkan',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                              ),
                              Text(
                                'Sistem secara otomatis menyimpan data meja beserta link QR Code untuk pelanggan.',
                                style: TextStyle(fontSize: 10.5, color: context.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final no = tableNoController.text.trim();
                    final cap = int.tryParse(capacityController.text.trim()) ?? 0;
                    if (no.isEmpty || cap <= 0) {
                      return;
                    }

                    if (existing == null) {
                      final exists = widget.db.tables.any(
                        (t) => t.nomorMeja.toLowerCase() == no.toLowerCase(),
                      );
                      if (exists) {
                        return;
                      }
                      widget.db.addTable(no, cap);
                    } else {
                      widget.db.updateTable(
                        existing.idMeja,
                        nomorMeja: no,
                        kapasitas: cap,
                        status: selectedStatus,
                      );
                    }
                    Navigator.of(ctx).pop();
                    setState(() {});
                  },
                  child: Text(existing == null ? 'Simpan' : 'Perbarui'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTableQrDialog(TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stiker QR ${table.nomorMeja}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Dikelola oleh Administrator', style: TextStyle(fontSize: 11, color: context.textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Kartu Stiker Meja Siap Cetak
              Center(
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Image.asset(
                              'assets/images/Rasantara Cloche App Icon.png',
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(Icons.restaurant, color: Color(0xFFEA580C), size: 16),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'RASANTARA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      QrImageView(
                        data: table.qrPayload,
                        version: QrVersions.auto,
                        size: 160,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        table.nomorMeja,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kapasitas ${table.kapasitas} Kursi • Pindai untuk Pesan Menu',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Info Payload
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.fillSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        table.qrPayload,
                        style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      tooltip: 'Salin Link QR',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: table.qrPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Link QR ${table.nomorMeja} disalin ke clipboard'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tombol aksi
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.image_outlined, size: 15),
                      label: const Text('Unduh PNG'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final path = await ExportReportService.downloadTableQrImagePng(table);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(path != null
                                          ? 'Gambar QR ${table.nomorMeja}.png disimpan di folder Downloads!'
                                          : 'Gambar QR ${table.nomorMeja}.png berhasil diunduh!'),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal mengunduh gambar: $e'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                      label: const Text('Cetak / PDF'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text('Menyiapkan stiker PDF ${table.nomorMeja}...'),
                              ],
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                        try {
                          final path = await ExportReportService.downloadTableQrStickerPdf(table);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(path != null
                                          ? 'Stiker PDF ${table.nomorMeja} disimpan di folder Downloads!'
                                          : 'Stiker PDF ${table.nomorMeja} siap dicetak!'),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal membuat stiker PDF: $e'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllTablesQrDialog() {
    final tables = widget.db.tables;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: context.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          height: 520,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Semua Stiker QR Meja Restoran',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (c, i) {
                    final t = tables[i];
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          QrImageView(
                            data: t.qrPayload,
                            version: QrVersions.auto,
                            size: 96,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            t.nomorMeja,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${t.kapasitas} Kursi',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Cetak Semua Lembar Stiker'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 8),
                              Text('Menyiapkan lembar PDF semua QR meja...'),
                            ],
                          ),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      try {
                        final path = await ExportReportService.downloadAllTablesQrPdf(tables);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(path != null
                                        ? 'Semua stiker QR meja disimpan di folder Downloads!'
                                        : 'Semua stiker QR meja siap dicetak!'),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal membuat lembar QR: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: context.surfaceCard,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.orangePrimary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.orangePrimary,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.restaurant_menu, size: 18), text: 'Referensi Menu'),
              Tab(icon: Icon(Icons.table_restaurant, size: 18), text: 'Referensi Meja'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMenuTab(),
          _buildTableTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.orangePrimary,
        foregroundColor: AppTheme.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Tambah Menu' : 'Tambah Meja'),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEditMenuDialog();
          } else {
            _showAddEditTableDialog();
          }
        },
      ),
    );
  }

  Widget _buildMenuTab() {
    final menus = widget.db.menus;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 80 + MediaQuery.of(context).padding.bottom),
      itemCount: menus.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final menu = menus[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppTheme.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto Hidangan
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: context.fillSubtle,
                    child: (menu.gambarUrl.isNotEmpty)
                        ? MenuModel.buildImage(
                            menu.gambarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => MenuModel.buildImage(
                              MenuModel.defaultImageForMenu(menu.namaMasakan, menu.kategori),
                              fit: BoxFit.cover,
                              errorBuilder: (c2, e2, s2) => Icon(
                                menu.kategori == MenuCategory.minuman
                                    ? Icons.local_cafe_rounded
                                    : Icons.restaurant_rounded,
                                color: AppTheme.orangePrimary,
                                size: 28,
                              ),
                            ),
                          )
                        : MenuModel.buildImage(
                            MenuModel.defaultImageForMenu(menu.namaMasakan, menu.kategori),
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Icon(
                              menu.kategori == MenuCategory.minuman
                                  ? Icons.local_cafe_rounded
                                  : Icons.restaurant_rounded,
                              color: AppTheme.orangePrimary,
                              size: 28,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.orangeLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              menu.kategori.label,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                            ),
                          ),
                          StatusBadge.fromStatus(menu.status.label),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        menu.namaMasakan,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (menu.deskripsi.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          menu.deskripsi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text(
                        _currencyFormat.format(menu.harga),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.orangePrimary),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        menu.isTersedia ? Icons.toggle_on : Icons.toggle_off,
                        color: menu.isTersedia ? AppTheme.statusGreen : AppTheme.textMuted,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: menu.isTersedia ? 'Tandai Habis' : 'Tandai Tersedia',
                      onPressed: () {
                        widget.db.toggleMenuStatus(menu.idMasakan);
                        setState(() {});
                      },
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _showAddEditMenuDialog(menu),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.statusRed),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: 'Hapus Menu',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (delCtx) => AlertDialog(
                                backgroundColor: AppTheme.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text('Konfirmasi Hapus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                content: Text('Yakin ingin menghapus menu "${menu.namaMasakan}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(delCtx).pop(),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                                    onPressed: () {
                                      widget.db.deleteMenu(menu.idMasakan);
                                      Navigator.of(delCtx).pop();
                                      setState(() {});
                                    },
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableTab() {
    final tables = widget.db.tables;

    return Column(
      children: [
        // Banner Pengelolaan QR Meja Admin
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderSubtle),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;
              final infoContent = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFEA580C), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kelola Data Meja (${tables.length} Meja)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary),
                        ),
                        Text(
                          'Simpan data meja dan cetak stiker QR code meja tamu.',
                          style: TextStyle(fontSize: 11, color: context.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final printButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEA580C),
                  side: const BorderSide(color: Color(0xFFFDBA74)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_outlined, size: 15),
                label: const Text('Cetak Semua QR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                onPressed: _showAllTablesQrDialog,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoContent,
                    const SizedBox(height: 10),
                    printButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: infoContent),
                  const SizedBox(width: 10),
                  printButton,
                ],
              );
            },
          ),
        ),

        // Grid Meja
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 80 + MediaQuery.of(context).padding.bottom),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              final table = tables[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            table.nomorMeja,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary),
                          ),
                          StatusBadge.fromStatus(table.status.label),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people_outline, size: 15, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                '${table.kapasitas} Kursi',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 17, color: AppTheme.textMuted),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                tooltip: 'Edit Meja',
                                onPressed: () => _showAddEditTableDialog(table),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.statusRed),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                tooltip: 'Hapus Meja',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (delCtx) => AlertDialog(
                                      backgroundColor: AppTheme.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text('Hapus Meja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      content: Text('Yakin ingin menghapus ${table.nomorMeja}?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(delCtx).pop(),
                                          child: const Text('Batal'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                                          onPressed: () {
                                            widget.db.deleteTable(table.idMeja);
                                            Navigator.of(delCtx).pop();
                                            setState(() {});
                                          },
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Tombol Lihat & Cetak QR Meja
                      InkWell(
                        onTap: () => _showTableQrDialog(table),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: context.fillSubtle,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderSubtle),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2_rounded, size: 16, color: Color(0xFFEA580C)),
                              const SizedBox(width: 6),
                              Text(
                                'QR Stiker Meja',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick status toggle
                      PopupMenuButton<TableStatus>(
                        initialValue: table.status,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.orangeLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.orangeBorder),
                          ),
                          child: const Center(
                            child: Text(
                              'Ubah Status Meja',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                            ),
                          ),
                        ),
                        onSelected: (st) {
                          widget.db.updateTableStatus(table.nomorMeja, st);
                          setState(() {});
                        },
                        itemBuilder: (ctx) => TableStatus.values.map((st) {
                          return PopupMenuItem(
                            value: st,
                            child: Text(st.label),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
