import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/menu_model.dart';
import '../services/database_service.dart';
import '../services/order_simulation_service.dart';
import '../widgets/order_tracker_sheet.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'order/order_entry_screen.dart';
import 'order/order_history_screen.dart';
import 'cashier/cashier_screen.dart';
import 'reference/menu_management_screen.dart';
import 'reports/report_screen.dart';
import 'users/user_management_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/settings_screen.dart';

class NavDestinationItem {
  final String label;
  final IconData icon;
  final Widget screen;
  const NavDestinationItem({
    required this.label,
    required this.icon,
    required this.screen,
  });
}

class MainNavigationScreen extends StatefulWidget {
  final DatabaseService db;
  final VoidCallback onLogout;

  const MainNavigationScreen({
    super.key,
    required this.db,
    required this.onLogout,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;
  bool _isDesktopSidebarVisible = true;
  String? _selectedTableForOrder;
  MenuCategory? _selectedCategoryForOrder;
  String? _searchQueryForOrder;
  String? _autoApplyCouponForOrder;

  void _navigateToTab(int index, {MenuCategory? category, String? searchQuery, String? couponCode, String? tableNo}) {
    setState(() {
      _currentIndex = index;
      if (category != null) _selectedCategoryForOrder = category;
      if (searchQuery != null) _searchQueryForOrder = searchQuery;
      if (couponCode != null) _autoApplyCouponForOrder = couponCode;
      if (tableNo != null) _selectedTableForOrder = tableNo;
    });
  }

  List<NavDestinationItem> _getDestinationsForRole(UserRole role) {
    final list = <NavDestinationItem>[];

    // 1. Dashboard Denah Meja: Seluruh role
    list.add(NavDestinationItem(
      label: context.t('Beranda', 'Home'),
      icon: Icons.table_restaurant_rounded,
      screen: DashboardScreen(
        db: widget.db,
        onNavigateToTab: _navigateToTab,
      ),
    ));

    // 2. Entri Order: Admin, Waiter, Pelanggan
    if (role.canCreateOrder) {
      list.add(NavDestinationItem(
        label: context.t('Entri Order', 'Order Entry'),
        icon: Icons.restaurant_menu_rounded,
        screen: OrderEntryScreen(
          key: ValueKey('order-$_selectedTableForOrder-${_selectedCategoryForOrder?.name}-$_searchQueryForOrder-$_autoApplyCouponForOrder'),
          db: widget.db,
          initialTableNo: _selectedTableForOrder,
          initialCategory: _selectedCategoryForOrder,
          initialSearch: _searchQueryForOrder,
          initialCoupon: _autoApplyCouponForOrder,
          onNavigateToTab: _navigateToTab,
          onOrderSubmitted: () {
            setState(() {
              _selectedTableForOrder = null;
              _selectedCategoryForOrder = null;
              _searchQueryForOrder = null;
              _autoApplyCouponForOrder = null;
            });
            _navigateToTab(0);
          },
        ),
      ));
    }

    // 2b. Riwayat Pesanan: Khusus Pelanggan
    if (role == UserRole.pelanggan) {
      list.add(NavDestinationItem(
        label: context.t('Riwayat', 'History'),
        icon: Icons.receipt_long_rounded,
        screen: CustomerOrderHistoryScreen(db: widget.db),
      ));
    }

    // 3. Entri Transaksi: Admin, Kasir
    if (role.canProcessTransactions) {
      list.add(NavDestinationItem(
        label: context.t('Entri Transaksi', 'Transactions'),
        icon: Icons.point_of_sale_rounded,
        screen: CashierScreen(db: widget.db),
      ));
    }

    // 4. Entri Referensi: Admin only
    if (role.canManageReferences) {
      list.add(NavDestinationItem(
        label: context.t('Entri Referensi', 'References'),
        icon: Icons.inventory_2_outlined,
        screen: MenuManagementScreen(db: widget.db),
      ));
    }

    // 5. Generate Laporan: Admin, Waiter, Kasir, Owner
    if (role.canViewReports) {
      list.add(NavDestinationItem(
        label: context.t('Laporan', 'Reports'),
        icon: Icons.analytics_outlined,
        screen: ReportScreen(db: widget.db),
      ));
    }

    // 6. Registrasi User: Admin, Waiter, Kasir
    if (role.canRegisterUsers) {
      list.add(NavDestinationItem(
        label: context.t('Registrasi User', 'Registration'),
        icon: Icons.people_outline,
        screen: UserManagementScreen(db: widget.db),
      ));
    }

    // Profil & Pengaturan Akun: Semua Role
    list.add(NavDestinationItem(
      label: context.t('Profil', 'Profile'),
      icon: Icons.person_outline_rounded,
      screen: ProfileScreen(
        db: widget.db,
        onLogout: widget.onLogout,
      ),
    ));

    return list;
  }

  void _showUserAccountModal(BuildContext context, UserModel? user, UserRole role) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFFFF7ED),
                      child: Text(
                        (user?.namaUser.isNotEmpty == true ? user!.namaUser[0] : 'U').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.namaUser ?? 'Pengguna',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
                          ),
                          Text(
                            (user?.username.isNotEmpty ?? false) && user?.username != 'pelanggan'
                                ? '@${user!.username}'
                                : 'Pelanggan Rasantara Terverifikasi',
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined, color: Color(0xFFEA580C)),
                  title: Text(context.t('Pengaturan Profil & Keamanan', 'Profile & Security Settings'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(context.t('Password, Google OAuth, Saldo & Alamat', 'Password, Google OAuth, Balance & Address'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final destinations = _getDestinationsForRole(role);
                    final pIdx = destinations.indexWhere((d) => d.label.contains('Profil') || d.label.contains('Profile'));
                    if (pIdx != -1) {
                      setState(() => _currentIndex = pIdx);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            db: widget.db,
                            onLogout: widget.onLogout,
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.manage_accounts_outlined, color: context.textPrimary),
                  title: Text(context.t('Ganti Role Akun', 'Switch Account Role'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
                  trailing: Icon(Icons.chevron_right, size: 20, color: context.textSecondary),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppTheme.statusRed),
                  title: Text(context.t('Keluar dari Akun', 'Log Out'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.statusRed)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.db.logout();
                    widget.onLogout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.db.currentUser;
    final role = currentUser?.role ?? UserRole.pelanggan;
    final destinations = _getDestinationsForRole(role);

    // Guard index bounds
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              _scaffoldKey.currentState?.closeDrawer();
              return;
            }
            if (_currentIndex != 0) {
              setState(() => _currentIndex = 0);
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aplikasi tetap aktif. Gunakan menu Keluar di profil untuk logout.'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Scaffold(
            key: _scaffoldKey,
          drawer: _buildDrawer(currentUser, role, destinations),
          appBar: AppBar(
            backgroundColor: context.surfaceCard,
            elevation: 0.5,
            titleSpacing: 0,
            leading: IconButton(
              icon: Icon(Icons.menu_rounded, color: context.textPrimary, size: 24),
              tooltip: 'Menu Sidebar',
              onPressed: () {
                if (!isDesktop) {
                  if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                    _scaffoldKey.currentState?.closeDrawer();
                  } else {
                    _scaffoldKey.currentState?.openDrawer();
                  }
                } else {
                  setState(() {
                    _isDesktopSidebarVisible = !_isDesktopSidebarVisible;
                  });
                }
              },
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/images/logo.png', width: 26, height: 26, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.storefront, color: Color(0xFFEA580C), size: 16)),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Rasantara',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: context.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              if (isDesktop) ...[
                InkWell(
                  onTap: () => _showUserAccountModal(context, currentUser, role),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: context.isDarkMode
                          ? const Color(0xFF7C2D12).withValues(alpha: 0.3)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.isDarkMode
                            ? const Color(0xFF7C2D12)
                            : const Color(0xFFFFEDD5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        Text(
                          role == UserRole.pelanggan && (currentUser?.username.isNotEmpty ?? false) && currentUser?.username != 'pelanggan'
                              ? '@${currentUser!.username}'
                              : role.label,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted, size: 20),
                tooltip: 'Pengaturan Aplikasi',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen(db: widget.db)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                tooltip: 'Keluar dari Akun',
                onPressed: () => _confirmLogout(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: isDesktop
              ? Row(
                  children: [
                    // Desktop Sidebar Navigation
                    if (_isDesktopSidebarVisible)
                      Container(
                        width: 220,
                        decoration: BoxDecoration(
                          color: context.surfaceCard,
                          border: Border(right: BorderSide(color: context.borderSubtle)),
                        ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: destinations.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final item = destinations[index];
                                final isSelected = _currentIndex == index;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => setState(() => _currentIndex = index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFEA580C).withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 20,
                                          color: isSelected ? const Color(0xFFEA580C) : AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? const Color(0xFFEA580C) : context.textPrimary,
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
                          // Shortcut Scan QR Meja on Desktop
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rasantara POS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sistem Manajemen Kasir & Pemesanan',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: destinations[_currentIndex].screen,
                    ),
                  ],
                )
              : destinations[_currentIndex].screen,

          // ─── BOTTOM NAVBAR TAMPILAN MOBILE: CRAFTED ANTI-SLOP ───
          bottomNavigationBar: !isDesktop
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingOrderTracker(context, currentUser),
                    _buildCraftedBottomNav(context, currentUser, role, destinations),
                  ],
                )
              : null,
          ),
        );
      },
    );
  }

  /// Floating pill bar Pantau Pesanan (dinonaktifkan agar pantau pesanan spesifik per meja yang diklik)
  Widget _buildFloatingOrderTracker(BuildContext context, UserModel? currentUser) {
    return const SizedBox.shrink();
  }

  /// Navbar Mobile Human-Crafted (Anti-Slop Design):
  /// - Bersih, terstruktur kokoh di bagian bawah dengan hairline border 1px
  /// - Tombol PINDAI terintegrasi elegan di tengah tanpa bayangan neon atau orbs mengambang
  /// - Navigasi 100% fungsional, rasio sentuh ramah jari (accessible touch target)
  Widget _buildCraftedBottomNav(
    BuildContext context,
    UserModel? currentUser,
    UserRole role,
    List<NavDestinationItem> destinations,
  ) {

    // Tampilkan destinasi sesuai role yang aktif (maksimal 5 tab di mobile)
    final displayDestinations = destinations.length <= 5
        ? destinations
        : destinations.sublist(0, 5);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceCard,
        border: Border(
          top: BorderSide(color: context.borderSubtle, width: 1.0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: displayDestinations.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = _currentIndex == idx;
              final shortLabel = item.label.split(' & ').first.split(' / ').first;

              return Expanded(
                child: _buildNavItem(
                  icon: item.icon,
                  activeIcon: item.icon,
                  label: shortLabel,
                  isSelected: isSelected,
                  onTap: () => setState(() => _currentIndex = idx),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFFEA580C);
    const inactiveColor = Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? (context.isDarkMode
                        ? const Color(0xFF7C2D12).withValues(alpha: 0.4)
                        : const Color(0xFFFFF7ED))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(
    UserModel? currentUser,
    UserRole role,
    List<NavDestinationItem> destinations,
  ) {
    return Drawer(
      backgroundColor: context.surfaceCard,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.storefront, color: Colors.white, size: 28)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Rasantara',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.4, color: context.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sistem Kasir & Restoran Modern',
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          role == UserRole.pelanggan && (currentUser?.username.isNotEmpty ?? false) && currentUser?.username != 'pelanggan'
                              ? '@${currentUser!.username}'
                              : role.label,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFEA580C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: destinations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = destinations[index];
                final isSelected = _currentIndex == index;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: isSelected ? const Color(0xFFEA580C).withValues(alpha: 0.1) : Colors.transparent,
                  leading: Icon(
                    item.icon,
                    color: isSelected ? const Color(0xFFEA580C) : AppTheme.textMuted,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFFEA580C) : context.textPrimary,
                    ),
                  ),
                  onTap: () {
                    setState(() => _currentIndex = index);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
            title: Text(context.t('Pengaturan Aplikasi', 'App Settings'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(db: widget.db)));
            },
          ),
          const Divider(color: AppTheme.borderSubtle),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2),
                foregroundColor: const Color(0xFFDC2626),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
              label: Text(
                context.t('Keluar dari Akun', 'Log Out'),
                style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _confirmLogout(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text(context.t('Konfirmasi Keluar', 'Confirm Logout'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          context.t(
            'Apakah Anda yakin ingin keluar dari sesi akun Rasantara?',
            'Are you sure you want to log out of your Rasantara session?',
          ),
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('Batal', 'Cancel'), style: const TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.db.logout();
              widget.onLogout();
            },
            child: Text(context.t('Ya, Keluar', 'Yes, Log Out')),
          ),
        ],
      ),
    );
  }
}
