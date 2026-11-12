import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/menu_model.dart';
import '../../models/order_model.dart';
import '../../models/table_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/qris_payment_dialog.dart';

class OrderEntryScreen extends StatefulWidget {
  final DatabaseService db;
  final String? initialTableNo;
  final MenuCategory? initialCategory;
  final String? initialSearch;
  final String? initialCoupon;
  final void Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOrderSubmitted;

  const OrderEntryScreen({
    super.key,
    required this.db,
    this.initialTableNo,
    this.initialCategory,
    this.initialSearch,
    this.initialCoupon,
    this.onNavigateToTab,
    this.onOrderSubmitted,
  });

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  // Meja Terpilih
  String _selectedTableNo = 'Meja 01';

  // Search Controller
  final _searchController = TextEditingController();

  // Kategori & Search
  MenuCategory _selectedCategory = MenuCategory.semua;
  String _searchQuery = '';

  // Keranjang Pesanan Meja: idMasakan -> OrderItemModel
  final Map<int, OrderItemModel> _cart = {};

  final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    if (widget.initialTableNo != null && widget.initialTableNo!.isNotEmpty) {
      _selectedTableNo = widget.initialTableNo!;
    } else {
      _selectedTableNo = 'Meja 01';
    }

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _searchController.text = widget.initialSearch!;
      _searchQuery = widget.initialSearch!.toLowerCase();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Cek apakah pelanggan yang memesan adalah Pelanggan Langganan (VIP Member)
  bool get _isCurrentCustomerSubscribed {
    final curUser = widget.db.currentUser;
    if (curUser != null && curUser.role == UserRole.pelanggan && curUser.isSubscribed) {
      return true;
    }
    return false;
  }

  // Potongan harga khusus Pelanggan Langganan (10% dari total belanja menu)
  int get _diskonMemberAmount {
    if (!_isCurrentCustomerSubscribed) return 0;
    return (_cartTotalHarga * 0.10).round();
  }

  int get _cartTotalHarga => _cart.values.fold(0, (sum, i) => sum + i.subtotal);
  int get _cartTotalItems => _cart.values.fold(0, (sum, i) => sum + i.jumlah);

  int get _grandTotal {
    final net = _cartTotalHarga - _diskonMemberAmount;
    return net > 0 ? net : 0;
  }

  void _addToCart(MenuModel menu) {
    if (!menu.isTersedia) return;
    setState(() {
      if (_cart.containsKey(menu.idMasakan)) {
        _cart[menu.idMasakan]!.jumlah += 1;
      } else {
        _cart[menu.idMasakan] = OrderItemModel(
          idDetailOrder: 0,
          menu: menu,
          jumlah: 1,
          catatan: '',
        );
      }
    });
  }

  void _removeFromCart(MenuModel menu) {
    setState(() {
      if (!_cart.containsKey(menu.idMasakan)) return;
      if (_cart[menu.idMasakan]!.jumlah > 1) {
        _cart[menu.idMasakan]!.jumlah -= 1;
      } else {
        _cart.remove(menu.idMasakan);
      }
    });
  }

