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

  // Potongan harga khusus Pelanggan Langganan VIP
  int get _diskonMemberAmount {
    if (!_isCurrentCustomerSubscribed) return 0;
    final percent = widget.db.memberDiscountPercent;
    return (_cartTotalHarga * (percent / 100.0)).round();
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
      metodePembayaran: payWithQris ? 'QRIS' : 'Tunai',
    );

    widget.db.updateTableStatus(_selectedTableNo, TableStatus.terisi);

    setState(() {
      _cart.clear();
    });

    if (payWithQris) {
      // Menampilkan dialog QRIS untuk pelanggan scan
      QrisPaymentDialog.show(
        context,
        order: createdOrder,
        totalAmount: totalAmountToPay,
        db: widget.db,
        onPaymentSuccess: () {
          widget.onOrderSubmitted?.call();
        },
      ).then((_) {
        if (mounted) {
          widget.onOrderSubmitted?.call();
        }
      });
    } else {
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
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFEA580C),
                  onRefresh: () async {
                    await widget.db.initSupabase();
                    if (mounted) setState(() {});
                  },
                  child: _buildMenuGrid(isWide: true),
                ),
              ),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        Column(
          children: [
            _buildTopTableBar(),
            _buildCategoryAndSearchBar(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFEA580C),
                onRefresh: () async {
                  await widget.db.initSupabase();
                  if (mounted) setState(() {});
                },
                child: _buildMenuGrid(isWide: false),
              ),
            ),
            if (_cart.isNotEmpty) SizedBox(height: 76 + bottomInset),
          ],
        ),
        if (_cart.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14 + bottomInset,
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
        return Material(
          color: Colors.transparent,
          child: Container(
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

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTableNo = tbl.nomorMeja;
                        });
                        Navigator.pop(ctx);
                      },
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
                                  context.t('MEJA', 'TABLE'),
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
                                    isOccupied ? context.t('TERISI', 'OCCUPIED') : context.t('KOSONG', 'EMPTY'),
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
                                '${tbl.kapasitas} ${context.t('Kursi', 'Seats')}',
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
        ),
      );
    },
  );
  }

  // ── CATEGORY & SEARCH BAR ──
  Widget _buildCategoryAndSearchBar() {
    final categories = [
      MenuCategory.semua,
      MenuCategory.paket,
      MenuCategory.makanan,
      MenuCategory.minuman,
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
                hintText: context.t('Cari menu hidangan nusantara...', 'Search authentic dishes...'),
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
                    label: Text(cat.localizedLabel(context.isEnglish)),
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
        physics: const AlwaysScrollableScrollPhysics(),
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
      physics: const AlwaysScrollableScrollPhysics(),
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
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (inCart != null && inCart.jumlah > 0)
              ? AppTheme.orangePrimary
              : context.borderSubtle,
          width: (inCart != null && inCart.jumlah > 0) ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showMenuDetailOverview(menu),
        borderRadius: BorderRadius.circular(12),
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
                        errorBuilder: (c, e, s) => Image.network(
                          MenuModel.defaultImageForMenu(menu.namaMasakan, menu.kategori),
                          fit: BoxFit.cover,
                          errorBuilder: (c2, e2, s2) => _buildMenuPlaceholder(menu),
                        ),
                        loadingBuilder: (c, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: context.fillSubtle,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.orangePrimary,
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Image.network(
                        MenuModel.defaultImageForMenu(menu.namaMasakan, menu.kategori),
                        fit: BoxFit.cover,
                        errorBuilder: (c2, e2, s2) => _buildMenuPlaceholder(menu),
                      ),
                    if (!isAvailable)
                      Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        alignment: Alignment.center,
                        child: Text(
                          context.t('HABIS', 'SOLD OUT'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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

  // ── PLACEHOLDER GAMBAR ELEGAN (JIKA FOTO KOSONG / GAGAL DIMUAT) ──
  Widget _buildMenuPlaceholder(MenuModel menu, {bool isLarge = false}) {
    IconData iconData;
    String categoryLabel;
    switch (menu.kategori) {
      case MenuCategory.minuman:
        iconData = Icons.local_cafe_rounded;
        categoryLabel = 'Minuman Segar';
        break;
      case MenuCategory.paket:
        iconData = Icons.set_meal_rounded;
        categoryLabel = 'Paket Spesial';
        break;
      case MenuCategory.addon:
        iconData = Icons.bakery_dining_rounded;
        categoryLabel = 'Camilan & Pelengkap';
        break;
      default:
        iconData = Icons.restaurant_rounded;
        categoryLabel = 'Kuliner Nusantara';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isLarge ? 16 : 9),
              decoration: BoxDecoration(
                color: AppTheme.orangePrimary.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                size: isLarge ? 48 : 28,
                color: AppTheme.orangePrimary,
              ),
            ),
            if (isLarge) ...[
              const SizedBox(height: 10),
              Text(
                categoryLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF78350F),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Cita Rasa Nusantara Autentik',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF9A3412),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── DESKRIPSI DEFAULT JIKA DATA KOSONG ──
  String _getDefaultDeskripsi(MenuModel menu) {
    switch (menu.kategori) {
      case MenuCategory.minuman:
        return 'Minuman segar pelepas dahaga yang diracik dari bahan alami berkualitas tinggi, disajikan dingin dengan kesegaran maksimal.';
      case MenuCategory.paket:
        return 'Paket hidangan komplit hemat dan mengenyangkan dengan perpaduan menu utama, lauk pendamping, serta minuman segar khas Rasantara.';
      case MenuCategory.addon:
        return 'Camilan pelengkap hidangan yang renyah dan gurih, dibuat dari bumbu rempah pilihan untuk menemani santap Anda.';
      default:
        return 'Olahan kuliner khas Nusantara yang dimasak dengan racikan bumbu rempah tradisional warisan leluhur untuk cita rasa gurih dan lezat.';
    }
  }

  // ── KOMPOSISI & BAHAN UTAMA HIDANGAN ──
  String _getMenuKomposisi(MenuModel menu) {
    final lower = menu.namaMasakan.toLowerCase();

    // 1. Makanan Utama Nusantara
    if (lower.contains('rendang')) {
      return 'Daging sapi tenderloin/sandung lamur pilihan, santan kelapa murni kental, cabai merah keriting, bawang merah, bawang putih, lengkuas, jahe, serai, daun kunyit, daun jeruk purut, asam kandis, cengkih, kapulaga, dan pala.';
    } else if (lower.contains('betutu')) {
      return 'Daging ayam segar utuh pilihan, base genep rempah 15 bumbu khas Bali (bawang merah, bawang putih, cabai rawit, kunyit bakar, kencur, jahe, lengkuas, kemiri, ketumbar, terasi bakar), serai wangi, daun salam, minyak kelapa murni, dan daun pisang pembungkus.';
    } else if (lower.contains('liwet')) {
      return 'Beras pandan wangi pulen, santan kelapa segar gurih, serai, daun salam, suwiran ayam kampung bumbu opor, areh santan kental gurih, telur pindang kecap, dan sayur sambal goreng labu siam.';
    } else if (lower.contains('rawon')) {
      return 'Daging sapi sandung lamur empuk, kluwek fermentasi matang pilihan, kaldu sapi pekat gurih, daun jeruk purut, serai wangi, bawang merah, bawang putih, ketumbar, kunyit, tauge pendek segar, telur asin, dan sambal terasi pedas.';
    } else if (lower.contains('gudeg')) {
      return 'Nangka muda (gori) pilihan, gula kelapa aren asli, santan kelapa murni gurih, daun jati, sambal goreng krecek pedas kacang tolo, ayam kampung bacem lembut, areh kelapa kental, dan telur bebek bacem.';
    } else if (lower.contains('sate')) {
      return 'Daging fillet dada dan paha ayam segar empuk, bumbu marinasi ketumbar dan bawang putih, saus kacang tanah sangrai giling halus, kecap manis kedelai hitam premium, bawang merah, dan cabai rawit segar.';
    } else if (lower.contains('soto banjar') || (lower.contains('soto') && lower.contains('banjar'))) {
      return 'Daging ayam suwir empuk, kaldu ayam gurih harum kayu manis, cengkih, kapulaga, biji pala, perkedel kentang renyah, soun beras, potongan telur rebus, seledri, dan perasan jeruk limau.';
    } else if (lower.contains('pempek')) {
      return 'Daging ikan tenggiri segar giling halus, tepung sagu tani kualitas super, telur ayam utuh, bawang putih, garam, kuah cuko hitam (gula aren batok Linggau, asam jawa, cabai rawit, bawang putih), dan irisan mentimun segar.';
    } else if (lower.contains('taliwang')) {
      return 'Daging ayam kampung muda, cabai merah kering, cabai rawit merah, bawang merah, bawang putih, tomat merah segar, terasi bakar khas Lombok, kencur, gula merah, dan perasan jeruk limau segar.';
    } else if (lower.contains('bebek') || lower.contains('sinjay')) {
      return 'Daging bebek muda segar empuk gurih, bumbu rempah ungkep lengkuas, ketumbar, kunyit, bawang putih, kremesan rempah renyah, sambal pencit mangga muda serut, cabai rawit pedas, dan lalapan timun kemangi.';
    } else if (lower.contains('gado') || lower.contains('pecel')) {
      return 'Kacang panjang rebus, tauge segar, kol, kentang kukus, tahu goreng, tempe goreng, telur ayam rebus, saus kacang tanah sangrai giling halus, gula merah aren, asam jawa, kerupuk bawang, dan emping melinjo.';
    } else if (lower.contains('nasi goreng')) {
      return 'Beras pulen dingin berkualitas, telur ayam segar, suwiran daging ayam, bawang merah, bawang putih, cabai rawit, terasi bakar, kecap manis kedelai hitam, daun bawang, acar timun wortel, dan kerupuk udang.';
    } else if (lower.contains('mie goreng') || lower.contains('bakmi')) {
      return 'Mie telur kuning kenyal, telur ayam orak-arik, suwiran ayam gurih, kol, sawi hijau, daun bawang, bawang putih, kemiri, merica putih bubuk, kecap manis kedelai hitam premium, acar timun, dan bawang goreng renyah.';
    } else if (lower.contains('bakso')) {
      return 'Bakso daging dan urat sapi asli kenyal, tahu isi adonan bakso lembut, siomay kukus ikan, pangsit goreng renyah, mie kuning, soun, kuah kaldu rebusan tulang sumsum sapi harum bawang putih seledri, dan sambal rawit hijau.';
    }

    // 2. Minuman Nusantara
    else if (lower.contains('cendol') || lower.contains('dawet')) {
      return 'Butiran cendol tepung beras pandan suji hijau alami, santan kelapa murni segar gurih, sirup gula aren kental, es serut kristal, potongan buah nangka manis wangi, dan daging durian Medan asli berkualitas.';
    } else if (lower.contains('teler')) {
      return 'Daging alpukat mentega potong segar, kelapa muda serut asli, potongan buah nangka harum, biji selasih, susu kental manis premium, santan cair manis, sirup vanila pandan, dan es serut dingin.';
    } else if (lower.contains('wedang') || lower.contains('jahe')) {
      return 'Jahe merah segar dibakar dan digeprek, batang serai wangi memar, kayu manis batang, cengkih, daun pandan wangi, gula aren murni, dan air mineral murni teruji.';
    } else if (lower.contains('kuwut')) {
      return 'Serutan daging kelapa muda, air kelapa murni segar, serutan melon hijau manis, biji selasih mengembang, perasan jeruk nipis segar, sirup melon pandan, dan es batu kristal.';
    } else if (lower.contains('teh tarik')) {
      return 'Seduhan daun teh hitam pekat berkualitas (black tea), susu kental manis gurih, susu evaporasi creamy, kapulaga bubuk harum, dan air mineral murni.';
    } else if (lower.contains('alpukat') || lower.contains('avocado')) {
      return 'Buah alpukat mentega matang segar pilihan, susu cair segar, sirup gula tebu murni, saus cokelat pekat premium kental manis melimpah, dan es batu serut halus.';
    } else if (lower.contains('kopi susu') || (lower.contains('kopi') && lower.contains('aren'))) {
      return 'Double shot espresso biji kopi Nusantara (Arabika & Robusta blend), susu segar full cream, sirup gula aren organik murni cair, dan es batu kristal higienis.';
    } else if (lower.contains('kopi') || lower.contains('coffee')) {
      return 'Bubuk biji kopi murni Arabika Gayo Aceh giling medium-fine, air mineral mendidih suhu 93°C, dan gula tebu murni (opsional sesuai selera).';
    } else if (lower.contains('kelapa') || lower.contains('coconut')) {
      return 'Kerokan daging kelapa muda segar alami, air kelapa murni dingin, perasan sari jeruk peras manis segar, sirup gula tebu murni, dan es batu kristal.';
    } else if (lower.contains('teh') || lower.contains('tea')) {
      return 'Pucuk daun teh hitam pilihan perkebunan Nusantara, gula tebu alami, air mineral murni teruji, disajikan segar dengan es batu kristal.';
    }

    // 3. Camilan & Pelengkap (Add-On)
    else if (lower.contains('pisang')) {
      return 'Buah pisang raja matang manis pilihan, adonan tepung terigu dan tepung beras krispi renyah, taburan parutan keju cheddar gurih melimpah, susu kental manis cokelat, dan minyak goreng nabati higienis.';
    } else if (lower.contains('tahu gejrot')) {
      return 'Tahu pong kopong goreng gurih dipotong-potong, kuah gula merah aren rebusan asam jawa dan kecap manis, ulekan kasar cabai rawit hijau, bawang merah, dan bawang putih segar khas Cirebon.';
    } else if (lower.contains('tempe') || lower.contains('mendoan')) {
      return 'Tempe kedelai khusus mendoan tipis lebar, adonan tepung terigu dan tepung beras gurih rempah ketumbar kunyit, irisan daun bawang segar melimpah, dan cocolan sambal kecap manis cabai rawit pedas.';
    } else if (lower.contains('kerupuk') || lower.contains('krupuk')) {
      return 'Daging udang laut segar giling halus, tepung tapioka super halus, telur ayam, bawang putih, garam bumbu rempah, dan digoreng dengan minyak kelapa sawit nabati higienis hingga renyah mengembang sempurna.';
    }

    // 4. Paket Menu Komplit
    else if (lower.contains('rantang berempat')) {
      return '2 porsi Rendang Daging Sapi Minang, 2 porsi Ayam Betutu Gilimanuk, 4 porsi Nasi Liwet Gurih Solo, 1 mangkuk Sambal Goreng Krecek gurih pedas, kerupuk udang renyah, lalapan segar, dan 4 gelas Es Teh Manis Segar.';
    } else if (lower.contains('kenyang berdua')) {
      return '1 porsi Rendang Daging Sapi Minang, 1 porsi Ayam Betutu Bakar Bali, 2 porsi Nasi Putih Pandan Wangi pulen, sambal cabai hijau, lalapan segar, dan 2 gelas Es Cendol Gula Aren Rasantara.';
    } else if (lower.contains('sarapan solo')) {
      return '1 porsi Nasi Liwet Solo gurih santan, suwiran ayam opor lembut, telur pindang bacem, sayur labu siam areh kental gurih, dan 1 cangkir Teh Tarik Melayu Rempah Hangat.';
    }

    // Fallback Kategori
    switch (menu.kategori) {
      case MenuCategory.minuman:
        return 'Bahan minuman alami berkualitas, air mineral murni higienis, sari buah segar, pemanis alami pilihan, dan es batu kristal.';
      case MenuCategory.paket:
        return 'Perpaduan menu utama Nusantara, lauk pendamping lezat, sambal khas tradisional, lalapan segar, dan minuman pelengkap.';
      case MenuCategory.addon:
        return 'Bahan makanan pilihan bermutu tinggi, racikan garam rempah tradisional gurih, dan digoreng dengan minyak nabati higienis.';
      default:
        return 'Bahan baku segar pilihan, racikan bumbu rempah autentik khas Nusantara (bawang merah, bawang putih, rempah aromatik), dan minyak nabati berkualitas.';
    }
  }

  // ── BOTTOM SHEET OVERVIEW HIDANGAN (FOTO FULL TIDAK TERPOTONG) ──
  void _showMenuDetailOverview(MenuModel menu) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAvailable = menu.isTersedia;

    final existingItem = _cart[menu.idMasakan];
    int quantity = existingItem != null ? existingItem.jumlah : 1;

    final komposisi = _getMenuKomposisi(menu);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final subtotal = menu.harga * quantity;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),

                  // Header Bar (Badges & Close Button)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.orangePrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                menu.kategori.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.orangePrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isAvailable ? 'Tersedia' : 'Habis',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isAvailable ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          ),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),

                  // Konten Detail
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── FOTO HIDANGAN FULL (TIDAK TERPOTONG!) ──
                          Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderSubtle),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: menu.gambarUrl.isNotEmpty
                                ? Image.network(
                                    menu.gambarUrl,
                                    fit: BoxFit.contain, // FULL UTUH TIDAK TERPOTONG
                                    errorBuilder: (c, e, s) => Image.network(
                                      MenuModel.defaultImageForMenu(menu.namaMasakan, menu.kategori),
                                      fit: BoxFit.contain,
                                      errorBuilder: (c2, e2, s2) => _buildMenuPlaceholder(menu, isLarge: true),
                                    ),
                                    loadingBuilder: (c, child, progress) {
                                      if (progress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                              : null,
                                          color: AppTheme.orangePrimary,
                                        ),
                                      );
                                    },
                                  )
                                : Image.network(
                                    MenuModel.defaultImageForMenu(menu.namaMasakan, menu.kategori),
                                    fit: BoxFit.contain,
                                    errorBuilder: (c2, e2, s2) => _buildMenuPlaceholder(menu, isLarge: true),
                                  ),
                          ),

                          const SizedBox(height: 16),

                          // Nama & Harga
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  menu.namaMasakan,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _currencyFmt.format(menu.harga),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.orangePrimary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ── DESKRIPSI SINGKAT MAKANAN ──
                          Text(
                            context.t('Deskripsi Singkat', 'Brief Description'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            menu.deskripsi.trim().isNotEmpty
                                ? menu.deskripsi.trim()
                                : _getDefaultDeskripsi(menu),
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 14),
                          Divider(color: context.borderSubtle, height: 1),
                          const SizedBox(height: 14),

                          // ── KOMPOSISI HIDANGAN ──
                          Text(
                            context.t('Komposisi Hidangan', 'Dish Ingredients'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            komposisi,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color: context.surfaceCard,
                      border: Border(top: BorderSide(color: context.borderSubtle)),
                    ),
                    child: Row(
                      children: [
                        // Quantity Stepper
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.borderSubtle),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                color: quantity > 1 ? AppTheme.orangePrimary : AppTheme.textMuted,
                                onPressed: isAvailable && quantity > 1
                                    ? () => setSheetState(() => quantity--)
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '$quantity',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                color: isAvailable ? AppTheme.orangePrimary : AppTheme.textMuted,
                                onPressed: isAvailable
                                    ? () => setSheetState(() => quantity++)
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Tombol Tambah / Perbarui
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: isAvailable
                                  ? () {
                                      setState(() {
                                        if (_cart.containsKey(menu.idMasakan)) {
                                          _cart[menu.idMasakan]!.jumlah = quantity;
                                        } else {
                                          _cart[menu.idMasakan] = OrderItemModel(
                                            idDetailOrder: 0,
                                            menu: menu,
                                            jumlah: quantity,
                                            catatan: existingItem?.catatan ?? '',
                                          );
                                        }
                                      });
                                      Navigator.pop(sheetCtx);
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.orangePrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                isAvailable
                                    ? (existingItem != null
                                        ? 'Perbarui • ${_currencyFmt.format(subtotal)}'
                                        : 'Tambah • ${_currencyFmt.format(subtotal)}')
                                    : 'Stok Habis',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                    Expanded(
                      child: Text(
                        'Diskon VIP (${widget.db.memberDiscountPercent}%):',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
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
              // Tombol Bayar QRIS
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
                      'Bayar QRIS',
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
