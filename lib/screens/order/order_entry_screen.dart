import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';

class OrderEntryScreen extends StatefulWidget {
  final DatabaseService db;

  const OrderEntryScreen({super.key, required this.db});

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  String? _selectedTableNo;
  final _customerNameController = TextEditingController(text: 'Pelanggan Walk-In');
  final _notesController = TextEditingController();
  MenuCategory _selectedCategory = MenuCategory.semua;
  String _searchQuery = '';

  // Local cart: menu.idMasakan -> OrderItemModel
  final Map<int, OrderItemModel> _cart = {};

  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Default to first empty table if available
    final available = widget.db.tables.where((t) => t.status == TableStatus.kosong);
    if (available.isNotEmpty) {
      _selectedTableNo = available.first.nomorMeja;
    } else if (widget.db.tables.isNotEmpty) {
      _selectedTableNo = widget.db.tables.first.nomorMeja;
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addToCart(MenuModel menu) {
    if (!menu.isTersedia) return;
    setState(() {
      if (_cart.containsKey(menu.idMasakan)) {
        _cart[menu.idMasakan]!.jumlah += 1;
      } else {
        _cart[menu.idMasakan] = OrderItemModel(
          idDetailOrder: DateTime.now().millisecondsSinceEpoch + menu.idMasakan,
          menu: menu,
          jumlah: 1,
        );
      }
    });
  }

  void _removeFromCart(MenuModel menu) {
    setState(() {
      if (_cart.containsKey(menu.idMasakan)) {
        if (_cart[menu.idMasakan]!.jumlah > 1) {
          _cart[menu.idMasakan]!.jumlah -= 1;
        } else {
          _cart.remove(menu.idMasakan);
        }
      }
    });
  }

  int get _cartTotalHarga => _cart.values.fold(0, (sum, item) => sum + item.subtotal);
  int get _cartTotalItems => _cart.values.fold(0, (sum, item) => sum + item.jumlah);

  void _submitOrder() {
    if (_selectedTableNo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih meja terlebih dahulu')),
      );
      return;
    }

    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan masih kosong, pilih menu terlebih dahulu')),
      );
      return;
    }

    final order = widget.db.createOrder(
      noMeja: _selectedTableNo!,
      namaPelanggan: _customerNameController.text.trim().isEmpty ? 'Pelanggan' : _customerNameController.text.trim(),
      keterangan: _notesController.text.trim(),
      items: _cart.values.toList(),
    );

    setState(() {
      _cart.clear();
      _notesController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.statusGreen,
        content: Text('Order #${order.idOrder} untuk $_selectedTableNo berhasil dikirim ke dapur!'),
      ),
    );
  }

  void _openCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rincian Pesanan ($_selectedTableNo)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_cart.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('Keranjang pesanan kosong', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: _cart.values.map((item) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.menu.namaMasakan,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      _currencyFormat.format(item.subtotal),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '@ ${_currencyFormat.format(item.menu.harga)}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.orangePrimary, size: 22),
                                          onPressed: () {
                                            _removeFromCart(item.menu);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                        Text('${item.jumlah}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: AppTheme.orangePrimary, size: 22),
                                          onPressed: () {
                                            _addToCart(item.menu);
                                            setModalState(() {});
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Catatan (contoh: pedas, es dipisah)',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  controller: TextEditingController(text: item.catatan)
                                    ..selection = TextSelection.collapsed(offset: item.catatan.length),
                                  onChanged: (val) {
                                    item.catatan = val;
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        _currencyFormat.format(_cartTotalHarga),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cart.isEmpty
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            _submitOrder();
                          },
                    child: Text('Kirim Order ($_cartTotalItems item)'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMenus = widget.db.menus.where((menu) {
      final matchCategory = _selectedCategory == MenuCategory.semua || menu.kategori == _selectedCategory;
      final matchQuery = menu.namaMasakan.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          menu.deskripsi.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCategory && matchQuery;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: Column(
        children: [
          // Top Bar: Table Selector and Customer Name
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Table Selector Dropdown
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTableNo,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Meja',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          prefixIcon: Icon(Icons.table_restaurant, color: AppTheme.orangePrimary, size: 18),
                        ),
                        items: widget.db.tables.map((table) {
                          return DropdownMenuItem<String>(
                            value: table.nomorMeja,
                            child: Text(
                              '${table.nomorMeja} (${table.status.label})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedTableNo = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Customer Name
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _customerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Pelanggan',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search Input
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Cari makanan, minuman, paket...',
                    prefixIcon: Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MenuCategory.values.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.label),
                      selected: isSelected,
                      selectedColor: AppTheme.orangePrimary,
                      backgroundColor: AppTheme.surfaceBg,
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.white : AppTheme.textDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Menu Grid
          Expanded(
            child: filteredMenus.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada menu yang sesuai',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 800
                          ? 4
                          : constraints.maxWidth > 550
                              ? 3
                              : 2;
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredMenus.length,
                        itemBuilder: (context, index) {
                          final menu = filteredMenus[index];
                          final qtyInCart = _cart[menu.idMasakan]?.jumlah ?? 0;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: qtyInCart > 0 ? AppTheme.orangePrimary : AppTheme.borderSubtle,
                                width: qtyInCart > 0 ? 1.5 : 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Category & Availability Badge
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.orangeLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          menu.kategori.label,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.orangePrimary, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      StatusBadge.fromStatus(menu.status.label),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Menu Name
                                  Text(
                                    menu.namaMasakan,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Description
                                  Expanded(
                                    child: Text(
                                      menu.deskripsi,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Price
                                  Text(
                                    _currencyFormat.format(menu.harga),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.orangePrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Counter or Add Button
                                  if (!menu.isTersedia)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: null,
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 36),
                                        ),
                                        child: const Text('Habis', style: TextStyle(fontSize: 12)),
                                      ),
                                    )
                                  else if (qtyInCart == 0)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _addToCart(menu),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 36),
                                        ),
                                        child: const Text('+ Tambah', style: TextStyle(fontSize: 12)),
                                      ),
                                    )
                                  else
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          onTap: () => _removeFromCart(menu),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.orangeLight,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.remove, size: 18, color: AppTheme.orangePrimary),
                                          ),
                                        ),
                                        Text(
                                          '$qtyInCart',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        InkWell(
                                          onTap: () => _addToCart(menu),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.orangePrimary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(Icons.add, size: 18, color: AppTheme.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      // Bottom Order Floating Bar
      bottomNavigationBar: _cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_cartTotalItems Item Terpilih • $_selectedTableNo',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                          Text(
                            _currencyFormat.format(_cartTotalHarga),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.orangePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _openCartBottomSheet,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      child: const Text('Rincian'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submitOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text('Kirim Order'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
