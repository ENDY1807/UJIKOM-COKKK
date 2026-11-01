import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'order/order_entry_screen.dart';
import 'order/order_history_screen.dart';
import 'order/qr_scanner_dialog.dart';
import 'cashier/cashier_screen.dart';
import 'reference/menu_management_screen.dart';
import 'reference/table_qr_screen.dart';
import 'reports/report_screen.dart';
import 'users/user_management_screen.dart';
import 'profile/profile_screen.dart';

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
  String? _scannedTableFromQr;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Buka Scanner QR Code Kamera (Tombol Utama di Navbar Gaya DANA)
  Future<void> _openCameraQrScanner(List<NavDestinationItem> destinations) async {
    final scannedTable = await QrScannerDialog.show(context);
    if (scannedTable != null && scannedTable.isNotEmpty) {
      // Cari index layar Pesan Menu / Entri Order
      final orderIndex = destinations.indexWhere(
        (d) => d.label.contains('Pesan') || d.label.contains('Order'),
      );

      setState(() {
        _scannedTableFromQr = scannedTable;
        if (orderIndex != -1) {
          _currentIndex = orderIndex;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEA580C),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('QR Meja Terbaca: $scannedTable. Membuka menu pesanan...'),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  List<NavDestinationItem> _getDestinationsForRole(UserRole role) {
    final list = <NavDestinationItem>[];

    // 1. Dashboard Utama: Seluruh role
    list.add(NavDestinationItem(
      label: 'Beranda',
      icon: Icons.dashboard_outlined,
      screen: DashboardScreen(
        db: widget.db,
        onNavigateToTab: _navigateToTab,
      ),
    ));

    // 2. Order Entry: Admin, Waiter, Pelanggan
    if (role.canCreateOrder) {
      list.add(NavDestinationItem(
        label: role == UserRole.pelanggan ? 'Pesan Menu' : 'Entri Order',
        icon: Icons.restaurant_menu_rounded,
        screen: OrderEntryScreen(
          key: ValueKey(_scannedTableFromQr),
          db: widget.db,
          initialTableNo: _scannedTableFromQr,
        ),
      ));
    }

    // 2b. Riwayat Pesanan Saya: Khusus Pelanggan
    if (role == UserRole.pelanggan) {
      list.add(NavDestinationItem(
        label: 'Riwayat',
        icon: Icons.receipt_long_rounded,
        screen: CustomerOrderHistoryScreen(db: widget.db),
      ));
    }

    // 3. Transaksi Kasir: Admin, Kasir
    if (role.canProcessTransactions) {
      list.add(NavDestinationItem(
        label: 'Kasir & Tagihan',
        icon: Icons.point_of_sale_rounded,
        screen: CashierScreen(db: widget.db),
      ));
    }

    // 4. Entri Referensi: Admin only
    if (role.canManageReferences) {
      list.add(NavDestinationItem(
        label: 'Referensi Menu',
        icon: Icons.inventory_2_outlined,
        screen: MenuManagementScreen(db: widget.db),
      ));
    }

    // 5. Generate Laporan: Admin, Waiter, Kasir, Owner
    if (role.canViewReports) {
      list.add(NavDestinationItem(
        label: 'Laporan',
        icon: Icons.analytics_outlined,
        screen: ReportScreen(db: widget.db),
      ));
    }

    // 6. Registrasi & Manajemen User: Admin, Waiter, Kasir
    if (role.canRegisterUsers) {
      list.add(NavDestinationItem(
        label: role == UserRole.administrator ? 'Kelola User' : 'Registrasi',
        icon: Icons.people_outline,
        screen: UserManagementScreen(db: widget.db),
      ));
    }

    // 7. Cetak & Buat QR Meja: Admin, Kasir, Owner
    if (role == UserRole.administrator || role == UserRole.kasir || role == UserRole.owner) {
      list.add(NavDestinationItem(
        label: 'QR Meja',
        icon: Icons.qr_code_2_rounded,
        screen: TableQrScreen(db: widget.db),
      ));
    }

    // 8. Profil & Pengaturan Akun: Semua Role
    list.add(NavDestinationItem(
      label: 'Profil',
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
      backgroundColor: Colors.white,
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
                      color: const Color(0xFFE2E8F0),
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
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            'Role: ${role.label}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
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
                  title: const Text('Pengaturan Profil & Keamanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Password, Google OAuth, Saldo & Alamat', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    final destinations = _getDestinationsForRole(role);
                    final pIdx = destinations.indexWhere((d) => d.label.contains('Profil'));
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
                  leading: const Icon(Icons.manage_accounts_outlined, color: AppTheme.textDark),
                  title: const Text('Ganti Role Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: AppTheme.statusRed),
                  title: const Text('Keluar dari Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.statusRed)),
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
          drawer: !isDesktop ? _buildDrawer(currentUser, role, destinations) : null,
          appBar: AppBar(
            backgroundColor: AppTheme.white,
            elevation: 0.5,
            titleSpacing: 8,
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
                  child: const Icon(Icons.restaurant_menu, color: Color(0xFFEA580C), size: 16),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Rasantara',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              // Quick Role Switcher Dropdown
              PopupMenuButton<UserRole>(
                tooltip: 'Ganti Role Akun',
                onSelected: (newRole) {
                  widget.db.switchRole(newRole);
                  setState(() => _currentIndex = 0);
                },
                itemBuilder: (ctx) => UserRole.values.map((r) {
                  return PopupMenuItem(
                    value: r,
                    child: Row(
                      children: [
                        Icon(
                          r == role ? Icons.check_circle : Icons.circle_outlined,
                          size: 16,
                          color: r == role ? const Color(0xFFEA580C) : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(r.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, size: 14, color: Color(0xFFEA580C)),
                      const SizedBox(width: 4),
                      Text(
                        role.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 14, color: Color(0xFFEA580C)),
                    ],
                  ),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, size: 16, color: AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        currentUser?.namaUser ?? 'Pengguna',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.logout, color: AppTheme.statusRed, size: 18),
                tooltip: 'Keluar',
                onPressed: () {
                  widget.db.logout();
                  widget.onLogout();
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: isDesktop
              ? Row(
                  children: [
                    // Desktop Sidebar Navigation
                    Container(
                      width: 220,
                      decoration: const BoxDecoration(
                        color: AppTheme.white,
                        border: Border(right: BorderSide(color: AppTheme.borderSubtle)),
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
                                              color: isSelected ? const Color(0xFFEA580C) : AppTheme.textDark,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Scan QR Meja', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _openCameraQrScanner(destinations),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.borderSubtle),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rasantara Restoran',
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
              ? _buildCraftedBottomNav(context, currentUser, role, destinations)
              : null,
          ),
        );
      },
    );
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Beranda
              Expanded(
                child: _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Beranda',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
              ),

              // 2. Pesan Menu
              Expanded(
                child: _buildNavItem(
                  icon: Icons.restaurant_menu_outlined,
                  activeIcon: Icons.restaurant_menu_rounded,
                  label: 'Pesan',
                  isSelected: _currentIndex == 1 && destinations.length > 1,
                  onTap: () {
                    if (destinations.length > 1) {
                      setState(() => _currentIndex = 1);
                    }
                  },
                ),
              ),

              // 3. Tombol Tengah Ergonomis: PINDAI QR MEJA
              SizedBox(
                width: 72,
                child: Center(
                  child: InkWell(
                    onTap: () => _openCameraQrScanner(destinations),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x28EA580C),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'PINDAI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Aktivitas / Riwayat
              Expanded(
                child: _buildNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: destinations.length > 2 ? destinations[2].label.split(' ').first : 'Aktivitas',
                  isSelected: _currentIndex == 2 && destinations.length > 2,
                  onTap: () {
                    if (destinations.length > 2) {
                      setState(() => _currentIndex = 2);
                    }
                  },
                ),
              ),

              // 5. Akun Saya
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Akun',
                  isSelected: _currentIndex == destinations.indexWhere((d) => d.label.contains('Profil')),
                  onTap: () {
                    final pIdx = destinations.indexWhere((d) => d.label.contains('Profil'));
                    if (pIdx != -1) {
                      setState(() => _currentIndex = pIdx);
                    } else {
                      _showUserAccountModal(context, currentUser, role);
                    }
                  },
                ),
              ),
            ],
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
                color: isSelected ? const Color(0xFFFFF7ED) : Colors.transparent,
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
      backgroundColor: AppTheme.white,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7ED),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.restaurant, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Rasantara',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${role.label} · ${currentUser?.namaUser ?? "Pengguna"}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
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
                      color: isSelected ? const Color(0xFFEA580C) : AppTheme.textDark,
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
          const Divider(color: AppTheme.borderSubtle),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.logout, color: AppTheme.statusRed, size: 18),
              label: const Text('Keluar dari Akun', style: TextStyle(color: AppTheme.statusRed, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
                widget.db.logout();
                widget.onLogout();
              },
            ),
          ),
        ],
      ),
    );
  }
}