  void _editItemNote(OrderItemModel item) {
    final noteCtrl = TextEditingController(text: item.catatan);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Catatan Menu: ${item.menu.namaMasakan}',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: TextField(
          controller: noteCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Contoh: Pedas sedang, tanpa es, pisah kuah...',
            labelText: 'Keterangan Pesanan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.orangePrimary),
            onPressed: () {
              setState(() {
                item.catatan = noteCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _submitOrder({bool payWithQris = false}) {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 menu sebelum mengirim pesanan meja.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    final custName = widget.db.currentUser?.role == UserRole.pelanggan
        ? widget.db.currentUser!.namaUser
        : 'Pelanggan $_selectedTableNo';
    final orderNotes = 'Layanan Meja $_selectedTableNo';
    final effDiskonMember = _diskonMemberAmount;
    final totalAmountToPay = _grandTotal;

    final createdOrder = widget.db.createOrder(
      noMeja: _selectedTableNo,
      namaPelanggan: custName,
      keterangan: orderNotes,
      items: _cart.values.toList(),
      diskonMember: effDiskonMember,
    );

    widget.db.updateTableStatus(_selectedTableNo, TableStatus.terisi);

    final submittedTable = _selectedTableNo;
    setState(() {
      _cart.clear();
    });

    if (payWithQris) {
      // Menampilkan dialog QRIS dinamis untuk pelanggan scan lewat DANA / GoPay
      QrisPaymentDialog.show(
        context,
        order: createdOrder,
        totalAmount: totalAmountToPay,
        db: widget.db,
        onPaymentSuccess: () {
          widget.onOrderSubmitted?.call();
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pesanan $submittedTable untuk "$custName" berhasil dikirim ke Kasir & Dapur.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onOrderSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaceBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          return isWide ? _buildWideLayout() : _buildCompactLayout();
        },
      ),
    );
  }

  // ── LAYOUT WIDE (TABLET / DESKTOP POS WAITER) ──
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kolom Kiri: Navigasi Meja, Filter Kategori & Menu Grid
        Expanded(
          flex: 65,
          child: Column(
            children: [
              _buildTopTableBar(),
              _buildCategoryAndSearchBar(),
              Expanded(child: _buildMenuGrid(isWide: true)),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: AppTheme.borderSubtle),
        // Kolom Kanan: Keranjang Pesanan Meja (Always Visible)
        Expanded(
          flex: 35,
          child: Container(
            color: context.surfaceCard,
            child: _buildCartPanel(),
          ),
        ),
      ],
    );
  }

  // ── LAYOUT COMPACT (SMARTPHONE WAITER) ──
  Widget _buildCompactLayout() {
    return Stack(
      children: [
        Column(
          children: [
            _buildTopTableBar(),
            _buildCategoryAndSearchBar(),
            Expanded(child: _buildMenuGrid(isWide: false)),
            if (_cart.isNotEmpty) const SizedBox(height: 76),
          ],
        ),
        if (_cart.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: _buildMobileBottomBar(),
          ),
      ],
    );
  }

  // ── TOP TABLE BAR (QUICK TABLE SELECTOR) ──
  Widget _buildTopTableBar() {
    final tables = widget.db.tables;

    return Container(
      color: context.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_restaurant_rounded, size: 16, color: AppTheme.orangePrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Pilih Meja:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showVisualTablePickerModal,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.orangeLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.orangeBorder),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.grid_view_rounded, size: 12, color: AppTheme.orangePrimary),
                          SizedBox(width: 4),
                          Text(
                            'Denah Visual',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.orangePrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orangePrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedTableNo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tables.map((tbl) {
                final isSelected = tbl.nomorMeja == _selectedTableNo;
                final isOccupied = tbl.status == TableStatus.terisi;

                Color bg = context.surfaceBg;
                Color border = context.borderSubtle;
                Color textCol = context.textPrimary;

                if (isSelected) {
                  bg = AppTheme.orangePrimary;
                  border = AppTheme.orangePrimary;
                  textCol = Colors.white;
                } else if (isOccupied) {
                  bg = const Color(0xFFFEF3C7);
                  border = const Color(0xFFFDE68A);
                  textCol = const Color(0xFF92400E);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTableNo = tbl.nomorMeja;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tbl.nomorMeja,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: textCol,
                            ),
                          ),
                          if (isOccupied && !isSelected) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD97706),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _showVisualTablePickerModal() {
    final tables = widget.db.tables;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.table_restaurant_rounded, size: 20, color: AppTheme.orangePrimary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pilih Meja Pesanan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    final tbl = tables[index];
                    final isSelected = tbl.nomorMeja == _selectedTableNo;
                    final isOccupied = tbl.status == TableStatus.terisi;
                    final numStr = tbl.nomorMeja.replaceAll(RegExp(r'[^0-9]'), '');

                    Color bg = isSelected
                        ? AppTheme.orangePrimary
                        : (isOccupied
                            ? (context.isDarkMode ? const Color(0xFF431407).withValues(alpha: 0.35) : const Color(0xFFFFF7ED))
                            : context.surfaceCard);
                    Color border = isSelected
                        ? AppTheme.orangePrimary
                        : (isOccupied ? const Color(0xFFEA580C) : context.borderSubtle);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTableNo = tbl.nomorMeja;
                        });
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: border,
                            width: (isSelected || isOccupied) ? 1.6 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'MEJA',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : (isOccupied ? const Color(0xFFEA580C) : context.textSecondary),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isOccupied
                                            ? const Color(0xFFEA580C).withValues(alpha: 0.15)
                                            : const Color(0xFF16A34A).withValues(alpha: 0.15)),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    isOccupied ? 'TERISI' : 'KOSONG',
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? Colors.white
                                          : (isOccupied ? const Color(0xFFEA580C) : const Color(0xFF16A34A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                numStr.isNotEmpty ? numStr : tbl.nomorMeja,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : (isOccupied ? const Color(0xFFEA580C) : context.textPrimary),
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${tbl.kapasitas} Kursi',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : context.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── CATEGORY & SEARCH BAR ──
  Widget _buildCategoryAndSearchBar() {
    final categories = [
      MenuCategory.semua,
      MenuCategory.makanan,
      MenuCategory.minuman,
      MenuCategory.paket,
      MenuCategory.addon,
    ];

    return Container(
      color: context.surfaceCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderSubtle),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: TextStyle(fontSize: 13, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cari menu hidangan nusantara...',
                hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Categories horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    selectedColor: AppTheme.orangePrimary,
                    backgroundColor: context.surfaceBg,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : context.textPrimary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isSelected ? AppTheme.orangePrimary : context.borderSubtle),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── MENU GRID ──
  Widget _buildMenuGrid({required bool isWide}) {
    var items = widget.db.menus;

    if (_selectedCategory != MenuCategory.semua) {
      items = items.where((m) => m.kategori == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      items = items.where((m) => m.namaMasakan.toLowerCase().contains(_searchQuery)).toList();
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'Menu tidak ditemukan',
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    final crossAxisCount = isWide ? 3 : 2;

    // Jika kategori yang dipilih adalah "Semua" dan tidak sedang mencari teks spesifik,
    // kelompokkan menu ke dalam section: Paket Spesial, Makanan, Minuman, Camilan & Add-On
    if (_selectedCategory == MenuCategory.semua && _searchQuery.isEmpty) {
      final sections = [
        (category: MenuCategory.paket, title: 'Paket Spesial', icon: Icons.stars_rounded),
        (category: MenuCategory.makanan, title: 'Makanan', icon: Icons.restaurant_rounded),
        (category: MenuCategory.minuman, title: 'Minuman', icon: Icons.local_cafe_rounded),
        (category: MenuCategory.addon, title: 'Camilan & Add-On', icon: Icons.cookie_outlined),
      ];

      return ListView(
        padding: const EdgeInsets.all(16),
        children: sections.map((sec) {
          final catItems = items.where((m) => m.kategori == sec.category).toList();
          if (catItems.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Bagian Kategori
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.orangePrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(sec.icon, size: 18, color: AppTheme.orangePrimary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      sec.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.fillSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderSubtle),
                      ),
                      child: Text(
                        '${catItems.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Grid Item Menu per Bagian Kategori
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: isWide ? 0.95 : 0.85,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: catItems.length,
                itemBuilder: (context, index) {
                  return _buildMenuItemCard(catItems[index]);
                },
              ),
              const SizedBox(height: 20),
            ],
          );
        }).toList(),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isWide ? 0.95 : 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildMenuItemCard(items[index]);
      },
    );
  }

  Widget _buildMenuItemCard(MenuModel menu) {
    final inCart = _cart[menu.idMasakan];
    final isAvailable = menu.isTersedia;

    return Card(
      elevation: 0,
      color: context.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (inCart != null && inCart.jumlah > 0)
              ? AppTheme.orangePrimary
              : context.borderSubtle,
          width: (inCart != null && inCart.jumlah > 0) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar Menu
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (menu.gambarUrl.isNotEmpty)
                    Image.network(
                      menu.gambarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: const Color(0xFFFFF7ED),
                        child: const Center(
                          child: Icon(Icons.lunch_dining_rounded, size: 36, color: Color(0xFFEA580C)),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFFFFF7ED),
                      child: const Center(
                        child: Icon(Icons.restaurant_menu, size: 36, color: Color(0xFFEA580C)),
                      ),
                    ),
                  if (!isAvailable)
                    Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      alignment: Alignment.center,
                      child: const Text(
                        'HABIS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Info & Aksi
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        menu.namaMasakan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFmt.format(menu.harga),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.orangePrimary,
                        ),
                      ),
                    ],
                  ),
                  // Stepper / Tambah
                  if (inCart != null && inCart.jumlah > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.note_alt_outlined, size: 18),
                          tooltip: 'Catatan Menu',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          color: inCart.catatan.isNotEmpty ? AppTheme.orangePrimary : AppTheme.textMuted,
                          onPressed: () => _editItemNote(inCart),
                        ),
                        Row(
                          children: [
                            _stepperButton(Icons.remove, () => _removeFromCart(menu)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '${inCart.jumlah}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            _stepperButton(Icons.add, () => _addToCart(menu)),
                          ],
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: isAvailable ? () => _addToCart(menu) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.orangePrimary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Tambah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _stepperButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppTheme.orangePrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: AppTheme.orangePrimary),
      ),
    );
  }

  // ── CART PANEL (RINCIAN PESANAN MEJA) ──
  Widget _buildCartPanel({VoidCallback? onActionBeforeSubmit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cart Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            border: Border(bottom: BorderSide(color: context.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesanan $_selectedTableNo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                    const Text(
                      'Layanan Meja Restoran',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _cart.clear()),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Kosongkan', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),

        // Cart Items List
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('Belum ada pesanan untuk $_selectedTableNo', style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      const Text('Pilih hidangan dari menu di samping', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cart.length,
                  separatorBuilder: (_, _) => Divider(height: 16, color: context.borderSubtle),
                  itemBuilder: (context, index) {
                    final item = _cart.values.elementAt(index);
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.menu.namaMasakan,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.jumlah}x ${_currencyFmt.format(item.menu.harga)} = ${_currencyFmt.format(item.subtotal)}',
                                style: TextStyle(fontSize: 12, color: context.textSecondary),
                              ),
                              if (item.catatan.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Catatan: ${item.catatan}',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.orangePrimary),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_note, size: 20),
                              tooltip: 'Catatan',
                              onPressed: () => _editItemNote(item),
                            ),
                            _stepperButton(Icons.remove, () => _removeFromCart(item.menu)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text('${item.jumlah}', style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                            ),
                            _stepperButton(Icons.add, () => _addToCart(item.menu)),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Cart Summary & Kirim Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceCard,
            border: Border(top: BorderSide(color: context.borderSubtle)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Subtotal Menu ($_cartTotalItems item):',
                      style: TextStyle(fontSize: 13, color: context.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_currencyFmt.format(_cartTotalHarga), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary)),
                ],
              ),
              if (_diskonMemberAmount > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Diskon VIP (10%):',
                        style: TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('- ${_currencyFmt.format(_diskonMemberAmount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ],
                ),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Total Pesanan:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currencyFmt.format(_grandTotal),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.orangePrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tombol Bayar QRIS Dinamis (DANA / GoPay)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _cart.isNotEmpty
                      ? () {
                          onActionBeforeSubmit?.call();
                          _submitOrder(payWithQris: true);
                        }
                      : null,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: Colors.white),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Bayar QRIS Meja (DANA / GoPay)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Tombol Kirim Pesanan (Bayar Nanti di Kasir)
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _cart.isNotEmpty
                      ? () {
                          onActionBeforeSubmit?.call();
                          _submitOrder(payWithQris: false);
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded, size: 16, color: AppTheme.orangePrimary),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Kirim Pesanan (Bayar di Kasir)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orangePrimary),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.orangePrimary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── MOBILE BOTTOM BAR ──
  Widget _buildMobileBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_selectedTableNo • $_cartTotalItems item',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _currencyFmt.format(_grandTotal),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (modalCtx) => Container(
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: _buildCartPanel(
                    onActionBeforeSubmit: () => Navigator.of(modalCtx).pop(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.shopping_cart_checkout, size: 18),
            label: const Text('Rincian Pesanan'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.orangePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
