import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
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
                      decoration: const InputDecoration(labelText: 'Nama Masakan / Minuman'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MenuCategory>(
                      initialValue: selectedCat,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: [MenuCategory.makanan, MenuCategory.minuman, MenuCategory.paket].map((cat) {
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
                      decoration: const InputDecoration(labelText: 'Harga (Rp)', prefixText: 'Rp '),
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
                      decoration: const InputDecoration(labelText: 'Deskripsi Singkat'),
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
                    if (name.isEmpty || price <= 0) return;

                    if (existing == null) {
                      widget.db.addMenu(name, selectedCat, price, descController.text.trim());
                    } else {
                      widget.db.updateMenu(
                        existing.idMasakan,
                        name,
                        selectedCat,
                        price,
                        selectedStatus,
                        descController.text.trim(),
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

  void _showAddTableDialog() {
    final tableNoController = TextEditingController(text: 'Meja 0${widget.db.tables.length + 1}');
    final capacityController = TextEditingController(text: '4');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Meja Restoran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tableNoController,
                decoration: const InputDecoration(labelText: 'Nomor / Nama Meja'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kapasitas (Kursi)'),
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
                final cap = int.tryParse(capacityController.text.trim()) ?? 4;
                if (no.isEmpty) return;
                widget.db.addTable(no, cap);
                Navigator.of(ctx).pop();
                setState(() {});
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: AppTheme.white,
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
            _showAddTableDialog();
          }
        },
      ),
    );
  }

  Widget _buildMenuTab() {
    final menus = widget.db.menus;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
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
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.orangeLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              menu.kategori.label,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge.fromStatus(menu.status.label),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        menu.namaMasakan,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textDark),
                      ),
                      if (menu.deskripsi.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          menu.deskripsi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _currencyFormat.format(menu.harga),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                      ),
                    ],
                  ),
                ),
                // Action Buttons
                Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        menu.isTersedia ? Icons.toggle_on : Icons.toggle_off,
                        color: menu.isTersedia ? AppTheme.statusGreen : AppTheme.textMuted,
                        size: 30,
                      ),
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
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textMuted),
                          onPressed: () => _showAddEditMenuDialog(menu),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.statusRed),
                          onPressed: () {
                            widget.db.deleteMenu(menu.idMasakan);
                            setState(() {});
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

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
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
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      table.nomorMeja,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                    ),
                    StatusBadge.fromStatus(table.status.label),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      '${table.kapasitas} Orang',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ],
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
    );
  }
}
